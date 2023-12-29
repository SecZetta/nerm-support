require 'optparse'
require 'dotenv/load'
require 'net/http'
require 'net/https'
require 'uri'
require 'json'
require 'csv'
require 'readline'
require 'abbrev'

module NERMCLI
    class Parser
        def self.parse(options)
            opt_parser = OptionParser.new do |parser|
                parser.banner = "Usage: nerm.rb [options]"

                parser.on("--env_manager", Array, "Allows you to set up a .env file to use for API calls") do |list|
                    NERMCLI::environment_management()
                end
                
                parser.on("--pull_users","Search for Users based on query parameters and generate a CSV or print a Table to the CLI") do
                    NERMCLI::pull_users(NERMCLI::get_current_env)
                end

                parser.on("--pull_profiles","Pull Profiles from an environment using specified arguments to generate a CSV") do
                    NERMCLI::pull_profiles(NERMCLI::get_current_env)
                end

                parser.on("--profile_count","Pull a count of all Profiles in an environment") do
                    NERMCLI::profile_count(NERMCLI::get_current_env)
                end

                parser.on("--health_check","Run a Health Check against the current environment") do
                    NERMCLI::health_check(NERMCLI::get_current_env)
                end

                parser.on("--help", "Prints this help") do
                    puts
                    puts parser
                    puts "Type 'exit' to quit the NERM CLI"
                end
            end

            opt_parser.parse!(options)
        end
    end

    module_function
    
    ### HELPER FUNCTIONS

    def get_current_env
        env_vars={}
        loop do
            env_vars=Dotenv.parse(File.join(Dir.pwd,"environments",".env.current"))
            if env_vars.empty?
                puts "Current Evironment is Empty. Please Create or set an Environment"
                NERMCLI::environment_management()
            else
                break
            end
        end

        puts "Current Environment: #{env_vars["NAME"]}"
        return env_vars
    end

    def make_request(path, env_vars, param_hash: {}, request_json: nil)
        if path.nil?
            puts "No Path Specified"
            return
        end

        if path == "health_check"
            uri = URI.parse("https://#{env_vars["TENANT"]}/#{path}?#{URI.encode_www_form(param_hash)}")
        else
            uri = URI.parse("https://#{env_vars["TENANT"]}/api/#{path}?#{URI.encode_www_form(param_hash)}")
        end
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

    def get_profile_total(env_vars,param_hash)
        total_count_param_hash={}
        total_count_param_hash["profile_type_id"]=param_hash["profile_type_id"] unless param_hash["profile_type_id"].empty?||param_hash["profile_type_id"].nil?
        total_count_param_hash["exclude_attributes"]="true"
        total_count_param_hash["limit"]=1
        total_count_param_hash["metadata"]="true"
        response = make_request("profiles", env_vars, param_hash:total_count_param_hash)
        return JSON.parse(response.body)["_metadata"]["total"]
    end

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

    def exit_cli
        puts "Closing NERM CLI.."
        exit(0)
    end

    def print_table(result_array)
        puts
        column_headers = Array.new
        max_width_column=Hash.new

        result_array.each do |i|
            column_headers |= i.keys
        end

        column_headers.each do |c|
            max_width_column[c]=0
            if c.length>max_width_column[c].to_i
                max_width_column[c]=c.length.to_i
            end
        end

        result_array.each do |r|
            r.each do |k,v|
                if v.to_s.length>max_width_column[k].to_i
                    max_width_column[k]=v.to_s.length.to_i
                end
            end
        end

        # all the +3 s  are to account for the width of " | "

        row_text=""
        column_headers.each do |c|
            row_text+=sprintf('%*s',max_width_column[c].to_i+3,"#{c} | ")
        end
        puts row_text

        row_text=""
        max_width_column.each do |k,v|
            for x in 1..v.to_i+3 do
                row_text+='-'
            end
        end
        puts row_text

        result_array.each do |r|
            row_text=""
            column_headers.each do |c|
                row_text+=sprintf('%*s',max_width_column[c].to_i+3,"#{r[c]} | ")
            end
            puts row_text
        end
        puts
    end

    ### OPTION FUNTIONS

    def pull_users(env_vars)
        response = Hash.new			# Holds the HTTP response
        users = Array.new		# Holds the Profiles gathered by the HTTP request
        offset = 0              	# Set a local scope offset so it can be manipulated if the default is too high for the endpoint
        get_limit = eval(Dotenv.parse("settings.env")["DEFAULT_GET_LIMIT"])

        # Defuault Params
        param_hash={}
        param_hash["limit"]=Dotenv.parse("settings.env")["DEFAULT_LIMIT_PARAM"].to_i

        puts
        puts "Enter the query parameters you want to use to find a User (Can be left blank to pull all Users)"
        puts "-name '(String value in single quotes)'", "-status (Active/Disabled/Pending)", "-login (String value)", "-email (String value)", "-title '(String Value in single quotes)'"
        puts "Usage: -name 'John Smith' -status Active"
        # Set up Readline Autocomplete
        user_list = [
            '-name','-status','-login',
            '-email','-title',
            'exit','quit'
        ].sort
        comp = proc { |s| user_list.grep(/^#{Regexp.escape(s)}/) }
        Readline.completion_append_character = ""
        Readline.completion_proc = comp
        query_parameters = Readline.readline('> ', true)

        query_parameters=query_parameters.chomp.split(/\s([^-]+)/)
        
        exit_cli if query_parameters=="exit"||query_parameters=="quit"

        unless query_parameters.nil? || query_parameters.empty?
            query_parameters.each_slice(2).to_a.each do |arr|
                case
                when Abbrev.abbrev(["-name"],/-[a-zA-Z]/).keys.include?(arr[0])
                    param_hash["name"]=arr[1].strip.delete_prefix("'").delete_suffix("'")
                when Abbrev.abbrev(["-status"],/-[a-zA-Z]/).keys.include?(arr[0])
                    param_hash["status"]=arr[1].strip
                when Abbrev.abbrev(["-login"],/-[a-zA-Z]/).keys.include?(arr[0])
                    param_hash["login"]=arr[1].strip
                when Abbrev.abbrev(["-email"],/-[a-zA-Z]/).keys.include?(arr[0])
                    param_hash["email"]=arr[1].strip
                when Abbrev.abbrev(["-title"],/-[a-zA-Z]/).keys.include?(arr[0])
                    param_hash["title"]=arr[1].strip.delete_prefix("'").delete_suffix("'")
                when Abbrev.abbrev(["quit"],/[a-zA-Z]/).keys.include?(arr[0])||Abbrev.abbrev(["exit"],/[a-zA-Z]/).keys.include?(arr[0])
                    puts "Exiting.."
                    return
                end
            end
        end

        while offset != get_limit do
            param_hash["offset"]=offset
            puts "Requesting Users |  Offset: #{offset}"
            response = make_request("users", env_vars, param_hash:param_hash)

            case response
                when Net::HTTPSuccess
                    p "Success"
                    parsed = response.read_body
                    parsedresponse = JSON.parse(parsed)
                    
                    if parsedresponse["users"].empty? then 
                        p 'No More User, Stopping loop'
                        break
                    else
                        parsedresponse["users"].each do |i|
                            users << i
                        end
                    end
                    offset += param_hash["limit"]
                
                    p "Hit the GET limit of #{$Get_Limit}, Stopping loop" if offset == $Get_Limit	
                when Net::HTTPUnauthorized
                    p "#{response.code} | #{response.message}: Check API token"
                    break
                when Net::HTTPServerError
                    p "#{response.code} | #{response.message}: try again later?"
                    break
                when Net::HTTPBadRequest
                    p "#{response.code} | #{response.message}: #{JSON.parse(response.read_body)["error"]}"
                    break
                else
                    p "#{response.code} | #{response.message} - May be end of available Users"
                    break
            end
        end

        unless users.empty? then
            result_array = []
            users.each do |i|
                record_hash = {}
        
                # get top level attributes
                i.each do |k,v|
                    record_hash[k]=i[k] 
                end
        
                result_array << record_hash.clone
            end

            custom_csv_headers = Array.new
        
            result_array.each do |i|
                custom_csv_headers |= i.keys
            end

            # id,name,email,status
            simple_arr=Array.new
            result_array.each do |h|
                record_hash = {}
                record_hash["id"] = h["id"]
                record_hash["name"] = h["name"]
                record_hash["login"] = h["login"]
                record_hash["email"] = h["email"]
                record_hash["status"] = h["status"]
                record_hash["type"] = h["type"]
                simple_arr << record_hash.clone
            end
            
            puts "Do you want to print a table of the profile counts to the console or save the profile counts to a csv file? (table/file/both)"
            print_list = [
                'table','file','both',
                'exit','quit'
            ].sort
            comp = proc { |s| print_list.grep(/^#{Regexp.escape(s)}/) }
            Readline.completion_append_character = ""
            Readline.completion_proc = comp
            answer = Readline.readline('> ', true)
            loop do
                case 
                when Abbrev.abbrev(["table"],/[a-zA-Z]/).keys.include?(answer)
                    print_table(simple_arr)
                    break
                when Abbrev.abbrev(["file"],/[a-zA-Z]/).keys.include?(answer)
                    create_csv(result_array,custom_csv_headers,"#{env_vars["NAME"]}_user_report")
                    break
                when Abbrev.abbrev(["both"],/[a-zA-Z]/).keys.include?(answer)
                    print_table(simple_arr)
                    create_csv(result_array,custom_csv_headers,"#{env_vars["NAME"]}_user_report")
                    break
                when Abbrev.abbrev(["quit"],/[a-zA-Z]/).keys.include?(answer)||Abbrev.abbrev(["exit"],/[a-zA-Z]/).keys.include?(answer)
                    break
                else
                    puts 'Invalid Input. Try again..'
                end
            end
        end
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

        puts "Enter the query parameters you want to add to the call (Can be left blank). Available parameters:"
        puts "-exclude_attributes (true/false)", "-name (String value of a Profile Name)", "-status (Active/Inactive/On Leave/Terminated)"
        puts "Usage: -exclude_attributes true -status Active"
        profile_list = [
            '-exclude_attributes','-name','-status',
            'exit','quit'
        ].sort
        comp = proc { |s| profile_list.grep(/^#{Regexp.escape(s)}/) }
        Readline.completion_append_character = ""
        Readline.completion_proc = comp
        query_parameters = Readline.readline('> ', true)

        query_parameters=query_parameters.chomp.split(/\s([^-]+)/)
        
        exit_cli if query_parameters=="exit"||query_parameters=="quit"

        unless query_parameters.nil? || query_parameters.empty?
            query_parameters.each_slice(2).to_a.each do |arr|
                case
                when Abbrev.abbrev(["-exclude_attributes"],/-[a-zA-Z]/).keys.include?(arr[0])
                    param_hash["exclude_attributes"]=arr[1]
                when Abbrev.abbrev(["-name"],/-[a-zA-Z]/).keys.include?(arr[0])
                    param_hash["name"]=arr[1].strip.delete_prefix("'").delete_suffix("'")
                when Abbrev.abbrev(["-status"],/-[a-zA-Z]/).keys.include?(arr[0])
                    param_hash["status"]=arr[1]
                when Abbrev.abbrev(["quit"],/[a-zA-Z]/).keys.include?(arr[0])||Abbrev.abbrev(["exit"],/[a-zA-Z]/).keys.include?(arr[0])
                    puts "Exiting.."
                    return
                end
            end
        end
        total_count= get_profile_total(env_vars,param_hash)

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
        
            create_csv(result_array,custom_csv_headers,"#{env_vars["NAME"]}_profile_report")
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
            # p response.body
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
            print_list = [
                'table','file','both',
                'exit','quit'
            ].sort
            comp = proc { |s| print_list.grep(/^#{Regexp.escape(s)}/) }
            Readline.completion_append_character = ""
            Readline.completion_proc = comp
            answer = Readline.readline('> ', true)
            loop do
                case
                when Abbrev.abbrev(["table"],/[a-zA-Z]/).keys.include?(answer)
                    print_table(result_array)
                    break
                when Abbrev.abbrev(["file"],/[a-zA-Z]/).keys.include?(answer)
                    create_csv(result_array,custom_csv_headers,"#{env_vars["TENANT"]}_profile_count")
                    break
                when Abbrev.abbrev(["both"],/[a-zA-Z]/).keys.include?(answer)
                    print_table(result_array)
                    create_csv(result_array,custom_csv_headers,"#{env_vars["TENANT"]}_profile_count")
                    break
                when Abbrev.abbrev(["quit"],/[a-zA-Z]/).keys.include?(answer)||Abbrev.abbrev(["exit"],/[a-zA-Z]/).keys.include?(answer)
                    break
                else
                    puts 'Invalid Input. Try again..'
                end
            end
        end
    end

    def find_environments
        env_array = Array.new
        Dir.foreach(File.join(Dir.pwd,"environments")) do |x|
            env_array << x[5..-1] if /.env*/.match(x) # pull name of env 
        end

        return env_array
    end

    def environment_management()
        env_arr = NERMCLI::find_environments
        puts "Available Environments:"
        env_arr.each_with_index {|e,x| puts "#{x}. #{e}"}

        puts "Enter:"
        puts "   '-r #' to read the values of an available environment (This will be used throughout the CLI)"
        puts "   '-s #' to set an available env to be your 'current' environment  (This will be used throughout the CLI)"
        puts "   '-c' to create a new Environment"
        puts "   '-u #' to modify an existing environment (IE: -u 2)"
        puts "   or exit"

        loop do
            answer=gets.chomp
            case 
            when answer[0..1]=="-r"
                puts
                env_vars=Dotenv.parse(File.join(Dir.pwd,"environments",".env.#{env_arr[answer[-1].to_i]}"))
                env_vars.each {|k,v| puts "#{k} | #{v}"}
                puts "Enter:"
                puts "   '-r #' to read the values of an available environment (This will be used throughout the CLI)"
                puts "   '-s #' to set your current environment to an available env (This will be used throughout the CLI)"
                puts "   '-c' to create a new Environment"
                puts "   '-u #' to modify an existing environment (IE: -u 2)"
                puts "   or exit"
            when answer[0..1]=="-s"
                env_vars=Dotenv.parse(File.join(Dir.pwd,"environments",".env.#{env_arr[answer[-1].to_i]}"))
                File.open(File.join(Dir.pwd,"environments",".env.current"), "w") do |f|
                    f.puts("NAME=#{env_arr[answer[-1].to_i]}")
                    f.puts("TENANT=#{env_vars["TENANT"]}")
                    f.puts("API_KEY=#{env_vars["API_KEY"]}")
                end
                puts "#{env_arr[answer[-1].to_i]} set as the Currrent Environment"
                break
            when answer=="-c"
                puts "Specify a name for this environment (IE: sandbox, Production, etc):"
                env_name=gets.chomp
                break if env_name=="exit"

                puts "Specify the Tenant for this environment (IE: enter example.nonemployee.com):"
                tenatVal=gets.chomp
                break if tenatVal=="exit"

                puts "Specify the API Token value for this environment (Do not include 'Bearer' or 'Token token=' etc):"
                apiKey=gets.chomp
                break if apiKey=="exit"

                File.open(File.join(Dir.pwd,"environments",".env.#{env_name}"), "w") do |f|
                    f.puts("TENANT=#{tenatVal}")
                    f.puts("API_KEY=#{apiKey}")
                end
                break
            when answer[0..1]=="-u"
                env_vars=Dotenv.parse(File.join(Dir.pwd,"environments",".env.#{env_arr[answer[-1].to_i]}"))
                puts env_vars
                puts "Specify the Tenant for the #{env_arr[answer[-1].to_i]} environment (IE: enter example.nonemployee.com):"
                tenatVal=gets.chomp
                break if tenatVal=="exit"

                puts "Specify the API Token value for the #{env_arr[answer[-1].to_i]} environment (Do not include 'Bearer' or 'Token token=' etc):"
                apiKey=gets.chomp
                break if apiKey=="exit"

                File.open(File.join(Dir.pwd,"environments",".env.#{env_arr[answer[-1].to_i]}"), "w") do |f|
                    f.puts("TENANT=#{tenatVal}")
                    f.puts("API_KEY=#{apiKey}")
                end

                break
            when answer=="exit"
                exit_cli
            else
                puts 'invalid input..'
            end
        end
    end

    def health_check(env_vars)
        response=make_request("health_check",env_vars)
        
        puts "","Response Code: #{response.code}"
        puts "Healthy? : #{JSON.parse(response.body)['healthy']} | Message : #{JSON.parse(response.body)['message']}",""
    end
end

# # On CLI Start, print the Help
# NERMCLI::Parser.parse(["--help"])

# Get option entry
loop do
    # Set up Readline Autocomplete
    opt_list = [
        '--help', '--health_check', '--pull_profiles',
        '--pull_users', '--profile_count', '--env_manager',
        'exit','quit'
    ].sort
    comp = proc { |s| opt_list.grep(/^#{Regexp.escape(s)}/) }
    Readline.completion_append_character = ""
    Readline.completion_proc = comp

    NERMCLI::Parser.parse(["--help"])
    line = Readline.readline('> ', true)
    NERMCLI::exit_cli if (line.match?(/exit|quit/))

    NERMCLI::Parser.parse(["#{line}"])
end