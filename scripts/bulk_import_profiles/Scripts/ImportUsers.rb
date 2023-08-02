require 'json'
require 'net/http'
require 'uri'
require 'csv'
require 'net/https'
require 'fileutils'
require_relative './Functions.rb'

$apiToken = 'XX'
$NEProfileURL = 'https://.mynonemployee.com'

## ------------------ Manage Logging File ------------------  ##
if(File.exist?("../Logs/ImportRecords.log"))
	time = Time.now
	if File.mtime("../Logs/ImportRecords.log").strftime("%Y-%m-%d") != time.strftime("%Y-%m-%d")
		FileUtils.mv "../Logs/ImportRecords.log", "../archive/ImportRecords_#{time.month}_#{time.day}_#{time.year}.log"
		File.open("../Logs/ImportRecords.log", "w")
	end
else
	File.open("../Logs/ImportRecords.log", "w")
end

File.write("../Logs/ImportRecords.log", "#{Time.now}: Beginning import\n", mode: "a")

#--------------------------------- Create User Objects --------------------------------------#
users = csvToHash("../Data/TEST",'"')
importUsers(users)

File.write("../logs/ImportRecords.log", "#{Time.now}: Finished import\n", mode: "a")