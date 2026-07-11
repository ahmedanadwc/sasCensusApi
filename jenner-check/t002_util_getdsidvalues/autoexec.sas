/* jenner-check autoexec for t002_util_getdsidvalues */
options obs=100; /* cap input rows for the captured run */

/* Mock of the APILIB._API_ALL_DATA registry table that
   censusapi_getAllDataSets.sas normally builds from the live Census Data
   API's data.json feed. util_getDsIdValues.sas only reads three columns
   from it (_ROWID_, ds_unique_id, BaseURL), which is all this stand-in
   carries -- rows modeled on real Census dataset base URLs. */
data work._api_all_data;
  length ds_unique_id $25 BaseURL $200;
  infile datalines dsd truncover;
  input _ROWID_ ds_unique_id $ BaseURL $;
  datalines;
1,_1_dec2000sf1,http://api.census.gov/data/2000/dec/sf1/
2,_2_dec2000sf3,http://api.census.gov/data/2000/dec/sf3/
3,_3_acs1_2021,https://api.census.gov/data/2021/acs/acs1/
4,_4_cbp_1986,http://api.census.gov/data/1986/cbp/
;
run;
