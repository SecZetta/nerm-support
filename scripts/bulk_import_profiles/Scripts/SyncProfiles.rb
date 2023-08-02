require 'json'
require 'net/http'
require 'uri'
require 'csv'
require 'net/https'
require 'fileutils'
require_relative './Functions.rb'

$apiToken = ''
$NEProfileURL = 'https://.mynonemployee.com'

# ------------------ Manage Logging File ------------------  ##
if(File.exist?("../logs/ImportRecords.log"))
	time = Time.now
	if File.mtime("../logs/ImportRecords.log").strftime("%Y-%m-%d") != time.strftime("%Y-%m-%d")
		FileUtils.mv "../logs/ImportRecords.log", "../archive/ImportRecords_#{time.month}_#{time.day}_#{time.year}.log"
		File.open("../logs/ImportRecords.log", "w")
	end
else
	File.open("../logs/ImportRecords.log", "w")
end

File.write("../logs/ImportRecords.log", "#{Time.now}: ----------------------Beginning import----------------------\n", mode: "a")


## ------------------ Main  ------------------  ##

$profileTypeIDs = mapProfileTypes()
File.write("../logs/ImportRecords.log", "#{Time.now}: Profile Types gathered\n", mode: "a")
configuration = getConfiguration("../Configs/ProfileConfig.json")
File.write("../logs/ImportRecords.log", "#{Time.now}: ProfileConfig.json read in\n", mode: "a")
$profileIDs = Hash.new()


#--------------------------------- Sync Profile Objects --------------------------------------#

File.write("../logs/ImportRecords.log", "#{Time.now}: Starting to import: Profile Test\n", mode: "a")
syncProfiles($profileTypeIDs["People"], configuration["Prof_test"], csvToHash("../Data/Prof_test.csv",","))
File.write("../logs/ImportRecords.log", "#{Time.now}: Import complete: Profile Test\n", mode: "a")

#File.write("../logs/ImportRecords.log", "#{Time.now}: Starting to import: Populations\n", mode: "a")
#syncProfiles($profileTypeIDs["Populations"], configuration["Populations"], csvToHash("../Data/Populations.csv",","))
#File.write("../logs/ImportRecords.log", "#{Time.now}: Import complete: Populations\n", mode: "a")

#File.write("../logs/ImportRecords.log", "#{Time.now}: Starting to import: Organizations\n", mode: "a")
#syncProfiles($profileTypeIDs["Organizations"], configuration["Organizations"], csvToHash("../Data/Organizations.csv",","))
#File.write("../logs/ImportRecords.log", "#{Time.now}: Import complete: Organizations\n", mode: "a")

File.write("../logs/ImportRecords.log", "#{Time.now}: ----------------------Finished import----------------------\n", mode: "a")