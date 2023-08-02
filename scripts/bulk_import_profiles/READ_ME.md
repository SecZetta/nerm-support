This is a fairly robust way to import users and profiles from CSV files.
I don't think it has errors at the moment, but that doesn't mean there
can't be. Feel free to adjust batch sizing.

This ZIP contains the following directories:

-   Data

    -   CSV files

        -   All fields use double quotes text qualifier, including
            column headers

```{=html}
<!-- -->
```
-   Configs

    -   ProfileConfig.json

        -   This file maps the CSV text headers to profile types and
            attributes

        -   It supports three kinds of objects

            -   Text

                -   Includes simple dates, drop downs, radio buttons

            ```{=html}
            <!-- -->
            ```
            -   Profiles

                -   Tries to find a specific profile given the profile
                    type specified and then assign it to the attribute
                    specified

            ```{=html}
            <!-- -->
            ```
            -   Users

                -   Tries to find a specific user mapping the value in
                    the CSV column to a user object with the parameter
                    specified

        ```{=html}
        <!-- -->
        ```
        -   Example

            -   I want to import existing Organizations from a CSV file
                with three columns, Name, Populations, Sponsor.

            -   Using the configuration shown below, each Organization's
                Population will be stored in the attribute
                "managed_types" on the Organization profile.

            -   Each Organization's Sponsor will be stored in the
                attribute "sponsor" after searching for the user who's
                email matches the value in the CSV file.

```{=html}
<!-- -->
```
-   Logs

    -   Minor logging. Could be improved.

```{=html}
<!-- -->
```
-   Scripts

    -   ImportUsers.rb

        -   If any imported profiles include references to users, like
            Sponsor, then run ImportUsers.rb before running
            SyncProfiles.rb

        -   At a minimum, you will need to change

            -   API Token

            -   URL

            -   CSV filename

    ```{=html}
    <!-- -->
    ```
    -   SyncProfiles.rb

        -   This will create new profiles and update existing ones

        -   If any imported profiles include references to other
            profiles, the other profiles will need to be imported first

        -   At a minimum, you will need to change

            -   API Token

            -   URL

            -   The order you wish to import the specific profile types

    ```{=html}
    <!-- -->
    ```
    -   Functions.rb

        -   You should not need to make changes here, but you might need
            to if you hit a problem
