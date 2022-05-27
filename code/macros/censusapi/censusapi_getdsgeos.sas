/*!
 ******************************************************
 * @author	Ahmed Al-Attar
 * @created	04/14/2022
 ******************************************************
 */

/**
******************************************************
* Parses the Data API query geographies illustrated in  
* the specified geography.json file into SAS Data Set,
* using PROC HTTP, JSON Library Engine and data step 
* processing.
*
* <br><br>Usage Example:<br>
* %censusapi_getDsGeos(p_outDsName=WORK._api_ds_all_geos
* , p_geoJsonURL=%STR(https://api.census.gov/data/2000/dec/sf1/geography.json))

* <br>
*
* @param p_outDsName	The output data set name. Required
* @param p_geoJsonURL	The Geography JSON URL. Required
******************************************************
*/

%MACRO censusapi_getDsGeos(p_outDsName=WORK._api_ds_all_geos, p_geoJsonURL=);

	%LOCAL
		l_sTime
		l_eTime
		l_rTime
		l_rc
		l_msg
		;

	%LOCAL
		l_outDsName
		l_requireDs
		l_wildcardDs
		;

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

	%if (%superq(p_geoJsonURL) EQ ) %then
	%do;
		/* Missing p_geoJsonURL value in macro call */
		%let l_rc  = 2;
		%let l_msg = ERROR: censusapi_getDsGroups: p_geoJsonURL is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	/********** END -- Macro Parameter Validation **********/

	/* ------------------------- */
	/* Get WORK._api_ds_all_geos */
	/* ------------------------- */
	FILENAME apigeosf TEMP;
	PROC HTTP
	 METHOD="GET"
	 URL="&p_geoJsonURL"
	 OUT=apigeosf;

	 SYSECHO "Requesting the Geographies JSON URL via Proc HTTP";
	RUN;

	LIBNAME apigeos JSON FILEREF=apigeosf;
	%let l_requireDs = 0;
	%let l_wildcardDs = 0;

	/* Create consolidated datasets reporting list */
	%if (%SYSFUNC(EXIST(apigeos.fips_requires))) %then
	%do;
		%let l_requireDs = 1;
		DATA WORK.geo_required(KEEP=ordinal_fips required)/VIEW=WORK.geo_required;
			LENGTH required $300;
			SET apigeos.fips_requires(KEEP=ordinal_fips requires:);
			ARRAY reqs {*} requires:;
			required = CATX(',',of reqs[*]);
		RUN;
	%end;

	%if (%SYSFUNC(EXIST(apigeos.fips_wildcard))) %then
	%do;
		%let l_wildcardDs = 1;
		DATA WORK.geo_wildcards(KEEP=ordinal_fips wildcards)/VIEW=WORK.geo_wildcards;
			LENGTH wildcards $300;
			SET apigeos.fips_wildcard(KEEP=ordinal_fips wildcard:);
			ARRAY wcrds {*} wildcard:;
			wildcards = CATX(',',of wcrds[*]);
		RUN;
	%end;

	DATA &p_outDsName;
		SYSECHO "Processing the returned JSON response and generating the &p_outDsName output data set";
		LENGTH
			ordinal_fips 8
			geoLevelId $4
			geoLevelDisplay $4 
			name $200
			referenceDate $10
			required $300 
			wildcards $300 
			optionalWithWCFor $100;

		%if ((&l_requireDs = 1) OR (&l_wildcardDs = 1))%then 
		%do;
			if (0) then SET 
				%if (&l_requireDs = 1) %then %do; WORK.geo_required %end;
				%if (&l_wildcardDs = 1) %then %do; WORK.geo_wildcards %end;
				;
		%end;
		SET apigeos.fips(DROP=ordinal_root);

		LABEL
			ordinal_fips		= 'GEO ROWID'
			required			= 'Required'
			wildcards			= 'Wildcards'
			name				= 'Geography Hierarchy'
			geoLevelId			= 'Geography Level'
			referenceDate		= 'Reference Date'
			geoLevelDisplay		= 'Geography Level Display'
			optionalWithWCFor	= 'Optional with W/C for'
			;

		if (_n_=1) then
		do;
			%if (&l_requireDs = 1) %then 
			%do; 
			dcl hash req_h (dataset:'WORK.geo_required');
			req_h.defineKey('ordinal_fips');
			req_h.defineData('required');
			req_h.defineDone();
			%end;

			%if (&l_wildcardDs = 1) %then 
			%do; 
			dcl hash wc_h (dataset:'WORK.geo_wildcards');
			wc_h.defineKey('ordinal_fips');
			wc_h.defineData('wildcards');
			wc_h.defineDone();
			%end;
		end;

		/* Ensure both fields are populated */
		geoLevelId = COALESCEC(geoLevelId,geoLevelDisplay);
		geoLevelDisplay = COALESCEC(geoLevelDisplay,geoLevelId);

		%if (&l_requireDs = 1) %then 
		%do; 
		_iorc_ = req_h.find();
		%end;

		%if (&l_wildcardDs = 1) %then 
		%do; 
		_iorc_ = wc_h.find();
		%end;

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
		LIBNAME apigeos CLEAR;
		FILENAME apigeosf;
		PROC DATASETS LIB=WORK NOLIST MT=ALL;
			DELETE geo_required geo_wildcards / MT=ALL;
		QUIT;
		%let l_eTime=%sysfunc(time());
		%let l_rTime=%sysfunc(putn(%sysevalf(&l_eTime - &l_sTime),time12.2));
		%PUT >>> censusapi_getDsGroups :>>> Total RunTime = &l_rTime;

%MEND censusapi_getDsGeos;