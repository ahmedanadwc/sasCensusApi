/*!
 ******************************************************
 * @author	Ahmed Al-Attar
 * @created	04/19/2022
 ******************************************************
 */

/**
******************************************************
* Parses the Variables Metadata stored in the specified 
* variables.json file into SAS Data Set and Formats,
* using PROC HTTP and JSON Library engine.
* Once the Variables data set in created, it's used to 
* dynamically create the following formats for variables
* manipulations 
* - $_xxx_vRename. : Used for renaming the variables
* - $_xxx_vCnvrt.  : Used for Type Conversion from char to num
* - $_xxx_vLbl.    : Used for Assigning variables labels 
*
*
* <br><br>Usage Example:<br>
* %censusapi_getDsVars(p_outDsName=APILIB._799_DEC_2000_vars
* , p_varFmtNamePreFix=_799_DEC_2000
* , p_varsJsonURL=http://api.census.gov/data/2000/dec/sf1/variables.json
* , p_outVarFmtLibName=APILIB)
* <br>
*
* @param p_outDsName	The output data set name. Required
* @param p_varsJsonURL	The Variables JSON URL. Required
* @param p_varFmtNamePreFix	Internal Data set Unique ID. Required 
* @param p_outVarFmtLibName Libname to store Variables Formats. 
*							Default:WORK. Required
******************************************************
*/

