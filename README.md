# nerm-support
Repo to host scripts useful for supporting NERM customers

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
