require 'csv'
require 'json'
require 'net/http'
require 'uri'
require 'net/https'
require 'date'

$stdout.sync = true

p "Pull Profiles Start"

## STATIC VALUES -- SET BEFORE RUNNING SCRIPT
$CSV_Headers = ["id","uid","name","profile_type_id","status","created_at","updated_at"]		# Headers for the final CSV, in order.

$Profile_Type_ID = ""	# Profile Type to use for the /profiles endpoint and in the Advanced Search JSON Body
$API_Token = ""				# API Token the script will use to make requests
$Tenant =""											# Tenant subdomain we will target for requests
$Base_Url="https://#{$Tenant}.nonemployee.com"				# Base URL that the HTTP requests will use. 

$Limit=500 													# Default limit for HTTP requests
$Default_Offset=0											# Default offset for HTTP requests
$Get_Limit = Float::INFINITY								# The limit for the number of returned profiles . Can use Float::INFINITY to get "all" profiles 

$Path = "Profiles Endpoint" 	# Drives what request to make - "Profiles Endpoint" OR "Advanced Search Endpoint" 

$Request_json = {				## SET Json body if using the Advanced Search Endpoint
	"advanced_search": {
		"condition_rules_attributes": [
			{
				"type": "ProfileTypeRule",
				"comparison_operator": "==",
				"value": "#{$Profile_Type_ID}"
			}
		]
	}
}

class ExportHelper
	def initialize 
		# Location to save script output. Must be csv format. (Default: "data.csv")
		@output_location = "#{$Tenant}_ProfileReport_#{Time.now.to_i}.csv"
	end

	# Creates the start of the CSV with Headers only
	def create_csv(headers=$CSV_Headers)
		p "creating CSV"
		csv_file = CSV.open(@output_location, "w", :write_headers=>true, :force_quotes=>true, :encoding=>'utf-8') do |csv|
			csv.to_io.write "\uFEFF"
			csv << headers
		end
	end

	# Appends slices of data to the CSV as the requests are made
	def append_csv(data_hash_array,headers=$CSV_Headers)
		p "adding #{data_hash_array.size} data records to CSV"
		csv_file = CSV.open(@output_location, "ab", :force_quotes=>true, :encoding=>'utf-8') do |csv|
			data_hash_array.each do |r|
				row_arr = []
				headers.each do |h|		# Use headers as the key values to read each data row into the CSV so the attributes land in the right columns 
					row_arr << "#{r[h]}"
				end
				csv << row_arr.dup
			end
		end
	end
end

# Make API requests based on the given path
def make_request(limit = $Limit, offset)
	case $Path
		when "Profiles Endpoint"
			limit = 500 unless limit < 500
			uri = URI.parse("#{$Base_Url}/api/profiles?limit=#{limit}&offset=#{offset}&profile_type_id=#{$Profile_Type_ID}")
			request = Net::HTTP::Get.new(uri)
		when "Advanced Search Endpoint"
			limit = 100 unless limit < 100
			uri = URI.parse("#{$Base_Url}/api/advanced_search/run?limit=#{limit}&offset=#{offset}")
			request = Net::HTTP::Post.new(uri)
			request.body = $Request_json.to_json
		else
			p "No Path Selected"
			exit 1
	end
	p uri

	request.content_type = "application/json"
	request["Authorization"] = "Token token=#{$API_Token}"
	request["Accept"] = "application/json"

	req_options = {
		read_timeout: 60,
		use_ssl: true,
		verify_mode: OpenSSL::SSL::VERIFY_NONE
	}
	response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
		http.request(request)
	end
	return response,limit
end
#

response = Hash.new			# Holds the HTTP response
profiles = Array.new		# Holds the Profiles gathered by the HTTP request
offset = $Default_Offset	# Set a local scope offset so it can be manipulated if the default is too high for the endpoint
helper = ExportHelper.new	# Export Helper class to make HTTP requests and generate the report csv
helper.create_csv			# Create the initial CSV file

while offset != $Get_Limit do
	response,next_offset = make_request(offset)

	case response
		when Net::HTTPSuccess
			p "Success"
			parsed = response.read_body
			parsedresponse = JSON.parse(parsed)
			
			if parsedresponse["profiles"].empty? then 
				p 'No More Profiles, Stopping loop'
				break
			else
				# p parsedresponse["profiles"]
				parsedresponse["profiles"].each do |i|
					profiles << i
				end
			end
			offset += next_offset
		
			p "Hit the GET limit of #{$Get_Limit}, Stopping loop" if offset == $Get_Limit	
		when Net::HTTPUnauthorized
			p "{response.code} | #{response.message}: Check API token"
			break
		when Net::HTTPServerError
			p "{response.code} | #{response.message}: try again later?"
			break
		else
			p "#{response.code} | #{response.message} - May be end of Profiles"
			
			break
	end

	unless profiles.empty? then
		result_array = []
		profiles.each do |i|
			record_hash = {}
	
			# get top level attributes
			i.each do |k,v|
				unless k=="attributes" then
					record_hash[k]=i[k] 
				end
			end
	
			# get all profile attributes
			i["attributes"].each do |k,v|
				record_hash[k]=i["attributes"][k]
			end
	
			result_array << record_hash.clone
		end
	
		helper.append_csv(result_array)
	end
	profiles.clear	# clear data from the Profiles Array for GC
end