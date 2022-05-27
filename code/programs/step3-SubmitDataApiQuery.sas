SYSECHO "Calling the censusapi_submitDataApiQuery macro to submit a Census Data Api query and generate SAS data set out of it";

/*OPTIONS MPRINT nosymbolgen SOURCE SOURCE2;*/
%censusapi_submitDataApiQuery(
  p_apiBaseURL=%STR(https://api.census.gov/data/2000/dec/sf1?)
, p_apiGetClause=%STR(get=P010014,P010015,P010010,P010011,P010012,P010013,P010003,P010004,P010005,P010006,P010001,P010002,P010007,P010008,P010009,NAME)
, p_apiForClause=%bquote(for=zip%20code%20tabulation%20area%20(3%20digit)%20(or%20part):*)
, p_apiInClause=%bquote(in=state:09,23,25,33,44,50,34,36,42,17,18,26,39,55,19,20,27,29,31,38,46)
, p_dsUniqueId=_799_dec_2000
, p_outDsName=work.sf1_response
, p_dataApiKey=&g_apiKey
, p_maxVarCount=48)

/*
Using (https://www.urlencoder.io/) ==> https://api.census.gov/data/2000/dec/sf4?get=HCT004001,NAME&for=tract%20(or%20part):9831&in=state:01%20county:091%20county%20subdivision:93123%20place/remainder%20(or%20part):99999&key=YOUR_KEY_GOES_HERE
Using (https://www.urldecoder.io/) ==> https://api.census.gov/data/2000/dec/sf4?get=HCT004001,NAME&for=tract (or part):9831&in=state:01 county:091 county subdivision:93123 place/remainder (or part):99999&key=YOUR_KEY_GOES_HERE
*/