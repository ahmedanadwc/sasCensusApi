SYSECHO "Calling the censusapi_getDsFullInfo macro to compose a complete Profile of the specified data set";

/* OPTIONS MPRINT SOURCE SOURCE2; */

/* Compose a complete Profile of the specified data set */
/*%censusapi_getDsFullInfo(p_apiListingLibName=APILIB, p_apiListingDsName=_API_ALL_DATA, p_dsRowId=114)*/
%censusapi_getDsFullInfo(p_apiListingLibName=APILIB, p_apiListingDsName=_API_ALL_DATA, p_dsRowId=769)
%censusapi_getDsFullInfo(p_apiListingLibName=APILIB, p_apiListingDsName=_API_ALL_DATA, p_dsRowId=753)

