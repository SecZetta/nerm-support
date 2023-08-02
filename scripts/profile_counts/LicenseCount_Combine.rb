require_relative '.\NEPAPIUtil.rb'
require 'csv'

class WorkflowHelper
	def initialize
		@start_time = Time.now

		# Output file name for total count by customer
		@output_location_total_counts = "Total_License_Counts.csv"

		# Output file name for counts by Profile Type
		@output_location_by_type = "License_Counts_By_Profile_Type.csv"
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

	# Main process for the script
	def process
		# Check if files exist. If true, delete
		File.delete(@output_location_by_type) if File.exist?(@output_location_by_type)
		File.delete(@output_location_total_counts) if File.exist?(@output_location_total_counts)

		# Creates CSV file for "by_type" and adds headers
		File.open(@output_location_by_type, 'w') { |f| f.write("Profile Type,Active Count,Customer\n") }

		# Creates CSV file for "totals" and adds headers
		File.open(@output_location_total_counts, 'w') { |f| f.write("Customer,Total Count\n") }

		# Run through each .csv file in a Director
		Dir.glob('CSVs_May_2022/*.csv') do |csv_fn|
			# Total counter for each Customer
			total=0

			# Get Customer's Name from filename
			cust_name= csv_fn.split(/\/|\./)[1]

			# Create CSV array with Profile Types and Counts
			table= CSV.parse(File.read(csv_fn),headers: true)

			# Add the "Customer" Collumn to the array
			table["customer"]=cust_name

			# Write array data to output file.
			File.open(@output_location_by_type, 'a+') { |f| f.write(table.to_csv(write_headers:false)) }

			# Add all counts up to a total
			table.by_col[1].each{ |num| total+=num.to_i }

			# Write total count data to output file.
			File.open(@output_location_total_counts, 'a+') { |f| f.write("#{cust_name},#{total}\n") }
		end
		
		# Runtime report
		report
	end
end

# Runs the mail process
WorkflowHelper.new.process