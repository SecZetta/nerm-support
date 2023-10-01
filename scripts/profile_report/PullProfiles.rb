require 'csv'
require 'json'
require 'net/http'
require 'uri'
require 'net/https'
require 'date'

$stdout.sync = true

p "Pull Profiles Start"

## Static values
$Profile_Type_ID = ""
$apitoken = ""
$Tenant =""
$baseUrl="https://#{$Tenant}.nonemployee.com"

$limit=500 						# can be 500 if using /profiles
$get_limit = Float::INFINITY	# or Float::INFINITY to not stop until the end.

$Path = "Advanced Search Endpoint" 	# "Profiles Endpoint" OR "Advanced Search Endpoint"

$Request_json = {				## SET Json boyd if using the Advanced Search Endpoint
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
		@output_location = "#{$Tenant}_ProfileReport_#{Date.today}.csv"

		# Static Headers for the final CSV, used as default if the dynamic headers are not set. 
		@CSV_Headers = ["id","uid","name","profile_type_id","status","created_at","updated_at",
		"attribute_1","attribute_2"]
	end

	def create_csv(data_hash_array,headers=@CSV_Headers)
		p "creating CSV"
		csv_config = {
			write_headers: true,
			force_quotes: true,
			encoding: 'utf-8'
		}
		csv_file = CSV.open(@output_location, "w", :write_headers=>true, :force_quotes=>true, :encoding=>'utf-8') do |csv|
			csv.to_io.write "\uFEFF"
			csv << headers
			data_hash_array.each do |r|
				row_arr = []
				headers.each do |h|
					row_arr << "#{r[h]}"
				end
				csv << row_arr.dup
			end
		end
	end
end

# Make API requests based on the given path
def make_request(limit,offset)
	case $Path
		when "Profiles Endpoint"
			uri = URI.parse("#{$baseUrl}/api/profiles?limit=#{limit}&offset=#{offset}&profile_type_id=#{$Profile_Type_ID}")
			request = Net::HTTP::Get.new(uri)
		when "Advanced Search Endpoint"
			limit = 100 unless limit < 100
			uri = URI.parse("#{$baseUrl}/api/advanced_search/run?limit=#{limit}&offset=#{offset}")
			request = Net::HTTP::Post.new(uri)
			request.body = $Request_json.to_json
		else
			return
	end
	p uri

	request.content_type = "application/json"
	request["Authorization"] = "Token token=#{$apitoken}"
	request["Accept"] = "application/json"

	req_options = {
		read_timeout: 60,
		use_ssl: true,
		verify_mode: OpenSSL::SSL::VERIFY_NONE
	}
	response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
		http.request(request)
	end
	return response

end
#

profiles = Array.new
response=Hash.new
offset = 0

while offset != $get_limit do
	response = make_request($limit,offset)

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
			offset += $limit
		
			p "Hit the GET limit of #{$get_limit}, Stopping loop" if offset == $get_limit	
		when Net::HTTPUnauthorized
			p "{response.code} | #{response.message}: Check API token"
			break
		when Net::HTTPServerError
			p "{response.code} | #{response.message}: try again later?"
			break
		else
			p "#{response.code} | #{response.message}"
			break
	end
end

unless profiles.empty? then

	helper = ExportHelper.new
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

	custom_csv_headers = Array.new

	result_array.each do |i|
		custom_csv_headers |= i.keys
	end

	helper.create_csv(result_array,custom_csv_headers)
end