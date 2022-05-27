SYSECHO "Calling the censusapi_getalldatasets macro to get the latest list/collection of available tables under the Census Data API";

/* Get the latest list of available tables under the Census Data API */
%censusapi_getalldatasets(p_outLibName=APILIB
, p_outDsName=_API_ALL_DATA
, p_dataJsonURL=%str(https://api.census.gov/data.json)
, p_reportOutputPath=&g_outputRoot)
