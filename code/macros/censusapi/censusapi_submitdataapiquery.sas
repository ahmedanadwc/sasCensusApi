/**
  @file censusapi_submitdataapiquery.sas
  @brief Submits queries which inturn parses out the returned 
  JSON response into SAS data sets
  @details
  1. Checks the number of requested variables in the specified apiGetClause 
  and dynamically re-writes the API query into one or several 
  %censusapi_getDataApiQueryRspns macro calls using the chunked query with
  a maximum of 50 variables per macro call.
  2. Submits these chunked queries in sequence, which inturn parses out the 
  returned JSON response into SAS data sets.
  3. Loops through the generated response data sets and merges them into a 
  single output data set.

      Usage Example:
      %censusapi_submitDataApiQuery(p_apiBaseURL=%STR(https://api.census.gov/data/2000/cps/basic/sep?)
        , p_apiGetClause=%STR(get=PXORIGIN,PRHSPNON,PRDTCOW2,PXMJNUM,PRDTCOW1,PXNLFACT,PULBHSEC,PEDWAVR)
        , p_apiForClause=%bquote(for=county:*)
        , p_apiInClause=%bquote(in=state:01,02,21,11&PEEDUCA=39)
        , p_dsUniqueId=_114_cps_2000, p_outDsName=work.test_query
        , p_dataApiKey=&g_apiKey, p_maxVarCount=48)

  @param [in] p_apiBaseURL= The Data API Base URL. Required
  @param [in] p_apiGetClause= The Data API get= Clause. Required
  @param [in] p_apiForClause= The Data API for= Clause. Required
  @param [in] p_apiInClause= The Data API in= Clause. Optional, depends on the GeoHierarchy requirements
  @param [in] p_dsUniqueId= Internal Data set Unique ID. Required
  @param [in] p_outDsName= The output data set name. Required
  @param [in] p_dataApiKey= Personal Data API Key. Optional
  @param [in] p_maxVarCount= Maximum number of variables per set. Default=50

  <h4> SAS Macros </h4>
  @li censusapi_getdataapiqueryrspns.sas

  @version SAS 9.4
  @author Ahmed Al-Attar

**/

