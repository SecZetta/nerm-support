# CLI Tool to make API requests and generate files

## Configuration
There are default settings configured in the `settings.env` file. These are:
- OUTPUT_FOLDER : Currently set to `default_output_location` . This is where files generate by this CLI tool will be sent to.
- DEFAULT_LIMIT_PARAM : Currently set to `100`. This is the value which feeds the `limit` query parameter for GET requests.
- DEFAULT_GET_LIMIT : Currently set to `Float::INFINITY`. This is the value which controls when bulk GET requests will stop. At Infinity, this will GET records until all records are recieved

## Available Paths
- `-e , --env`` : This will allow a user to set up specific environment details (Tenant and API token) to be used in API Requests.
    - After sending in `-e`, you will be prompted to specify the environment you want to set up. This will find or create a `.env.<value>` file.
    - If an existing file is found for this environment, you can choose to read the data in that environment and/or overwrite it with new data. 
    - If no file is found, you will be prompted to set up the new environment details
- `--pull_profiles` : This will allow you to pull Profiles from an environment and pass in query parameters.
    - This will output the files to the default output location specified in the `settings.env`
    - After sending in `--pull_profiles`, you will be prompted to specify the environment to pull profiles from.
    - This will then display the available Profile Types you can select from to pull profiles.
    - Then, you can set query Parameters for the GET requests. Available query Parameters:
        - `--exclude_attributes` : True or False value. This is False by default. Setting this to True means that no attribute values will returned for the profiles.
        - `--name` : Takes a string value. This will search for Profiles that match the specified name
        - `--status` : Active/Inactive/On Leave/Terminated. This will search for Profiles that only have the set status, ignoring others.
        - `--metadata`: True or False. This is False by default. Setting this to True means that a `_metadata` obeject will be returned on the JSON response
- `--profile_count` : This will pull a count of all Profiles in an environment and either export the values to a file or display a table in the cli.
    - After sending in `-profile_count`, you will be prompted to specify the environment you want pull a Profile count for.
    - After which, you can choose to export that data to a file, display it as a table, or both. 