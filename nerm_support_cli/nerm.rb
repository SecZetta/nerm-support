require 'optparse'
require 'dotenv/load'
require 'net/http'
require 'net/https'
require 'uri'
require 'json'
require 'csv'

module NERMCLI
    class Parser
        def self.parse(options)
            opt_parser = OptionParser.new do |parser|
                parser.banner = "Usage: nerm.rb [options]"

                parser.on("-e", "--env", Array, "Allows you to set up a .env file to use for API calls") do |list|
                    puts "Specify the Environment (production, test, dev) you want to set values for:"
                    enviro=gets.chomp
                    
                    if File.exists?(".env.#{enviro}")
                        puts ".env.#{enviro} already exists. Enter 'r' to read the current environment values for #{enviro} or Do you wish to overwrite this environment with new data? (y/n)"
                        loop do
                            answer=gets.chomp
                            case answer
                            when "r"
                                env_vars=Dotenv.parse(".env.#{enviro}")
                                puts env_vars
                                puts "Do you wish to overwrite this environment with new data? (y/n)"
                            when "y"
                                puts "Specify the Tenant subdomain for the #{enviro} environment (IE: enter example for example.nonemployee.com):"
                                tenatVal=gets.chomp
                                puts "Specify the API Token value for the #{enviro} environment (Do not include 'Bearer' or 'Token token=' etc):"
                                apiKey=gets.chomp
                                File.open(".env.#{enviro}", "w") do |f|
                                    f.puts("TENANT=#{tenatVal}")
                                    f.puts("API_KEY=#{apiKey}")
                                end
                                break
                            when "n"
                                puts "exiting.."
                                break
                            else
                                puts 'invalid input..'
                            end
                        end
                    elsif !File.exists?(".env.#{enviro}")
                        puts ".env.#{enviro} does not yet exist in this working directory. Creating a .env.#{enviro} .."
                        puts "Specify the Tenant subdomain for the #{enviro} environment (IE: enter example for example.nonemployee.com):"
                        tenatVal=gets.chomp
                        puts "Specify the API Token value for the #{enviro} environment (Do not include 'Bearer' or 'Token token=' etc):"
                        apiKey=gets.chomp
                        File.open(".env.#{enviro}", "w") do |f|
                            f.puts("TENANT=#{tenatVal}")
                            f.puts("API_KEY=#{apiKey}")
                        end
                    end
                end

                parser.on("--pull_profiles","Pull Profiles from an environment using specified arguments") do
                    puts "Specify the Environment (production, test, dev) you want to pull Profiles from:"
                    enviro=gets.chomp
                    env_vars=Dotenv.parse(".env.#{enviro}")
                    NERMCLI::pull_profiles(env_vars)
                end

                parser.on("--profile_count","Pull a count of all Profiles in an environment") do
                    puts "Specify the Environment (production, test, dev) you want to pull a Profile count from:"
                    enviro=gets.chomp
                    env_vars=Dotenv.parse(".env.#{enviro}")
                    NERMCLI::profile_count(env_vars)
                end

                parser.on("-h", "--help", "Prints this help") do
                    puts parser
                    exit
                end
            end

            opt_parser.parse!(options)
        end
    end

    module_function

    def make_request(path, env_vars, param_hash: {}, request_json: nil)
        if path.nil?
            puts "No Path Specified"
            return
        end

        uri = URI.parse("https://#{env_vars["TENANT"]}.nonemployee.com/api/#{path}?#{URI.encode_www_form(param_hash)}")
        request = Net::HTTP::Get.new(uri)

        # p uri
    
        request.content_type = "application/json"
        request["Authorization"] = "Token token=#{env_vars["API_KEY"]}"
        request["Accept"] = "application/json"
    
        req_options = {
            read_timeout: 60,
            use_ssl: true,
            verify_mode: OpenSSL::SSL::VERIFY_NONE
        }
        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
            http.request(request)
        end

        case response
            when Net::HTTPSuccess
                return response
            when Net::HTTPUnauthorized
                p "#{response.code} | #{response.message}: Check API token"
                return response
            when Net::HTTPServerError
                p "#{response.code} | #{response.message}: try again later?"
                return response
        end

        return response
    end

    def get_single_p_type_total(env_vars,param_hash)
        total_count_param_hash={}
        total_count_param_hash["profile_type_id"]=param_hash["profile_type_id"]
        total_count_param_hash["exclude_attributes"]="true"
        total_count_param_hash["limit"]=1
        total_count_param_hash["metadata"]="true"
        response = make_request("profiles", env_vars, param_hash:total_count_param_hash)
        return JSON.parse(response.body)["_metadata"]["total"]
    end

    # Creates a CSV file 
	def create_csv(data_hash_array,headers,file_name)
        p "adding #{data_hash_array.size} data records to CSV"
        csv_file = CSV.open(File.join(Dir.pwd,Dotenv.parse("settings.env")["OUTPUT_FOLDER"],"/#{file_name}_#{Time.now.to_i}.csv"), "w",:write_headers=>true, :force_quotes=>true, :encoding=>'utf-8') do |csv|
            csv << headers
            data_hash_array.each do |r|
                row_arr = []
                headers.each do |h|		# Use headers as the key values to read each data row into the CSV so the attributes land in the right columns 
                    row_arr << "#{r[h]}"
                end
                csv << row_arr.dup
            end
        end
	end

    def print_table(result_array)
        puts
        column_headers = Array.new
        max_width_column=0

        result_array.each do |i|
            column_headers |= i.keys
        end

        column_headers.each do |c|
            if c.length>max_width_column
                max_width_column=c.length
            end
        end
        result_array.each do |r|
            r.each do |k,v|
                if v.to_s.length>max_width_column
                    max_width_column=v.to_s.length
                end
            end
        end

        max_width_column=max_width_column.to_i+3    # this it to account for the width of " | "

        row_text=""
        column_headers.each do |c|
            row_text+=sprintf('%*s',max_width_column.to_i,"#{c} | ")
        end
        puts row_text

        row_text=""
        for i in 1..column_headers.size do
            for x in 1..max_width_column.to_i do
                row_text+='-'
            end
        end
        puts row_text

        result_array.each do |r|
            row_text=""
            column_headers.each do |c|
                row_text+=sprintf('%*s',max_width_column.to_i,"#{r[c]} | ")
            end
            puts row_text
        end
        puts
    end
    

    def pull_profiles(env_vars)

        response = Hash.new			# Holds the HTTP response
        profiles = Array.new		# Holds the Profiles gathered by the HTTP request
        offset = 0              	# Set a local scope offset so it can be manipulated if the default is too high for the endpoint
        get_limit = eval(Dotenv.parse("settings.env")["DEFAULT_GET_LIMIT"])

        param_hash={}
        param_hash["offset"]=offset
        param_hash["limit"]=Dotenv.parse("settings.env")["DEFAULT_LIMIT_PARAM"].to_i

        profile_types_disp=[]
        profile_types_hash={}

        profile_types_resp= make_request("profile_types",env_vars).body
        JSON.parse(profile_types_resp)["profile_types"].each_with_index do |pt,x|
            profile_types_disp<<"#{x}. #{pt["name"]}"
            profile_types_hash["#{x}. #{pt["name"]}"]=pt["id"]
        end

        puts "Enter the number for the Profile Type that you want to pull profiles for:"
        puts profile_types_disp
        index=gets.to_i
        param_hash["profile_type_id"]=profile_types_hash[profile_types_disp[index]]

        total_count= get_single_p_type_total(env_vars,param_hash)

        puts "Enter the query parameters you want to add to the call (Can be left blank). Available parameters:"
        puts "--exclude_attributes (true/false), --name (String value of a Profile Name), --status (Active/Inactive/On Leave/Terminated), --metadata (true/false))"
        puts "Usage: --exclude_attributes true --status Active"
        query_parameters=gets.chomp.split

        unless query_parameters.nil? || query_parameters.empty?
            query_parameters.each_slice(2).to_a.each do |arr|
                case arr[0]
                when "-exclude_attributes","--exclude_attributes","-exclude","--exclude"
                    param_hash["exclude_attributes"]=arr[1]
                when "-name","--name","-n","--n"
                    param_hash["name"]=arr[1]
                when "-status","--status","-s","--s"
                    param_hash["status"]=arr[1]
                when "-metadata","--metadata","-m","--m"
                    param_hash["metadata"]=arr[1]
                end
            end
        end

        while offset != get_limit do
            param_hash["offset"]=offset
            puts "Requesting Profiles:  #{offset} / #{total_count}"
            response = make_request("profiles", env_vars, param_hash:param_hash)

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
                    offset += param_hash["limit"]
                
                    p "Hit the GET limit of #{$Get_Limit}, Stopping loop" if offset == $Get_Limit	
                when Net::HTTPUnauthorized
                    p "{response.code} | #{response.message}: Check API token"
                    break
                when Net::HTTPServerError
                    p "{response.code} | #{response.message}: try again later?"
                    break
                when "No Path Specified"
                    p "No Path was Specified for this Call"
                    break
                else
                    p "#{response.code} | #{response.message} - May be end of Profiles"
                    break
            end
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
                unless param_hash["exclude_attributes"]=="true"
                    i["attributes"].each do |k,v|
                        record_hash[k]=i["attributes"][k]
                    end
                end
        
                result_array << record_hash.clone
            end

            custom_csv_headers = Array.new
        
            result_array.each do |i|
                custom_csv_headers |= i.keys
            end
        
            create_csv(result_array,custom_csv_headers,env_vars["TENANT"])
        end
    end

    def profile_count(env_vars)
        response = Hash.new			# Holds the HTTP response
        profiles = Array.new		# Holds the Profiles gathered by the HTTP request
        offset = 0              	# Set a local scope offset so it can be manipulated if the default is too high for the endpoint
        get_limit = Dotenv.parse("settings.env")["DEFAULT_GET_LIMIT"].to_i

        param_hash={}
        param_hash["offset"]=offset
        param_hash["limit"]=Dotenv.parse("settings.env")["DEFAULT_LIMIT_PARAM"].to_i


        profile_types_hash={}

        profile_types_resp= make_request("profile_types",env_vars).body
        JSON.parse(profile_types_resp)["profile_types"].each do |pt|
            profile_types_hash[pt["name"]]=pt["id"]
        end

        profile_types_hash.each do |k,v|
            puts "Pulling Profile Count for #{k}"
            result_array=[]
            inactive_count=0

            param_hash["profile_type_id"]=v
            param_hash["exclude_attributes"]="true"
            param_hash["limit"]=1
            param_hash["metadata"]="true"

            param_hash["status"]="Active"
            response = make_request("profiles", env_vars, param_hash:param_hash)
            if response.code != "200"
                result_array<<0
            else
                result_array<< JSON.parse(response.body)["_metadata"]["total"]
            end

            param_hash["status"]="Inactive"
            response = make_request("profiles", env_vars, param_hash:param_hash)
            if response.code != "200"
                inactive_count+=0
            else
                inactive_count+= JSON.parse(response.body)["_metadata"]["total"].to_i
            end

            param_hash["status"]="On Leave"
            response = make_request("profiles", env_vars, param_hash:param_hash)
            if response.code != "200"
                inactive_count+=0
            else
                inactive_count+= JSON.parse(response.body)["_metadata"]["total"].to_i
            end

            param_hash["status"]="Terminated"
            response = make_request("profiles", env_vars, param_hash:param_hash)
            if response.code != "200"
                inactive_count<<0
            else
                inactive_count+= JSON.parse(response.body)["_metadata"]["total"].to_i
            end

            result_array<<inactive_count

            result_array<< result_array[0].to_i+result_array[1].to_i
            profile_types_hash[k]=result_array
        end

        unless profile_types_hash.empty? || profile_types_hash.nil? then
            result_array = []
            profile_types_hash.each do |k,v|
                record_hash = {}
                record_hash["Profile Type"]=k
                record_hash["Active"]=v[0]
                record_hash["Inactive"]=v[1]
                record_hash["Total"]=v[2]
        
                result_array << record_hash.clone
            end

            custom_csv_headers = Array.new
        
            result_array.each do |i|
                custom_csv_headers |= i.keys
            end

            puts "Do you want to print a table of the profile counts to the console or save the profile counts to a csv file? (table/file/both)"
            loop do
                answer=gets.chomp
                case answer
                when "t","ta","tab","tabl","table"
                    print_table(result_array)
                    break
                when "f","fi","fil","file"
                    create_csv(result_array,custom_csv_headers,"#{env_vars["TENANT"]}_profile_count")
                    break
                when "b","bo","bot","both"
                    print_table(result_array)
                    create_csv(result_array,custom_csv_headers,"#{env_vars["TENANT"]}_profile_count")
                    break
                else
                    puts 'Invalid Input. Try again..'
                end
            end            
        end
    end
end
NERMCLI::Parser.parse(ARGV)