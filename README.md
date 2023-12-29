# nerm-support
Repo to host scripts useful for supporting SailPoint's Non-Employee Risk management product. 

## NERM Scripts
### Available files:
- Bulk Cancel Session : Script that takes in IDs of workflow sessions to be closed and sends the API requests
- Bulk Import Profiles : This is a fairly robust way to import users and profiles from CSV files. Please find the full README in the `bulk_import_profiles` folder
- Generic Batch Scripting : Script that mimics a Batch workflow by using an Advanced Serach to find Profiles that match specified critera and then runs a Workflow against them
- Profile Counts : Script that pulls a count of each Profile Type for Active Profiles in a tenant
- Profile Report : Script that can use either an Advanced Search or the Profiles endpoint to create a CSV report of Profiles. 
- Profile UID to ID : Script to convert Profile UIDs to the GUIDs by using the UID to get the Profile 

## NERM CLI tool
We have added a CLI Tool that can be used to run similar processes that are defined in the scripts here. Currently, this is limited to Pulling data, but we are working on adding POST / PATCH operations

### CLI Usage: 

Start up a terminal and navigate to the `\nerm-suport\nerm_cupport-cli` folder
From that folder, run the cli tool with `ruby .\nerm.rb`
You will then be persented with the available options:

image

You can utilize the Tab key to autocomplete your typing for arguments and see what options are available.

##### This Repo is currently managed solely by Zachary Tarantino-Woolson and should be considered "Community Support" and Not officially supported by SailPoint.