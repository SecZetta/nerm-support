require 'json'
require 'net/http'
require 'uri'
require 'net/https'
require 'date'

$stdout.sync = true

p "Cancel Sessions Start"

## Static Values
# @Profile_Type_ID = ""
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

## Cancel the session
def cancel_session(session_id)
    req_json = {
        "workflow_session": {
            "status_uid": "closed"
        }
    }
    response= makeAPIrequest("workflow_sessions/#{session_id}", 'PATCH', req_json.to_json)
    p response
end
##



File.foreach("ids/IDs_to_cancel.txt") { |id|
    p id.gsub("\n","")
    cancel_session(id.gsub("\n",""))
}