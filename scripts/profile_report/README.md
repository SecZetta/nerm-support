# Profile Report Script
Script that can use either an Advanced Search or the Profiles endpoint to create a report. 

# Usage
- Should only have to modify the "Static Value" data at the top of the script for basic usage (Lines 13-24).
    - $Profile_Type_ID : used in the Advnaced Search json body and the /profiles endpoint to pull back all profiles of that type
    - $apitoken : the token to use for the API calls into the tenant
    - $Tenant : the actual tenant we will be calling into. Used for the baseUrl and the CSV title
    - $baseUrl : what we use to create the HTTP Request URI. May need to change the domain or from .com to .ca / .eu etc
    - $limit : the default limit that the API calls will use (There are default overrides if this is set too high)
    - $default_offset : Default offset value to use when makeing the calls. Can be set to something other than 0 for testing
    - $get_limit  : the absolute limit for the number of profiles to return. Can be used in testing to only return a subset of profiles (IE: 10k vs 100k)
    - $Path : the type of Request to make (/advanced_search vs  /profiles endpoint)
    - $Request_json : the JSON body for an Advanced Search to use. 

## To-Do
- Create caching of profile records to avoid potential errors of memory usage
- Add other query parameters for /profiles (status and exclude_attributes mainly, maybe order for created_at DESC etc ? )
- Pass in limit, offset, tenat, token, etc as arguments from on command line
- Use a /profiles_types look up for the Profile Type ID, so you can just select from a list