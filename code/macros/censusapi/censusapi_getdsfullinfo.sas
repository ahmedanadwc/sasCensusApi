/**
  @file censusapi_getdsfullinfo.sas
  @brief Extracts required JSON & HTML URLs associated with the specified Data set RowID 
  from the collected tables Metadata data set.
  @details
  Extracts required JSON & HTML URLs associated with the specified Data set RowID 
  from the collected tables Metadata data set.
  Once these URLs are extracted, it calls relevent macros to parse out the data and generate
  - Variables Metadata data set
  - Geographies data set
  - Examples data set
  Then an Excel Workbook is generated containing listing of these newly created SAS data sets.

      Usage Example:
      %censusapi_getDsFullInfo(p_apiListingLibName=APILIB, p_apiListingDsName=_API_ALL_DATA, p_dsRowId=3)

  @param [in] p_apiListingLibName= The Libname holding the	Datasets Metadata table. Default:APILIB. Required
  @param [in] p_apiListingDsName= The collected tables Metadata data set name. Default:_api_all_data. Required
  @param [in] p_dsRowId= The _ROWID_ value of the desired data set. Required
  @param [in] p_reportOutputPath= The output pathname. Default:&g_outputRoot. Required

  <h4> SAS Macros </h4>
  @li censusapi_getdsvars.sas
  @li censusapi_getdsgroups.sas
  @li censusapi_getdsgeos.sas
  @li censusapi_getdsexamples.sas

  <h4> Data Inputs </h4>
  @li APILIB._API_ALL_DATA

  <h4> Data Outputs </h4>
  @li APILIB.[ds_unique_id]_vars;
  @li APILIB.[ds_unique_id]_grps;
  @li APILIB.[ds_unique_id]_geos;
  @li APILIB.[ds_unique_id]_exmpls

  @version SAS 9.4
  @author Ahmed Al-Attar

**/

