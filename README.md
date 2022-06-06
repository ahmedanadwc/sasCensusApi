# sasCensusApi
Custom built SAS macro programs to extract data from the public Census Data API. These out of the box custom built SAS macro programs atreamline data acquisition and manipulation. They use the metadata supplied by the Census Data API registration to dynamically derive column type conversion and label assignments. As a minimum, Base SAS® Software, version 9.4 Maintenance 4 installation is required to run these macros. There is heavy use of the JSON LIBNAME statement, that was introduced in SAS 9.4 M4, to enable users to associate a libref with a JSON document.

To get started, assuming you already have a directory of all the artifacts in the repo, you'll need to 
1. Update your settings by modifying the <Installation directory>/config/setup.sas program, and populating the two variables listed below, before running it in your SAS session
  - %LET g_projRootPath = <Put your value here>;	*<---- Specify installation path. Do not include trailing slash!;
  - %LET g_apiKey = <Put your value here>;		*<---- Specify your Developer API Key.; 
  Note: You can use this link (https://api.census.gov/data/key_signup.html) to request a key;

2. Run the <Installation directory>/code/programs/step1-Build_DataApiCollection.sas in your SAS session, to collect metadata of the registered data sets in the Census Data API.
3. Run the <Installation directory>/code/programs/step2-SubmitDataApiQuery.sas in your SAS session, to illustrate how these macros can be used to extract data from the Census Data API.
