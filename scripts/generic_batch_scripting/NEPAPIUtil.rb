require 'net/http'
require 'uri'
require 'json'
require 'csv'
require 'openssl'
require 'open-uri'
require 'roo'

OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

class NEProfileAPI
  def profile_type_id_map
    @profile_type_id_map ||= 
      Hash[bulk_get_request('profile_types')["content"].map { 
        |record| [record["name"], record["id"]]
      }]
  end

  def attribute_id_map
    @attribute_id_map ||= 
      Hash[bulk_get_request('ne_attributes')["content"].map { 
        |record| [record["uid"], record["id"]]
      }]
  end

  def initialize(host:, authorization_hash:)
    @host_url = host
    @auth_hash = authorization_hash
  end
  
  def make_request(request_type, endpoint, response_header: nil, param_hash: {}, request_json: nil)
    # Assume the response header is the same as the endpoint name if none is given.
    response_header = endpoint if response_header.nil?
    response_header.downcase!
    

    # Construct URI
    uri = URI.parse("https://#{@host_url}/api/#{endpoint}?#{URI.encode_www_form(param_hash)}")

    # Determine request type
    case request_type.upcase
    when 'GET'
      request = Net::HTTP::Get.new(uri)
    when 'POST'
      request = Net::HTTP::Post.new(uri)
    when 'PATCH'
      request = Net::HTTP::Patch.new(uri)
    when 'DELETE'
      request = Net::HTTP::Delete.new(uri)
    else
      p "#{request_type} is not a valid HTTP request type for the NEProfile API. Try Get, Post, Patch, or Delete."
    end
    
    # Setup request parameters
    request.content_type = "application/json"
    @auth_hash.each do |k, v|
      request[k] = v
    end
    request["Accept"] = "application/json"
    request.body = request_json unless request_json.nil?

		req_options = {
			use_ssl: uri.scheme == "https",
			read_timeout: 300
    }
    
    p "#{request_type}: #{uri}"
	start_time = Time.now
    # Make request
    response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
			http.request(request)
    end
    end_time = Time.now
	p "Request Time: #{end_time - start_time} seconds"
    # Process response
    response_hash = {}
    response_hash["code"] = response.code
    response_hash["body"] = response.body
    response_hash["content"] = []
	
	if response_hash["code"] == '504' || response_hash["code"] == '502'
		p "Code: #{response.code}"
		p "Waiting 60 seconds"
		sleep(60)
		return make_request(request_type, endpoint, response_header: response_header, param_hash: param_hash, request_json: request_json)
	end

    if ["user", "profile", "workflow_session"].include?(response_header)
      response_hash["content"] << JSON.parse(response.body)[response_header]
    else
      content = JSON.parse(response.body)[response_header]
      unless content.nil?
        content.each do |record|
          response_hash["content"] << record
        end
      end
    end

	return response_hash
  end

  def bulk_get_request(endpoint, response_header: nil, param_hash: {}, return_limit: Float::INFINITY)
    # Set offset and limit parameters if they are ot already set
    param_hash["offset"] = param_hash["offset"].to_i # nil.to_i = 0
    param_hash["limit"] = 100 if param_hash["limit"].nil?

    # Response hash starts empty
    response_hash = {}
    response_hash["codes"] = []
    response_hash["bodies"] = []
    response_hash["content"] = []

    records_found = 0

    # Continue making requests and incrementing the offset until all records are collected
    loop do
      i_response = make_request('Get', endpoint, response_header: response_header, param_hash: param_hash)
      response_hash["codes"] << i_response["code"]
      response_hash["bodies"] << i_response["body"]

      i_response["content"].each do |record|
        response_hash["content"] << record
        records_found += 1
        break if records_found >= return_limit
      end

      param_hash["offset"] += param_hash["limit"]
    break if i_response["content"].length < param_hash["limit"] || records_found >= return_limit
    end

    return response_hash
  end

  def bulk_advanced_search(search_hash: nil, param_hash: {}, return_limit: Float::INFINITY)
    # Set offset and limit parameters if they are ot already set
    param_hash["offset"] = param_hash["offset"].to_i # nil.to_i = 0
    param_hash["limit"] = 100 if param_hash["limit"].nil?

    # Response hash starts empty
    response_hash = {}
    response_hash["codes"] = []
    response_hash["bodies"] = []
    response_hash["content"] = []

    records_found = 0

    # Continue making requests and incrementing the offset until all records are collected
    loop do
      i_response = make_request('Post', 'advanced_search/run', response_header: 'profiles', param_hash: param_hash, request_json: search_hash.to_json)
      response_hash["codes"] << i_response["code"]
      response_hash["bodies"] << i_response["body"]

      i_response["content"].each do |record|
        response_hash["content"] << record
        records_found += 1
        break if records_found >= return_limit
      end

      param_hash["offset"] += param_hash["limit"]
    break if i_response["content"].length < param_hash["limit"] || records_found >= return_limit
    end

    return response_hash
  end

  def filter_content(content_array, filtering_hash)
    content_array.dup.keep_if { |h| hash_matches_filter?(h, filtering_hash)}
  end

  def get_profile_create_error(response_body, profile_name, record_id = nil)
		response_hash = JSON.parse(response_body)
    err_message = "<br/><b>Error during profile creation (#{profile_name})"

    # If identifier supplied for record.
    if record_id.nil?
      err_message += ":</b>"
    else
      err_message += " for record #{record_id}:</b>"
    end

    # Parse the actual error message.
		unless response_hash["errors"].nil?
			response_hash["errors"].each do |k, v|
				unless k == "possible_duplicates"
					err_message += "<br/>- <b>#{k}</b>: #{v[0]}"
				else
					err_message += "<br/>- <b>#{k}</b>: "
					v[0].each do |pos_dup|
						err_message += "#{pos_dup["id"]},"
					end
					err_message.chomp!(',')
				end
			end
		else
			err_message = "Unknown profile creation error. HTTP Response: #{response_hash.to_s}"
		end
		return err_message
  end
  
  def get_attachment_data(endpoint, object_id, attribute_id, expected_file_type, process_info: {})
    # Get attachment from workflow session
    response = make_request('Get', "#{endpoint}/#{object_id}/upload/#{attribute_id}")

    # Save attachment locally
		saved_file_name = "data_#{endpoint}_#{object_id}.#{expected_file_type.downcase}"
		response_json = JSON.parse(response["body"])
		url_for_uploaded_file = URI.parse(response_json['url'])
		url_for_uploaded_file.open do |actual_file|
				File.open(saved_file_name, 'wb') do |new_file|
						new_file.write(actual_file.read)
				end
    end
    
    case expected_file_type.downcase
    when 'csv'
      response_hash = parse_csv(saved_file_name)
    when 'xlsx'
      response_hash = parse_xlsx(saved_file_name, process_info)
    else
      response_hash = {}
      response_hash["data"] = []
      response_hash["error"] = "Can not process expected file type #{expected_file_type}."
    end
    
    # Delete temp file
    File.delete(saved_file_name) if File.exist?(saved_file_name)

		return response_hash
  end

  def parse_xlsx(file_name, columns_hash)
    response_hash = {}
    response_hash["data"] = []

    begin
      xlsx = Roo::Spreadsheet.open("./#{file_name}")

      first = true
      xlsx.each(columns_hash) do |row|
        if first
          first = false
        else
          row_data = {}
          row.each do |k, v|
            v_data = ''
            unless v.nil?
              v_data = "#{v}"
            end
            row_data[k] = v_data
          end
          response_hash["data"] << row_data.dup
        end
      end
    rescue => e
      response_hash["error"] = "XLSX Parsing Error: #{e}"
      response_hash["data"] = []
    end

    return response_hash
  end

  def parse_csv(file_name)
    response_hash = {}
    response_hash["data"] = []

    # Pull CSV data from file
    begin
      CSV.foreach(file_name, :headers => true, :row_sep => :auto, :quote_char => "\"", :encoding => 'ISO8859-1:utf-8') do |row|
        row_data = {}
        row.each do |k, v|
          v_data = ''
          unless v.nil?
            # Remove hidden encoding characters that can ruin data
            v_data = v.force_encoding('UTF-8')
            v_data.sub!("\u200B".force_encoding('UTF-8'), '')
            v_data = v_data.chars.select(&:valid_encoding?).join
          end
          row_data[k] = v_data
        end
        response_hash["data"] << row_data.dup
      end
    rescue => e
      if "#{e.class}" == "CSV::MalformedCSVError"
        response_hash["error"] = "Malformed CSV Error: #{e}"
        response_hash["data"] = []
      else
        raise e
      end
    end

    return response_hash
  end

  def get_profile_owner_id(profile_id, attribute_id)
    request_params = {}
    request_params["profile_id"] = profile_id
    request_params["ne_attribute_id"] = attribute_id
    request_params["relationship_type"] = "owner"
    response = make_request("GET", "user_profiles", param_hash: request_params)

    return response["content"][0]["user_id"]
  end

  private
  def hash_matches_filter?(content, filtering_hash)
    result = true
    filtering_hash.keys.each do |k|
      dug = content.dig(k)
      if dug.nil?
        result = false
      else
        if filtering_hash[k].is_a?(Hash) && dug.is_a?(Hash)
          unless hash_matches_filter?(dug, filtering_hash[k])
            result = false
          end
        else
          if dug != filtering_hash[k]
            result = false
          end
        end
      end
    end
    return result
  end
end