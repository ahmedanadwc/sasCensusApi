/**
  @file censusapi_getdsgroups.sas
  @brief Parses the Groups Metadata stored in the specified groups.json file
  @details
  Parses the Groups Metadata stored in the specified groups.json file into SAS Data Set using PROC HTTP and JSON Library engine.

      Usage Example:
      %censusapi_getDsGroups(p_outDsName=WORK._api_ds_grps
        , p_groupsJsonURL=%str(https://api.census.gov/data/2000/dec/sf3/groups.json))

  @param [in] p_groupsJsonURL= The Groups JSON URL. Required
  @param [in] p_outDsName= The output data set name. Required

  <h4> SAS Macros </h4>
  @li etl_shrinkmydata.sas

  @version SAS 9.4
  @author Ahmed Al-Attar

**/

%MACRO censusapi_getDsGroups(p_outDsName=, p_groupsJsonURL=);

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
		%let l_msg = ERROR: censusapi_getDsGroups: p_outDsName is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_groupsJsonURL) EQ ) %then
	%do;
		/* Missing p_groupsJsonURL value in macro call */
		%let l_rc  = 2;
		%let l_msg = ERROR: censusapi_getDsGroups: p_groupsJsonURL is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	/********** END -- Macro Parameter Validation **********/

	FILENAME apigrpsf TEMP;
	PROC HTTP
		METHOD="GET"
		URL="&p_groupsJsonURL"
		OUT=apigrpsf;

	 SYSECHO "Requesting the Groups JSON URL via Proc HTTP";
	RUN;

	/* Use SAS JSON Library Engine */
	LIBNAME apigrps JSON FILEREF=apigrpsf;

	/* Create consolidated datasets reporting list */
	DATA &p_outDsName(RENAME=(ordinal_groups=_g_ROWID_));
		SYSECHO "Processing the returned JSON response and generating the &p_outDsName output data set";

		LENGTH 
			ordinal_groups 8
			name $8
			description	$250
			variables $300
			;

		LABEL 
			name        = 'Name'
			description = 'Description'
			variables   = 'Variable List';

		RETAIN name 'N/A' description 'N/A' variables 'N/A';

		SET apigrps.Groups(DROP=ordinal_root);
		if (variables NE 'N/A') then
		do;
			variables = Tranwrd(STRIP(variables),'json','html');
		end;
	RUN;

	%let l_outDsName = &p_outDsName;
	SYSECHO "Shrinking the &p_outDsName data set";
	%etl_shrinkMyData(p_inDsName=&l_outDsName, p_outDsName=&l_outDsName)

	%goto finished;

	%exit:
		%PUT *** ERROR: censusapi_getDsGroups  ***;
		%PUT *** l_RC must be zero (0).   ***;
		%PUT *** l_RC= &l_RC    .         ***;
		%PUT &l_MSG ;
		%PUT *** ERROR: censusapi_getDsGroups  ***;

	%finished:
		/* --- Clean up --- */
		LIBNAME apigrps CLEAR;
		FILENAME apigrpsf;
		%let l_eTime=%sysfunc(time());
		%let l_rTime=%sysfunc(putn(%sysevalf(&l_eTime - &l_sTime),time12.2));
		%PUT >>> censusapi_getDsGroups :>>> Total RunTime = &l_rTime;

%MEND censusapi_getDsGroups;