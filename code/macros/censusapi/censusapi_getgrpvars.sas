/**
  @file censusapi_getgrpvars.sas
  @brief Parses the Groups Metadata stored in the specified groups.json file
  @details
  Parses the Groups Metadata stored in the specified groups.json file 
  into SAS Data Set using PROC HTTP and JSON Library engine.

      Usage Example:
      %censusapi_getGrpVars(p_outDsName=WORK._api_ds_grps
        , p_grgVarsJsonURL=%str(https://api.census.gov/data/2000/dec/as/groups/H008.json))

  @param [in] p_outDsName= The output data set name. Required
  @param p_grgVarsJsonURL= The Groups JSON URL. Required

  <h4> SAS Macros </h4>
  @li etl_shrinkmydata.sas

  @version SAS 9.4
  @author Ahmed Al-Attar

**/

%MACRO censusapi_getGrpVars(p_outDsName=, p_grgVarsJsonURL=);

	%LOCAL
		l_sTime
		l_eTime
		l_rTime
		l_rc
		l_msg
		;

	%LOCAL
		l_outDsName;

	* Record Starting Time;
	%let l_sTime = %sysfunc(time());

	/********** BEGIN -- Macro Parameter Validation **********/

	%if (%superq(p_outDsName) EQ ) %then
	%do;
		/* Missing p_outDsName value in macro call */
		%let l_rc  = 1;
		%let l_msg = ERROR: censusapi_getGrpVars: p_outDsName is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_grgVarsJsonURL) EQ ) %then
	%do;
		/* Missing p_grgVarsJsonURL value in macro call */
		%let l_rc  = 2;
		%let l_msg = ERROR: censusapi_getGrpVars: p_grgVarsJsonURL is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	/********** END -- Macro Parameter Validation **********/

	FILENAME apigvrsf TEMP;
	PROC HTTP
		METHOD="GET"
		URL="&p_grgVarsJsonURL"
		OUT=apigvrsf;

	 SYSECHO "Requesting the Group Variables JSON URL via Proc HTTP";
	RUN;

	/* Use SAS JSON Library Engine */
	LIBNAME apigvars JSON FILEREF=apigvrsf;

	/* Create consolidated datasets reporting list */
	DATA &p_outDsName;
		SYSECHO "Processing the returned JSON response and generating the &p_outDsName output data set";

		LENGTH _v_ 4;
		FORMAT _v_ BEST8.;

		SET apigvars.alldata(KEEP=P2 P3 V Value WHERE=(V=1));
		BY P2 NOTSORTED;

		if (first.P2) then _v_+1;

		RENAME 
			P2 = Name
			p3 = Category;
		DROP V;
	RUN;

	%let l_outDsName = &p_outDsName;
	SYSECHO "Shrinking the &p_outDsName data set";
	%etl_shrinkMyData(p_inDsName=&l_outDsName, p_outDsName=&l_outDsName)

	%goto finished;

	%exit:
		%PUT *** ERROR: censusapi_getGrpVars  ***;
		%PUT *** l_RC must be zero (0).   ***;
		%PUT *** l_RC= &l_RC    .         ***;
		%PUT &l_MSG ;
		%PUT *** ERROR: censusapi_getGrpVars  ***;

	%finished:
		/* --- Clean up --- */
		LIBNAME apigvars CLEAR;
		FILENAME apigvrsf;
		%let l_eTime=%sysfunc(time());
		%let l_rTime=%sysfunc(putn(%sysevalf(&l_eTime - &l_sTime),time12.2));
		%PUT >>> censusapi_getGrpVars :>>> Total RunTime = &l_rTime;

%MEND censusapi_getGrpVars;