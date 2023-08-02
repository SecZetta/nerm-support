require_relative '.\NEPAPIUtil.rb'

class WorkflowHelper
	def initialize
		@start_time = Time.now

		@api = NEProfileAPI.new(
			host: '.seczetta.com', 
			authorization_hash: {'Authorization': 'Token token='}
		)

		# test_mode = true will run the workflow against only the one profile specified.
		# This is to verify the workflow produces the correct outcome before running it against the whole batch
		@test_mode = false
		@test_profile = ''
		
		# profile type is only enforced if test_mode = false
		@profile_type_to_get = 'PROFILE TYPE UUID'
		@get_limit = 20

		# Workflow to run and the requester who should be given credit for running it.
		# Designed for update workflows only
		@workflow_to_run = ''
		@workflow_requester = ''
		
		# Time to wait between workflow session POSTs
		@request_buffer = 0
	end

	def report
		p "Run Time: #{run_time_string(Time.now - @start_time)}"
	end

	def run_time_string(run_time)
		hours = (run_time / 3600).floor()
		minutes = ((run_time - (hours * 3600)) / 60).floor()
		seconds = (run_time % 60).floor()

		time_string = ""
		time_string += "#{hours} hours " unless hours == 0
		time_string += "#{minutes} minutes " unless minutes == 0
		time_string += "#{seconds} seconds" unless seconds == 0

		return time_string.empty? ? "less than 1 second" : time_string
	end

	def get_profile_ids	
		# request_json = {
		# 	"advanced_search": {
		# 		"condition_rules_attributes": [
		# 			{
		# 				"type": "ProfileTypeRule",
		# 				"comparison_operator": "==",
		# 				"value": "#{@api.profile_type_id_map["ENTER PROFILE TYPE TEXT ( EX: Non-Employee Roles )"]}"
		# 			},
		# 			{
		# 				"type": "ProfileAttributeRule",
		# 				"condition_object_id": "#{@api.attribute_id_map['ENTER ATTRIBUTE UID']}",
		# 				"object_type": "NeAttribute",
		# 				"comparison_operator": "include?",
		# 				"value": "ENTER VALUE HERE"
		# 			}
		# 		]
		# 	}
        # }

		# profiles = @api.make_request('POST', 'advanced_search/run', response_header: 'profiles', request_json: request_json.to_json)


		# file = File.open('pids_and_sids.csv')
		# profiles= CSV.read(file,headers: true)
		# file.close

		file = File.open('internal_profile_id_ne_attribute.txt')
		profiles= file.readlines.map(&:chomp)
		file.close
		
		return profiles
	end

	def run_workflow(profile_id)
		req_json = {
			"workflow_session"=> {
				"workflow_id"=> "#{@workflow_to_run}",
				"requester_id"=> "#{@workflow_requester}",
				"profile_id"=> "#{profile_id}",
				"requester_type": "NeprofileUser"
			}
		}
		@api.make_request('POST', 'workflow_sessions', response_header: nil, param_hash: {}, request_json: req_json.to_json)
	end

	def process
		if @test_mode
			p 'testing'
			pids=get_profile_ids
			# run_workflow(@test_profile)
		else
			profile_ids = get_profile_ids
			# p profile_ids
			profile_ids.each do |profile|
				p profile
				run_workflow(profile)
				if @request_buffer > 0
					p "Buffering #{@request_buffer} seconds"
					sleep(@request_buffer)
				end
			end
		end
		report
	end
end

WorkflowHelper.new.process