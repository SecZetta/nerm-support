require 'json'
require 'net/http'
require 'uri'
require 'csv'
require 'net/https'
require 'fileutils'

def getConfiguration(configFile)

	file = File.read(configFile)
	mappings = JSON.parse(file)
	return mappings

end

def requestGet(uriEnd)

	uri = URI.parse("#{$NEProfileURL}/api/#{uriEnd}")
	request = Net::HTTP::Get.new(uri)
	request.content_type = "application/json"
	request["Authorization"] = "Token token=#{$apiToken}"
	request["Accept"] = "application/json"
	req_options = {
		read_timeout: 50,
		use_ssl: true,
		verify_mode: OpenSSL::SSL::VERIFY_NONE
	}
	response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
		http.request(request)
	end
	return response
end

def advancedSearch(body)

	uri = URI.parse("#{$NEProfileURL}/api/advanced_search/run")
	request = Net::HTTP::Post.new(uri)
	request.content_type = "application/json"
	request["Authorization"] = "Token token=#{$apiToken}"
	request["Accept"] = "application/json"
	request.body = body
	req_options = {
		read_timeout: 50,
		use_ssl: true,
		verify_mode: OpenSSL::SSL::VERIFY_NONE
	}
	response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
		http.request(request)
	end
	return response

end

def requestPostPatch (uriEnd, requesttype, formatted_body)
	p uriEnd, requesttype, formatted_body
	#json_array.each { |batch|
	uri = URI.parse("#{$NEProfileURL}/api/#{uriEnd}")
	case requesttype
		when 'create'
			#File.write("../logs/ImportRecords.log", "#{Time.now}: CREATE\n", mode: "a")
			request = Net::HTTP::Post.new(uri)
		when 'update'
			request = Net::HTTP::Patch.new(uri)
		else request = ''
	end
	request.content_type = "application/json"
	request["Authorization"] = "Token token=#{$apiToken}"
	request["Accept"] = "application/json"
	request.body = formatted_body.to_json unless formatted_body == ''
	req_options = {
		read_timeout: 50,
		use_ssl: true,
		verify_mode: OpenSSL::SSL::VERIFY_NONE
	}
	response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
		http.request(request)
	end

	File.write("../logs/ImportRecords.log", "#{Time.now}: Request body: #{request.body}\n", mode: "a")
	File.write("../logs/ImportRecords.log", "#{Time.now}: Respose: #{response}\n", mode: "a")
	File.write("../logs/ImportRecords.log", "#{Time.now}: Respose: #{response.body}\n", mode: "a")
	
end

## Make an API GET request in batches for performance reasons
def getProfilesByType(typeId)
	output = Array.new()
	inc = 0
	result = JSON.parse(requestGet("profiles?limit=50&profile_type_id=#{typeId}").body)["profiles"]
	until result.nil? do
		result.each { |x| output << x}
		inc +=1
		result = JSON.parse(requestGet("profiles?limit=50&profile_type_id=#{typeId}&offset=#{(inc)*50}").body)["profiles"]
	end
	return output
end

## Get IDs from existing profiles records
def getProfileIDsByName(profiles)
	output = Hash.new()
	profiles.each { |profile| output[profile["name"]] = profile["id"] }
	return output
end

def getProfileIDsByLogin(profiles)
	output = Hash.new()
	profiles.each { |profile| output[profile["name"]] = profile["id"] }
	return output
end


## Get the ID for a specific profile by it's name
def getProfileIDByTypeAndName(profileTypeID, value)

	result = JSON.parse(requestGet("profiles?profile_type_id=#{profileTypeID}&name=#{value}").body)["profiles"][0]["id"]
	return result
end

## Make an API GET request in batches for performance reasons
def makeAPIGet(uriEND, header)
	output = Array.new()
	inc = 0
	result = JSON.parse(requestGet("#{uriEND}?limit=50").body)["#{header}"]
	until result.nil? do
		result.each { |x| output << x}
		inc +=1
		result = JSON.parse(requestGet("#{uriEND}?limit=50&offset=#{(inc)*50}").body)["#{header}"]
	end
	return output
end

## Map Profile Types ##
def mapProfileTypes
	ptmap = Hash.new
	makeAPIGet('profile_types','profile_types').each { |x| ptmap[x['name']] = x['id']}
	return ptmap
end

## Read in csv import ##
def csvToHash(file, delimiter)
	#File.write("../logs/ImportRecords.log", "#{Time.now}: ok\n", mode: "a")
	if(File.exist?("#{file}"))
	#	File.write("../logs/ImportRecords.log", "#{Time.now}: InCSVtoHash\n", mode: "a")
		time = Time.new
		file_details = []
		CSV.foreach("#{file}", encoding: "UTF-8", headers: true, col_sep: delimiter, quote_char: '"') do |row|
			file_details << row.to_hash
		end
		return file_details
	else
		data_hash = Hash.new
		return data_hash
	end
end

def getContribID(user_id,practice_id)

	response = requestGet("/user_profiles?user_id=#{user_id}&profile_id=#{practice_id}").body
	contrib_id = JSON.parse(response)["user_profiles"][0]["id"]
	return contrib_id
end

def getUserIDByLogin(num,login,userHashcopy)

	response = requestGet("/users?login=#{login}").body
	user_id = JSON.parse(response)["users"][0]["id"]
	userHashcopy[num]["user_id"] = user_id
	return user_id
end

