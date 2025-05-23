/**
  @file step1-Build_DataApiCollection.sas
  @brief Illustrates how to build a collection of all available tables under the Census Data API

  <h4> SAS Macros </h4>
  @li censusapi_getalldatasets.sas

  <h4> Related Programs </h4>
 
  @version SAS 9.4
  @author Ahmed Al-Attar

**/

SYSECHO "Calling the censusapi_getalldatasets macro to get the latest list/collection of available tables under the Census Data API";

/* Get the latest list of available tables under the Census Data API */
%censusapi_getalldatasets(p_outLibName=APILIB
, p_outDsName=_API_ALL_DATA
, p_dataJsonURL=%str(https://api.census.gov/data.json)
, p_reportOutputPath=&g_outputRoot)
