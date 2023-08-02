require 'json'
require 'net/http'
require 'uri'
require 'net/https'
require 'date'
require 'csv'

$stdout.sync = true

p "Pull Profile IDs Start"

## Static Values
@Profile_Type_ID = ""
@API_Token = ""
@Tenant = ""
@url=".nonemployee.com"

## Make API Request ##
def makeAPIrequest (uriEnd, requesttype, jsonbody = '')
	uri = URI.parse("https://#{@Tenant}#{@url}/api/#{uriEnd}")
	# p uri
	case requesttype.downcase
		when 'get'
			request = Net::HTTP::Get.new(uri)
		when 'post'
			request = Net::HTTP::Post.new(uri)
		when 'patch'
			request = Net::HTTP::Patch.new(uri)
		else request = ''
	end
	request.content_type = "application/json"
	request["Authorization"] = "Token token=#{@API_Token}"
	request["Accept"] = "application/json"
	request.body = jsonbody unless jsonbody == ''

	req_options = {
		read_timeout: 50,
		use_ssl: true,
		verify_mode: OpenSSL::SSL::VERIFY_NONE
	}
	
	response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
	http.request(request)
	end
end
##

# ## Cancel the session
# def cancel_session(session_id)
#     req_json = {
#         "workflow_session": {
#             "status_uid": "closed"
#         }
#     }
#     response= makeAPIrequest("workflow_sessions/#{session_id}", 'PATCH', req_json.to_json)
#     p response
# end
# ##

## Pull UIDs from Text file into hash
def pull_data
    p_ids=Hash.new
    cnt=1

    File.foreach("files/uids.txt") { |uid|
        p "Pulling ID #{cnt}"
        cnt+=1

        p_ids[uid]= JSON.parse(makeAPIrequest("profiles?exclude_attributes=true&uid=#{uid}", 'GET').body)["profiles"][0]["id"]
    }

    p_ids
end
# 
## Generates a CSV with the UIDs and IDs for each profile
def create_csv(p_ids)
    csv_config = {
        write_headers: true,
        force_quotes: true,
        encoding: 'utf-8'
    }
    csv_file = CSV.open("files/ids.csv", "w", :write_headers=>true, :force_quotes=>true, :encoding=>'utf-8') do |csv|
        csv.to_io.write "\uFEFF"
        csv << ["uid","id"]
        cnt=1
        
        p_ids.each do |r|
            p "Creating CSV Row #{cnt}/#{p_ids.size}"
            cnt+=1

            row_arr = []
            row_arr << r[0]
            row_arr << r[1]
            csv << row_arr.dup
        end
    end
end
# 

create_csv(pull_data)