%MACRO censusapi_getDsVars(p_outDsName=
, p_varsJsonURL=
, p_varFmtNamePreFix=
, p_outVarFmtLibName=WORK);

	%LOCAL
		l_sTime
		l_eTime
		l_rTime
		l_rc
		l_msg
		;

	%LOCAL
		l_transCols
		l_dsid
		l_maxLen
		l_outDsName
		;

	* Record Starting Time;
	%let l_sTime = %sysfunc(time());

	/********** BEGIN -- Macro Parameter Validation **********/

	%if (%superq(p_outDsName) EQ ) %then
	%do;
		/* Missing p_outDsName value in macro call */
		%let l_rc  = 1;
		%let l_msg = ERROR: censusapi_getDsVars: p_outDsName is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_varsJsonURL) EQ ) %then
	%do;
		/* Missing p_varsJsonURL value in macro call */
		%let l_rc  = 2;
		%let l_msg = ERROR: censusapi_getDsVars: p_varsJsonURL is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_varFmtNamePreFix) EQ ) %then
	%do;
		/* Missing p_varFmtNamePreFix value in macro call */
		%let l_rc  = 3;
		%let l_msg = ERROR: censusapi_getDsVars: p_varFmtNamePreFix is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_outVarFmtLibName) EQ ) %then
	%do;
		/* Missing p_outVarFmtLibName value in macro call */
		%let l_rc  = 4;
		%let l_msg = ERROR: censusapi_getDsVars: p_outVarFmtLibName is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	/********** END -- Macro Parameter Validation **********/

	/* ------------------------- */
	/* Get WORK._api_ds_all_vars */
	/* ------------------------- */
	FILENAME apivarsf TEMP;
	PROC HTTP
	 METHOD="GET"
	 URL="&p_varsJsonURL"
	 OUT=apivarsf;

	 SYSECHO "Requesting the Variables JSON URL via Proc HTTP";
	RUN;

	LIBNAME apivars JSON FILEREF=apivarsf;

	DATA WORK._tmp_ds_vars_;

		SYSECHO "Processing the returned JSON response and generating intermediate output data set";

		LENGTH _v_ROWID_ 4;
		FORMAT _v_ROWID_ BEST8.;

		SET apivars.alldata(KEEP=P2 P3 V Value WHERE=(V=1 AND LOWCASE(P3) IN ('label','predicatetype','required')));
		BY P2 NOTSORTED;

		/* Load non-variables/predicateOnly */
		if (_N_=1) then
		do;
			dcl hash nonvar_h (dataset:'apivars.alldata(KEEP=P2 P3 Value WHERE=(P3="predicateOnly" AND Value="true"))');
			nonvar_h.defineKey('P2');
			nonvar_h.defineDone();
		end;

		/* Delete non-variables/predicateOnly records */
		if (nonvar_h.find()=0) then DELETE;

		if (first.P2) then _v_ROWID_+1;

		P3 = TRANSLATE(STRIP(P3),'_','-');

		if (STRIP(P3) = 'predicateType') then
		do;
			if (STRIP(Value) = '') then 
				Value = 'string';
		end;

		/* Handle Inaccurate metadata settings for the NAME, and other description columns, and default it to "string" */
		if (STRIP(P3) = 'predicateType') then
		do;
			if ((STRIP(P2) = 'NAME') OR (STRIP(P2) = 'STABREV') OR (INDEX(STRIP(P2),'_DESC') GT 0)) then
				Value = 'string';
		end;

		RENAME 
			P2 = Name
			p3 = Category;

		LABEL 
			_v_ROWID_ = 'Variable ROWID'
			Name      = 'Name'
			Category  = 'Category';

		DROP V;
	RUN;

	SYSECHO "Shrinking the &p_outDsName data set";
	%etl_shrinkMyData(p_inDsName=WORK._tmp_ds_vars_
	, p_outDsName=WORK._tmp_ds_vars_, p_switchLimit=500)

	/* ------------------------------ */
	/* Prep to Transpose the table    */
	/* ------------------------------ */
	PROC SORT DATA=WORK._tmp_ds_vars_;
		BY _v_ROWID_ Name;
	RUN;

	/* Transpose the data */
	%let l_outDsName = &p_outDsName;
	PROC TRANSPOSE DATA=work._tmp_ds_vars_ OUT=&l_outDsName(DROP=_NAME_ _LABEL_);
		SYSECHO "Transposing the table to generate the final &p_outDsName output data set";
		BY _v_ROWID_ Name;
		ID category;
		VAR Value;
	run;

	SYSECHO "Shrinking the &p_outDsName data set";
	%etl_shrinkMyData(p_inDsName=&l_outDsName, p_outDsName=&l_outDsName, p_switchLimit=500)

	/* Create required formats for variable 
	   - Rename: $_xxx_vRename.
	   - Type Conversion: $_xxx_vCnvrt.
	   - Label Assignment: $_xxx_vLbl.
	*/
	DATA WORK.cntrl(KEEP=FMTNAME TYPE START LABEL);
		LENGTH FMTNAME $32 TYPE $1 START $32 LABEL $256;
		FORMAT LABEL $256. FMTNAME START $32.;

		SET &l_outDsName;
		RETAIN TYPE 'C';
		START = STRIP(NAME);
		FMTNAME = "&p_varFmtNamePreFix._vLbl";
		label = STRIP(COALESCEC(LABEL,NAME));
		OUTPUT;

		/* Default predicateType value to 'string' */
		if (STRIP(predicateType) = '') then
			predicateType = 'string';

		if (LOWCASE(predicateType) NE 'string') then
		do;
			FMTNAME = "&p_varFmtNamePreFix._vRename";
			label = CATS('i',NAME);
			OUTPUT;

			FMTNAME = "&p_varFmtNamePreFix._vCnvrt";
			inFmt = ifc(LOWCASE(predicateType)='int','BEST16.','BEST16.2');
			label = CATT(NAME,' = .; IF(STRIP(i',NAME,") NE 'NULL') THEN")||' '||CATT(NAME,' = INPUT(STRIP(i',NAME,'),',inFmt,');');
			OUTPUT;
		end;
		else
		do;
			FMTNAME = "&p_varFmtNamePreFix._vCnvrt";
			label = CATS(NAME,'= STRIP(',NAME,');');
			OUTPUT;
		end;
	RUN;
	PROC SORT DATA=WORK.cntrl; BY FMTNAME; RUN;
	PROC FORMAT LIB=&p_outVarFmtLibName CNTLIN=WORK.cntrl; RUN;

	%goto finished;

	%exit:
		%PUT *** ERROR: censusapi_getDsVars  ***;
		%PUT *** l_RC must be zero (0).   ***;
		%PUT *** l_RC= &l_RC    .         ***;
		%PUT &l_MSG ;
		%PUT *** ERROR: censusapi_getDsVars  ***;

	%finished:
		/* --- Clean up --- */
		LIBNAME apivars CLEAR;
		FILENAME apivarsf;
		PROC DATASETS LIB=WORK NOLIST; 
			DELETE _tmp_ds_vars_ cntrl /MT=DATA; 
		QUIT;
		%let l_eTime=%sysfunc(time());
		%let l_rTime=%sysfunc(putn(%sysevalf(&l_eTime - &l_sTime),time12.2));
		%PUT >>> censusapi_getDsVars :>>> Total RunTime = &l_rTime;

%MEND censusapi_getDsVars;