def getProfileIDByName(num,name, userHash)
	response = requestGet("/profiles?name=#{name}").body
	id = JSON.parse(response)["profiles"][0]["id"]
	userHash[num]["profile_id"] = id
	#return id = JSON.parse(response)["profiles"][0]["id"]
end

def getPracticeProfileIDByName(num,name, userHash)
	response = requestGet("/profiles?name=#{name}").body
	practice_id = JSON.parse(response)["profiles"][0]["id"]
	userHash[num]["practice_id"] = practice_id
	#return id = JSON.parse(response)["profiles"][0]["id"]
end


def getUserIDByEmail(email)
	response = requestGet("/users?email=#{email}").body
	return JSON.parse(response)["users"][0]["id"]
end

def syncProfiles(profiletypeid, configuration, inputHashArray)

	## This function looks up IDs for existing records to update (PATCH). If it does not exist the record is created (POST)

	profileArray = Array.new
	# Map fields to attributes in NEProfile
	inputHashArray.each { |row|
		profile = Hash.new

			profile["profile_type_id"] = profiletypeid
			profile["status"] = 1 
			profile["attributes"] = Hash.new
			configuration["fields"].each { |key, value|

				case value["type"] 
				when "text"
					#File.write("../logs/ImportRecords.log", "#{Time.now}: Text\n", mode: "a")
					profile["attributes"][value["attribute"]] = row[key]

				when "user"
					str = row[key].to_s
					userList = str.split(',')

					idList = []
					userList.each {|x| 
						case value["parameter"]
						when "email"
							idList << getUserIDByEmail(x)
						when "login"
							idList << getUserIDByLogin(x)
						end
					}
					profile["attributes"][value["attribute"]] = idList.join(',')

				when "profile"
					profile["attributes"][value["attribute"]] = getListofProfileIDsFromNames($profileTypeIDs[value["profile type"]], row[key])
				end
			}
			profile["name"] = row[configuration["profile naming 1"]]

			if !configuration["profile naming 2"].nil? && !row[configuration["profile naming 2"]].nil?
				profile["name"] = profile["name"] + " " + row[configuration["profile naming 2"]]
			end
			if !configuration["profile naming 3"].nil? && !row[configuration["profile naming 3"]].nil?
				profile["name"] = profile["name"] + " " + row[configuration["profile naming 3"]]
			end
		profileArray << profile

	}
	# Get IDs for existing profiles
	ids = getProfileIDsByName(getProfilesByType(profiletypeid))
	
	# Bundle into batches of 50 or less
	profileArray.each_slice(50) { |batch| 

		updateArray = Array.new
		createArray = Array.new

		batch.each { |record|
			id = 0
			if !ids[record["name"]].nil?
				id = ids[record["name"]]
				record["id"] = id
				updateArray << record
			else
				createArray << record
			end
		}
		# Make POST request to create
		if createArray.length != 0
			creates = Hash.new
			creates = {"profiles" => createArray}
			requestPostPatch("profiles", "create", creates)
		end
		# Make PATCH request to update
		if updateArray.length != 0
			updates = Hash.new
			updates = {"profiles" => updateArray}
			requestPostPatch("profiles", "update", updates)
		end
	}

end

def importUsers(userHash)

	userHash.each_slice(50) { |batch|
		userHash = Hash.new
		userArray = Array.new
		userHash["users"] = userArray
		batch.each { |user|
			eachUserHash = Hash.new
			eachUserHash["name"] = user["DISPLAY_NAME"]
			eachUserHash["login"] = user["LOGIN"]
			eachUserHash["email"] = user["EMAIL_ADDRESS"]
			eachUserHash["status"] = 1
			eachUserHash["type"] = "NeprofileUser"
			eachUserHash["group_strings"] = user["ROLES"]
			userArray << eachUserHash
		}
		requestPostPatch('users', 'create', userHash)
	}
end

def importNEAUsers(userHash)
	userHashcopy = userHash
	userHash.each_slice(50) { |batch|
		userHash = Hash.new
		userArray = Array.new
		userHash["users"] = userArray
		batch.each { |user|
			eachUserHash = Hash.new
			eachUserHash["name"] = user["Name"]
			eachUserHash["email"] = user["Email"]
			eachUserHash["login"] = user["Login"]
			eachUserHash["profile_id"] = user["profile_id"]
			eachUserHash["status"] = 1
			eachUserHash["group_strings"] = "NEaccess_Dev_PM"
			eachUserHash["type"] = "NeaccessUser"
			userArray << eachUserHash
		}
		requestPostPatch('users', 'create', userHash)
	}
	PracticeConnection(userHashcopy)
end

def GETProfileID(userHash)
	p userHash
	num = userHash.length - 1
	while num >= 0
		nome = userHash[num]["Name"]
		practice = userHash[num]["Practice"]
		p nome
		getProfileIDByName(num, nome, userHash)
		getPracticeProfileIDByName(num, practice, userHash)
		num = num - 1
	end
	importNEAUsers(userHash) #creating user and linking profiles
	#PracticeConnection(userHash)
end

def getListofProfileIDsFromNames(profileTypeID, profileNames)
	
	# Given a list of profile names like "Department A|Department B|Department C"
	strProfiles = profileNames.split("|")
	profiles = ""
	
	strProfiles.each{ |profile|
		profiles = profiles + "#{getProfileIDByTypeAndName(profileTypeID, profile)},"
	}
	# return 
	return profiles.chomp!(",")
end