%MACRO censusapi_getDsFullInfo(p_apiListingLibName=APILIB
, p_apiListingDsName=_API_ALL_DATA
, p_dsRowId=
, p_reportOutputPath=&g_outputRoot);

	%LOCAL
		l_sTime
		l_eTime
		l_rTime
		l_rc
		l_msg
		;

	%LOCAL
		l_title
		l_outDsPrefix
		l_outDsReportName
		l_geoslink
		l_varslink
		l_grpslink
		l_exmplsLink
		l_outGrpsDsName
		l_outVarsDsName
		l_outExmplsDsName
		;

	* Record Starting Time;
	%let l_sTime = %sysfunc(time());

	/********** BEGIN -- Macro Parameter Validation **********/

	%if (%superq(p_apiListingLibName) EQ ) %then
	%do;
		/* Missing p_apiListingLibName value in macro call */
		%let l_rc  = 1;
		%let l_msg = ERROR: censusapi_getDsFullInfo: p_apiListingLibName is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_apiListingDsName) EQ ) %then
	%do;
		/* Missing p_apiListingDsName value in macro call */
		%let l_rc  = 2;
		%let l_msg = ERROR: censusapi_getDsFullInfo: p_apiListingDsName is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_dsRowId) EQ ) %then
	%do;
		/* Missing p_dsRowId value in macro call */
		%let l_rc  = 3;
		%let l_msg = ERROR: censusapi_getDsFullInfo: p_dsRowId is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_reportOutputPath) EQ ) %then
	%do;
		/* Missing p_reportOutputPath value in macro call */
		%let l_rc  = 4;
		%let l_msg = ERROR: censusapi_getDsFullInfo: p_reportOutputPath is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	/********** END -- Macro Parameter Validation **********/

	/* Create a temporary vintage. format */
	PROC FORMAT lib=work;
		value vintage 
		 	. = 'NA'
		 	other = [best.];
	RUN;

	/* Get all required information related to the desired table from the Census Data API */
	PROC SQL NOPRINT;
		SELECT
			 STRIP(title)
			,STRIP(ds_unique_id)
			,STRIP(CATX('_',_ROWID_,c_dataset1,c_dataset2,PUT(c_vintage,vintage.)))
			,STRIP(c_geographyLink)
			,STRIP(c_variablesLink)
			,STRIP(c_groupsLink)
			,STRIP(c_examplesLink_html)
		INTO
			 :l_title
			,:l_outDsPrefix TRIMMED
			,:l_outDsReportName TRIMMED
			,:l_geoslink
			,:l_varslink
			,:l_grpslink
			,:l_exmplsLink

		FROM &p_apiListingLibName..&p_apiListingDsName
		WHERE _ROWID_ = &p_dsRowId;
	QUIT;

	%let l_outVarsDsName   = &p_apiListingLibName..&l_outDsPrefix._vars;
	%let l_outGrpsDsName   = &p_apiListingLibName..&l_outDsPrefix._grps;
	%let l_outGoesDsName   = &p_apiListingLibName..&l_outDsPrefix._geos;
	%let l_outExmplsDsName = &p_apiListingLibName..&l_outDsPrefix._exmpls;

	SYSECHO "Calling the censusapi_getDsFullInfo macro to get the Variables info of the specified data set";
	%censusapi_getDsVars(p_outDsName=&l_outVarsDsName
	, p_varsJsonURL=&l_varslink
	, p_varFmtNamePreFix=&l_outDsPrefix
	, p_outVarFmtLibName=&p_apiListingLibName)

	SYSECHO "Calling the censusapi_getDsGroups macro to get the Groups info of the specified data set";
	%censusapi_getDsGroups(p_outDsName=&l_outGrpsDsName
	, p_groupsJsonURL=&l_grpslink)

	SYSECHO "Calling the censusapi_getDsGeos macro to get the Goegraphies info of the specified data set";
	%censusapi_getDsGeos(p_outDsName=&l_outGoesDsName
	, p_geoJsonURL=&l_geoslink)

	SYSECHO "Calling the censusapi_getDsExamples macro to get the Examples info of the specified data set";
	%censusapi_getDsExamples(p_outDsName=&l_outExmplsDsName
	, p_examplesHtmlURL=&l_exmplsLink)

	/* Display the Result in the Filter Enabled HTML Table */
	TITLE "&l_title"; 
	TITLE3 "Datset information extracted from the Census Data API as of %SYSFUNC(datetime(),datetime20.) ";

	SYSECHO "Generating the Excel Workbook for &l_title output data set";

	ODS EXCEL file="&g_outputRoot.&g_slash._&l_outDsReportName._info.xlsx"
	    options(embedded_titles = "on"
				embedded_footnotes="on"
				frozen_headers = "on"
				sheet_interval="proc"
				start_at="2,2"
				flow="tables")
		style=styles.SNOW ;

	ODS EXCEL options(sheet_name="Variables");
	PROC PRINT DATA=&l_outVarsDsName NOOBS LABEL;
		VAR	Name label predicateType /*required*/;
		TITLE "Registered Variables as of %SYSFUNC(datetime(),datetime20.)  ";
	RUN;
	ODS EXCEL options(sheet_name="Groups");
	PROC PRINT DATA=&l_outGrpsDsName NOOBS LABEL;
		VAR	name description variables;
		TITLE "Registered Groups as of %SYSFUNC(datetime(),datetime20.) ";
	RUN;
	ODS EXCEL options(sheet_name="Geographies");
	PROC PRINT DATA=&l_outGoesDsName NOOBS LABEL;
		VAR	name geoLevelId geoLevelDisplay required wildcards optionalWithWCFor referenceDate;
		TITLE "Registered Geographies as of %SYSFUNC(datetime(),datetime20.) ";
	RUN;
	ODS EXCEL options(sheet_name="Examples");
	PROC PRINT DATA=&l_outExmplsDsName NOOBS LABEL;
		TITLE "Registered Examples as of %SYSFUNC(datetime(),datetime20.) ";
	RUN;
	TITLE;

	ODS EXCEL CLOSE;
	TITLE; FOOTNOTE;

	%goto finished;

	%exit:
		%PUT *** ERROR: censusapi_getDsFullInfo  ***;
		%PUT *** l_RC must be zero (0).   ***;
		%PUT *** l_RC= &l_RC    .         ***;
		%PUT *** &l_MSG ***;
		%PUT *** ERROR: censusapi_getDsFullInfo  ***;

	%finished:
		%let l_eTime=%sysfunc(time());
		%let l_rTime=%sysfunc(putn(%sysevalf(&l_eTime - &l_sTime),time12.2));
		%PUT >>> censusapi_getDsFullInfo :>>> Total RunTime = &l_rTime;
		;

%MEND censusapi_getDsFullInfo;