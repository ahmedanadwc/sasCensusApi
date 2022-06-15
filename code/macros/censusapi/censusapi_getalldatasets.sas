/*!
 ******************************************************
 * @author	Ahmed Al-Attar
 * @created	04/14/2022
 ******************************************************
 */

/**
******************************************************
* Parses the Data sets Metadata stored in the specified 
* data.json file into SAS Data Set and generate an Excel
* workbook, using PROC HTTP and JSON Library engine.
*
* <br><br>Usage Example:<br>
* %censusapi_getalldatasets(p_outLibName=APILIB
* , p_outDsName=_api_all_data
* , p_dataJsonURL=%str(https://api.census.gov/data.json)
* , p_reportOutputPath=&g_outputRoot)
*
* <br>
*
* @param p_outLibName	The output Library name. 
*			Default:APILIB. Required
* @param p_outDsName	The output data set name.
*			Default:_api_all_data. Required
* @param p_dataJsonURL	The Data API Data JSON File.
*			Default:https://api.census.gov/data.json. Required
* @param p_reportOutputPath The output pathname.
*			Default:&g_outputRoot. Required
******************************************************
*/

%MACRO censusapi_getAllDataSets(p_outLibName=APILIB
, p_outDsName=_api_all_data
, p_dataJsonURL=%str(https://api.census.gov/data.json)
, p_reportOutputPath=&g_outputRoot);

	%LOCAL
		l_sTime
		l_eTime
		l_rTime
		l_rc
		l_msg
		;

	%LOCAL 
		l_libRef
		l_outDsName;

	* Record Starting Time;
	%let l_sTime = %sysfunc(time());

	/********** BEGIN -- Macro Parameter Validation **********/

	%if (%superq(p_outLibName) EQ ) %then
	%do;
		/* Missing p_outLibName value in macro call */
		%let l_rc  = 1;
		%let l_msg = ERROR: censusapi_getAllDataSets: p_outLibName is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_outDsName) EQ ) %then
	%do;
		/* Missing p_outDsName value in macro call */
		%let l_rc  = 2;
		%let l_msg = ERROR: censusapi_getAllDataSets: p_outDsName is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_dataJsonURL) EQ ) %then
	%do;
		/* Missing p_dataJsonURL value in macro call */
		%let l_rc  = 3;
		%let l_msg = ERROR: censusapi_getAllDataSets: p_dataJsonURL is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_reportOutputPath) EQ ) %then
	%do;
		/* Missing p_reportOutputPath value in macro call */
		%let l_rc  = 4;
		%let l_msg = ERROR: censusapi_getAllDataSets: p_reportOutputPath is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	/********** END -- Macro Parameter Validation **********/

	%let l_libref= apidslib;

	/* Access the Census Data API Registered Data/Tables via JSON */

	FILENAME apijsonf TEMP;
	PROC HTTP
		METHOD="GET"
		URL="&p_dataJsonURL"
		OUT=apijsonf;

		SYSECHO "Requesting the Data JSON URL via Proc HTTP";
	RUN;

	/* Use SAS JSON Library Engine */
	LIBNAME &l_libref JSON FILEREF=apijsonf;

	/* Create a temporary yn. format */
	PROC FORMAT lib=work;
		value yn 
			1 = 'y'
			other = 'n';

		value vintage 
		 	. = 'NA'
		 	other = [best.];
	RUN;

	/* Create consolidated datasets reporting list */

	DATA &p_outLibName..&p_outDsName(DROP=c_is: trailText RENAME=(ordinal_dataset=_ROWID_));

		SYSECHO "Processing the returned JSON response and generating the &p_outLibName..&p_outDsName output data set";

		if (0) then SET &l_libref..DATASET_C_DATASET(KEEP=ordinal_dataset c_dataset:);

		LENGTH
			c_geographyLink_html c_variablesLink_html c_examplesLink_html c_groupsLink_html	BaseURL $200;
		LENGTH ds_unique_id $25 trailText $13;

		FORMAT ordinal_dataset BEST8.;

		SET &l_libref..DATASET(DROP=ordinal_root _type accesslevel temporal identifier license
									c_documentationlink c_tagsLink c_sorts_url c_valuesLink);
		LENGTH
			Aggregate_i Cube_i Available_i Timeseries_i Microdata_i $1;

		FORMAT c_vintage vintage.;

		if (_n_=1) then
		do;
			dcl hash h (dataset:"&l_libref..DATASET_C_DATASET(KEEP=ordinal_dataset c_dataset:)");
			h.defineKey('ordinal_dataset');
			h.defineData(all:'yes');
			h.defineDone();
		end;

		/* Get Dataset Name Hierarchy columns */
		_iorc_ = h.find();

		/* Convert Numeric Indicators to Single Y/N Char */
		Aggregate_i  = PUT(c_isAggregate,yn.);
		Cube_i       = PUT(c_isCube,yn.);
		Available_i  = PUT(c_isAvailable,yn.);
		Timeseries_i = PUT(c_isTimeseries,yn.);
		Microdata_i  = PUT(c_isMicrodata,yn.);

		/* Change the values to represent HTML links */
		c_geographyLink_html = TRANWRD(STRIP(c_geographyLink),'json','html');
		c_variablesLink_html = TRANWRD(STRIP(c_variablesLink),'json','html');
		c_examplesLink_html	 = TRANWRD(STRIP(c_examplesLink),'json','html');
		c_groupsLink_html	 = TRANWRD(STRIP(c_groupsLink),'json','html');
		ds_unique_id		 = '_' || STRIP(CATX('_',ordinal_dataset,c_dataset1,PUT(c_vintage,vintage.)));
		trailText = SCAN(c_examplesLink_html,-1,'/');
 		BaseURL = STRIP(TRANWRD(c_examplesLink_html,STRIP(trailText),' '));

		LABEL
			ordinal_dataset	= 'Dataset _ROWID_'
			ds_unique_id	= 'Dataset Uniqe ID'
			c_dataset1		= 'Dataset Name - Level 1'
			c_dataset2		= 'Dataset Name - Level 2'
			c_dataset3		= 'Dataset Name - Level 3'
			c_dataset4		= 'Dataset Name - Level 4'
			title			= 'Title'
			description		= 'Description'
			c_vintage		= 'Vintage'
			c_geographyLink = 'Geography list (JSON)'
			c_variablesLink = 'Variable list (JSON)'
			c_groupsLink    = 'Group list (JSON)'
			Aggregate_i		= 'Aggregate indicator'
			Cube_i			= 'Cube indicator'
			Available_i		= 'Available indicator'
			modified		= 'Modification Date Time'
			c_examplesLink  = 'Examples list (JSON)'
			spatial			= 'Spatial level'
			Timeseries_i	= 'Timeseries indicator'
			Microdata_i		= 'Microdata indicator'
			c_geographyLink_html = 'Geography list (HTML)'
			c_variablesLink_html = 'Variable list (HTML)'
			c_examplesLink_html = 'Examples list (HTML)'
			c_groupsLink_html = 'Group list (HTML)'
			BaseURL           = 'Base URL'
			;
	RUN;

	%let l_outDsName = &p_outLibName..&p_outDsName;

	SYSECHO "Shrinking the &p_outLibName..&p_outDsName data set";

	%etl_shrinkMyData(p_inDsName=&l_outDsName, p_outDsName=&l_outDsName)

	/* Create unique index on the BaseURL column */
	PROC DATASETS LIB=&p_outLibName NOLIST; 
		MODIFY &p_outDsName;
 		INDEX CREATE BaseURL / NOMISS UNIQUE;
	QUIT;

	/* Display the Result in Excel Workbook */
	TITLE "List of all available tables by the Census Data API as of %SYSFUNC(datetime(),datetime20.) ";

	SYSECHO "Generating the interactive Excel Workbook for the &p_outLibName..&p_outDsName output data set";

	ODS EXCEL file="&g_outputRoot.&g_slash.api_all_data.xlsx"
	    options(embedded_titles = "on"
				embedded_footnotes="on"
				frozen_headers = "on"
				sheet_name="&p_outDsName"
				start_at="2,2"
				flow="tables")
		style=styles.SNOW ;
		
		PROC PRINT DATA=&p_outLibName..&p_outDsName LABEL NOOBS;
			VAR _ROWID_ ds_unique_id
				title description c_vintage Aggregate_i Cube_i Available_i 
				spatial Timeseries_i Microdata_i modified c_geographyLink_html 
				c_variablesLink_html c_groupsLink_html c_examplesLink_html;
		RUN;

	ODS EXCEL CLOSE;
	TITLE; FOOTNOTE;

	%goto finished;

	%exit:
		%PUT *** ERROR: censusapi_getAllDataSets  ***;
		%PUT *** l_RC must be zero (0).   ***;
		%PUT *** l_RC= &l_RC    .         ***;
		%PUT *** &l_MSG ***;
		%PUT *** ERROR: censusapi_getAllDataSets  ***;

	%finished:
		/* --- Clean up --- */
		LIBNAME &l_libref CLEAR;
		FILENAME apijsonf;
		%let l_eTime=%sysfunc(time());
		%let l_rTime=%sysfunc(putn(%sysevalf(&l_eTime - &l_sTime),time12.2));
		%PUT >>> censusapi_getAllDataSets :>>> Total RunTime = &l_rTime;
		;

%MEND censusapi_getAllDataSets;