%MACRO censusapi_submitDataApiQuery(
  p_apiBaseURL=
, p_apiGetClause=
, p_apiForClause=
, p_apiInClause=
, p_dsUniqueId=
, p_outDsName=
, p_dataApiKey=&g_apiKey
, p_maxVarCount=50);

	%LOCAL
		l_sTime
		l_eTime
		l_rTime
		l_rc
		l_msg
		;

	%LOCAL
		l_outDsLib
		l_outDsName
		l_getVars
		l_varsCount
		l_apiForClause
		l_apiInClause
		l_dataApiKey
		;

	* Record Starting Time;
	%let l_sTime = %sysfunc(time());

	/********** BEGIN -- Macro Parameter Validation **********/

	%if (%superq(p_apiBaseURL) EQ ) %then
	%do;
		/* Missing p_apiBaseURL value in macro call */
		%let l_rc  = 1;
		%let l_msg = ERROR: censusapi_submitDataApiQuery: p_apiBaseURL is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_apiGetClause) EQ ) %then
	%do;
		/* Missing p_apiGetClause value in macro call */
		%let l_rc  = 2;
		%let l_msg = ERROR: censusapi_submitDataApiQuery: p_apiGetClause is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_apiForClause) EQ ) %then
	%do;
		/* Missing p_apiForClause value in macro call */
		%let l_rc  = 3;
		%let l_msg = ERROR: censusapi_submitDataApiQuery: p_apiForClause is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	/*
	%if (%superq(p_apiInClause) EQ ) %then
	%do;
	*/
		/* Missing p_apiInClause value in macro call */
	/*
		%let l_rc  = 4;
		%let l_msg = ERROR: censusapi_submitDataApiQuery: p_apiInClause is invalid. Please specify non-missing value;
		%goto exit;
	%end;
	*/

	%if (%superq(p_dsUniqueId) EQ ) %then
	%do;
		/* Missing p_dsUniqueId value in macro call */
		%let l_rc  = 5;
		%let l_msg = ERROR: censusapi_submitDataApiQuery: p_dsUniqueId is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_outDsName) EQ ) %then
	%do;
		/* Missing p_outDsName value in macro call */
		%let l_rc  = 6;
		%let l_msg = ERROR: censusapi_submitDataApiQuery: p_outDsName is invalid. Please specify non-missing value;
		%goto exit;
	%end;
	%else
	%do;
		%if (%index(&p_outDsName,%str(.)) EQ 0) %then
		%do;
			%let l_outDsLib=WORK;
			%let l_outDsName=%upcase(&p_outDsName);
		%end;
		%else
		%do;
			/* Capture Library and Data set Names from &p_outDsName */
			%let l_outDsLib=%upcase(%scan(&p_outDsName,1,%str(.)));
			%let l_outDsName=%upcase(%scan(&p_outDsName,2,%str(.)));
		%end;
	%end;

	/********** END -- Macro Parameter Validation **********/

	%let l_getVars    = %SCAN(%superq(p_apiGetClause),2,%STR(=));
	%let l_varsCount  = %EVAL(%SYSFUNC(COUNTC(%SUPERQ(l_getVars),%STR(,))) +1);
	%let l_dataApiKey = ;
	/*%put &=l_varsCount;*/

	%let l_apiForClause =;
	%let l_apiInClause=;

	%let l_apiForClause = %SYSFUNC(TRANWRD(%SUPERQ(p_apiForClause),%STR(%(),%NRSTR(%%%() ));
	%if (%superq(p_apiInClause) NE ) %then
		%let l_apiInClause  = %SYSFUNC(TRANWRD(%SUPERQ(p_apiInClause),%STR(%(),%NRSTR(%%%() ));

	%if (%SUPERQ(p_dataApiKey) NE ) %then
		%let l_dataApiKey = %str(key=&p_dataApiKey);

	FILENAME queries TEMP;

	DATA _NULL_;
		FILE queries LRECL=32000;
		LENGTH 
			urlBase $1000 
			urlGet $28000 
			urlTail $3000
			;

		urlBase = "&p_apiBaseURL";
		urlTail = STRIP('&'||CATX('&',"%superq(p_apiForClause)","%superq(p_apiInClause)","%superq(l_dataApiKey)"));

	%if (&l_varsCount GT &p_maxVarCount) %then
	%do;
		%let l_chunkCount= %SYSFUNC(ceil(&l_varsCount/&p_maxVarCount));
		/* %put &=l_chunkCount; */

		%do c=1 %to %eval(&l_chunkCount - 1);
			%let l_var = %SCAN(%SUPERQ(l_getVars),%eval(&p_maxVarCount+1),%STR(,));
			%let l_vPos = %INDEX(%SUPERQ(l_getVars),&l_var);
			%let l_chunk = %SUBSTR(%SUPERQ(l_getVars),1,%eval(&l_vPos - 2));
			%let l_getVars = %SUBSTR(%SUPERQ(l_getVars),&l_vPos);
			/*%put &=l_var &=l_vPos &=l_chunk &=l_getVars;*/

			PUT '%censusapi_getDataApiQueryRspns(' ;
			urlGet = 'get='||"%SUPERQ(l_chunk)";
			PUT '  p_queryURL=%NRSTR(' urlBase +(-1) urlGet +(-1) urlTail +(-1) ')' ;
			PUT ", p_varFmtNamePreFix=&p_dsUniqueId" ;
			PUT ", p_outDsName=WORK._response_&c)" ;
		%end;
		%let l_chunk = &l_getVars;
		/* %put &=l_chunk; */
		PUT '%censusapi_getDataApiQueryRspns(' ;
		urlGet = 'get='||"%SUPERQ(l_chunk)";
		PUT '  p_queryURL=%NRSTR(' urlBase +(-1) urlGet +(-1) urlTail +(-1) ')' ;
		PUT ", p_varFmtNamePreFix=&p_dsUniqueId" ;
		PUT ", p_outDsName=WORK._response_&c)" ;
	%end;
	%else 
	%do;
		PUT '%censusapi_getDataApiQueryRspns(' ;
		PUT '  p_queryURL=%NRSTR(' urlBase +(-1) "&p_apiGetClause" urlTail +(-1) ')' ;
		PUT ", p_varFmtNamePreFix=&p_dsUniqueId" ;
		PUT ", p_outDsName=WORK._response_)" ;
	%end;
	RUN;

	/* Run the generated chunked API queries */
	%INCLUDE queries;

	/* Compose the Final Outout Data set */
	%if (&l_varsCount GT &p_maxVarCount) %then
	%do;
	DATA &p_outDsName;
		%do c=1 %to %eval(&l_chunkCount - 1);
			%if (%SYSFUNC(EXIST(WORK._response_&c)) EQ 1) %then
			%do; 
			SET WORK._response_&c ;
			%end;
		%end;
		%if (%SYSFUNC(EXIST(WORK._response_&c)) EQ 1) %then
		%do; 
			SET WORK._response_&c ;
		%end;
	RUN;
	%end;
	%else 
	%do;
	PROC APPEND BASE=&p_outDsName DATA=WORK._response_; 
	RUN;
	%end;

	%goto finished;

	%exit:
		%PUT *** ERROR: censusapi_submitDataApiQuery  ***;
		%PUT *** l_RC must be zero (0).   ***;
		%PUT *** l_RC= &l_RC    .         ***;
		%PUT &l_MSG ;
		%PUT *** ERROR: censusapi_submitDataApiQuery  ***;

	%finished:
		/* Clean-up */
		PROC DATASETS LIB=WORK NOLIST NOWARN MT=DATA;
			DELETE _response_: / memtype=data;
		QUIT;
		%let l_eTime=%sysfunc(time());
		%let l_rTime=%sysfunc(putn(%sysevalf(&l_eTime - &l_sTime),time12.2));
		%PUT >>> censusapi_submitDataApiQuery :>>> Total RunTime = &l_rTime;

%MEND censusapi_submitDataApiQuery;