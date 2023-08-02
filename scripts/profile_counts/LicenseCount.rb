require_relative '.\NEPAPIUtil.rb'
require 'json'

class WorkflowHelper
	def initialize
		@start_time = Time.now

		@api = NEProfileAPI.new(
			host: '.seczetta.com',
			authorization_hash: {'Authorization': 'Token token='}
		)

		# test_mode = true will run the workflow against only the one profile specified.
		# This is to verify the workflow produces the correct outcome before running it against the whole batch
		# @test_mode = true
		
		# limit and offset for profile types GET
		@get_limit = 20
		@get_offset = 0

		# Where to output the CSV
		@output_location = "HOST_DATE.csv"

		# Headers for the final CSV, in order.
		@CSV_Headers = ["name", "active_count"]
		
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

	def get_profile_count(prof_type_id)
		get_params = {}
		get_params["limit"] = 1
		get_params["metadata"]= true
		get_params["profile_type_id"] = prof_type_id
		get_params["status"]="Active"

		res= @api.make_request('GET',"profiles", response_header: nil, param_hash: get_params)
		meta=JSON.parse(res["body"])
		if meta["error"]
			count = 0
		else
			count=meta["_metadata"]["total"]
		end

		return count
	end

	def get_profile_types
		get_params = {}
		prof_types =[]
		rec_hash={}

		get_params["limit"] = @get_limit
		get_params["metadata"]= true
		get_params["offset"]=@get_offset

		res = @api.bulk_get_request("profile_types", response_header: nil, param_hash: get_params, return_limit: Float::INFINITY)

		res["content"].each do |ptype|
			rec_hash["id"]=ptype["id"]
			rec_hash["name"]=ptype["name"]

			prof_types<<rec_hash.clone
		end

		return prof_types
	end

	def create_csv(data_hash_array, output_location)
		csv_file = CSV.open(output_location, "w", :write_headers=>true, :force_quotes=>false, :encoding=>'utf-8') do |csv|
		  csv.to_io.write "\uFEFF"
		  csv << @CSV_Headers
		  data_hash_array.each do |r|
			row_arr = []
			@CSV_Headers.each do |h|
			  row_arr << "#{r[h]}"
			end
			csv << row_arr.dup
			p csv
		  end
		end
	  end

	def process
		res=get_profile_types

		res.each do |cnt|
			count=get_profile_count(cnt["id"])
			p res
			p count
			cnt["active_count"] = count
		end

		create_csv(res,@output_location)

		report
	end
end

WorkflowHelper.new.process