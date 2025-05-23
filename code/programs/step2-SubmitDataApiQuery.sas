/**
  @file step2-SubmitDataApiQuery.sas
  @brief Illustrates the steps to submit a Census Data API query and generate a SAS data set out of it

  <h4> SAS Macros </h4>
  @li util_getdsidvalues.sas
  @li censusapi_getdsfullinfo.sas
  @li censusapi_submitdataapiquery.sas

  <h4> Related Programs </h4>
 
  @version SAS 9.4
  @author Ahmed Al-Attar

**/

%GLOBAL 
	g_dsRowId
	g_dsUniqueId
	;

SYSECHO "Calling the util_getDsIdValues macro to extract the data set's unique ID variables from the API metadata table ";
%util_getDsIdValues(p_apiBaseUrl=%str(http://api.census.gov/data/2000/dec/sf1/) 
,p_rtrnRowIDMacVarName=g_dsRowId 
,p_rtrnUniqueIDMacVarName=g_dsUniqueId)

SYSECHO "Calling the censusapi_getDsFullInfo macro to compose a complete Profile of the specified data set";
%censusapi_getDsFullInfo(p_apiListingLibName=APILIB, p_apiListingDsName=_API_ALL_DATA, p_dsRowId=&g_dsRowId)

SYSECHO "Calling the censusapi_submitDataApiQuery macro to submit a Census Data Api query and generate SAS data set out of it";
%censusapi_submitDataApiQuery(
  p_apiBaseURL=%STR(https://api.census.gov/data/2000/dec/sf1?)
, p_apiGetClause=%STR(get=P010014,P010015,P010010,P010011,P010012,P010013,P010003,P010004,P010005,P010006,P010001,P010002,P010007,P010008,P010009,NAME)
, p_apiForClause=%bquote(for=zip%20code%20tabulation%20area%20(3%20digit)%20(or%20part):*)
, p_apiInClause=%bquote(in=state:09,23,25,33,44,50,34,36,42,17,18,26,39,55,19,20,27,29,31,38,46)
, p_dsUniqueId=&g_dsUniqueId
, p_outDsName=work.sf1_response
, p_dataApiKey=&g_apiKey
, p_maxVarCount=48)

/*
Using (https://www.urlencoder.io/) ==> https://api.census.gov/data/2000/dec/sf4?get=HCT004001,NAME&for=tract%20(or%20part):9831&in=state:01%20county:091%20county%20subdivision:93123%20place/remainder%20(or%20part):99999&key=YOUR_KEY_GOES_HERE
Using (https://www.urldecoder.io/) ==> https://api.census.gov/data/2000/dec/sf4?get=HCT004001,NAME&for=tract (or part):9831&in=state:01 county:091 county subdivision:93123 place/remainder (or part):99999&key=YOUR_KEY_GOES_HERE
*/
