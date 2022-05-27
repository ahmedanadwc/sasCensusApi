/*!
 ******************************************************
 * @author	Ahmed Al-Attar
 * @created	04/21/2022
 ******************************************************
 */

/**
******************************************************
* Extracts requested information from the Census Data
* API, using HTTPS requests and parsing the returned
* JSON response into SAS Data Set.
*
* Note: This macro assumes variables metadata for the specified
*       data set has been collected, and its related SAS Formats
*		have been created alreay! 
*
* <br><br>Usage Example:<br>
* %censusapi_getDataApiQueryRspns(
* p_queryURL=%NRSTR(https://api.census.gov/data/2000/dec/sf1?
*get=P010014,P010015,P010010,P010011,P010012,P010013,P010003,P010004
*,P010005,P010006,P010001,P010002,P010007,P010008,P010009
*,NAME&for=zip%20code%20tabulation%20area%20(3%20digit)%20(or%20part):*
*&in=state:09,23,25,33,44,50,34,36,42,17)
, p_varFmtNamePreFix=_799_dec_2000
, p_outDsName=WORK._response_)
*
* <br>
* @param p_queryURL			The Data API Full query URL. Required
* @param p_varFmtNamePreFix	Internal Data set Unique ID. Required 
* @param p_outDsName		The output data set name. Required
******************************************************
*/

%MACRO censusapi_getDataApiQueryRspns(p_queryURL=
, p_varFmtNamePreFix=
, p_outDsName=);

	%LOCAL	
		l_sTime
		l_eTime
		l_rTime
		;

	%LOCAL
		l_httpErrorFlag
		l_renameVars
		l_outKeepVars
		l_vCount
		l_v
		l_var
		l_lbl
		l_newVar
		;

	* Record Starting Time;
	%let l_sTime = %sysfunc(time());

	/********** BEGIN -- Macro Parameter Validation **********/

	%if (%superq(p_queryURL) EQ ) %then
	%do;
		/* Missing p_queryURL value in macro call */
		%let l_rc  = 1;
		%let l_msg = ERROR: censusapi_getDataApiQueryRspns: p_queryURL is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_varFmtNamePreFix) EQ ) %then
	%do;
		/* Missing p_varFmtNamePreFix value in macro call */
		%let l_rc  = 2;
		%let l_msg = ERROR: censusapi_getDataApiQueryRspns: p_varFmtNamePreFix is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_outDsName) EQ ) %then
	%do;
		/* Missing p_outDsName value in macro call */
		%let l_rc  = 3;
		%let l_msg = ERROR: censusapi_getDataApiQueryRspns: p_outDsName is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	/********** END -- Macro Parameter Validation **********/

	/* --------------------------------------------------------------
	* Define a simple macro program that tests the value 
	* set in the SYS_PROCHTTP_STATUS_CODE macro variable. 
	* The program specifies to print an error message 
	* when the result code does not match a specified 
	* value for the SYS_PROCHTTP_STATUS_CODE macro variable. 
	* The macro program also prints the actual values returned 
	* by the SYS_PROCHTTP_STATUS_CODE and SYS_PROCHTTP_STATUS_PHRASE 
	* macro variables in any error messages. 
	 ---------------------------------------------------------------- */
	%MACRO inner_checkProcHttpReturn(p_inCode,p_rtrnErrorFlag);
		%if %symexist(SYS_PROCHTTP_STATUS_CODE) ne 1 %then 
		%do;
			%put ERROR: Expected &p_inCode., but a response was not received from the HTTP Procedure;
			%let &p_rtrnErrorFlag = 1;
		%end;
		%else 
		%do;
			%if (&SYS_PROCHTTP_STATUS_CODE. NE &p_inCode.) %then 
			%do;
				%put ERROR: Expected &p_inCode., but received &SYS_PROCHTTP_STATUS_CODE. &SYS_PROCHTTP_STATUS_PHRASE.;
				%let &p_rtrnErrorFlag = 1;
			%end;
		%end;
	%MEND inner_checkProcHttpReturn;

	%let l_httpErrorFlag = 0; *<-- Default to false;
	%let l_renameVars =;
	%let l_outKeepVars =;

	/* Run the API Query */
	FILENAME qryvalsf TEMP;
	PROC HTTP
		METHOD="GET"
		URL="&p_queryURL"
		OUT=qryvalsf;
	RUN;

	%inner_checkProcHttpReturn(200,l_httpErrorFlag);

	/* Using the JSON Library engine to process the response */
	%if (&l_httpErrorFlag NE 0) %then
	%do;
		%let l_rc  = 1;
		%let l_msg = ERROR: censusapi_getDataApiQueryRspns: Submitted HTTPS query request did not generate valid JSON response.;
		%goto exit;
	%end;

	LIBNAME qryvals JSON FILEREF=qryvalsf;

	/* -------------------------------------------
	 * 1. Dynamically Extract column names from 
	 *    the First Record in the JSON Response 
	 * 2. Populate required data step statements 
	 *    macros variables to control the structure
	 *    of the output data set. 
	 --------------------------------------------- */
	DATA _NULL_;
		/* Only read the first record */
		SET qryvals.root(OBS=1);

		ARRAY vars {*} $ _character_;
		LENGTH v_name varFmt $32 v_value $200;
		varFmt = COMPRESS("$&p_varFmtNamePreFix._vRename");

		do v=1 to dim(vars);
			v_name=vname(vars(v));
			v_value=UPCASE(vvalue(vars(v)));
			mod=0;

			/* Checks the validity of a character string for use as a SAS variable name */
			if (NVALID(v_value,'v7') = 0) then
			do;
				mod=1;
				v_value = SUBSTR(translate(v_value,'_','(','_',' '),1,32);
				v_value = PUTC(STRIP(v_value),STRIP(varFmt));
			end;
			CALL SYMPUT('l_outKeepVars',CATX(' ',symget('l_outKeepVars'),STRIP(v_value)));

			/* Check for Special renaming due to required Type Conversion */
			if (mod=0) then
				v_value = PUTC(STRIP(v_value),STRIP(varFmt));

			CALL SYMPUT('l_renameVars',CATX(' ',symget('l_renameVars'),CATX('=',STRIP(v_name),STRIP(v_value))));
		end;

		CALL SYMPUTX('l_vCount',dim(vars));
	RUN;

	/* Debugging Statements */
	/*
	%put &=l_renameVars;
	%put &=l_outKeepVars;
	%put &=l_vCount;
	*/

	/* -------------------------------------------
	 * 1. Start processing the records from the 
	 *    Second Record in the JSON Response 
	 * 2. Utilize the populated macros to generate
	 *    the required output data set
	 --------------------------------------------- */
	DATA &p_outDsName(KEEP=&l_outKeepVars);
		LENGTH varFmt varFmt2 $32;
		varFmt  = COMPRESS("$&p_varFmtNamePreFix._vCnvrt");
		varFmt2 = COMPRESS("$&p_varFmtNamePreFix._vLbl");

		SET qryvals.root(FIRSTOBS=2
				RENAME=(&l_renameVars));

		/* Perform all required Type Conversions, if any */
		%do l_v=1 %to &l_vCount;
			%let l_var=%SCAN(%SUPERQ(l_outKeepVars),&l_v,%str( ));
			%let l_var=%UPCASE(&l_var);
			%let l_newVar=%SYSFUNC(PUTC(&l_var,$&p_varFmtNamePreFix._vCnvrt.));

			 /*%put >>> &=l_var &=l_newVar;*/

			%if (%SUPERQ(l_var) NE %SUPERQ(l_newVar)) %then
			%do;
				%str(&l_newVar)
			%end;
		%end;

		/* Assign Variable Labels */
		LABEL
		%do l_v=1 %to &l_vCount;
			%let l_var=%SCAN(%SUPERQ(l_outKeepVars),&l_v,%str( ));
			%let l_lbl=%QSYSFUNC(PUTC(&l_var,$&p_varFmtNamePreFix._vLbl.));
			%let l_lbl=%QSYSFUNC(STRIP(&l_lbl));
			%STR(&l_var = %"&l_lbl%")
		%end;
		;
	RUN;

	%goto finished;

	%exit:
		%PUT *** ERROR: censusapi_getDataApiQueryRspns  ***;
		%PUT *** l_RC must be zero (0).   ***;
		%PUT *** l_RC= &l_RC    .         ***;
		%PUT *** &l_MSG ***;
		%PUT *** ERROR: censusapi_getDataApiQueryRspns  ***;

	%finished:
		/* Clean-up */
		LIBNAME qryvals CLEAR;
		FILENAME qryvalsf;
		PROC DATASETS LIB=WORK NOLIST;
			DELETE rspns / MT=DATA;
		QUIT;
		%let l_eTime=%sysfunc(time());
		%let l_rTime=%sysfunc(putn(%sysevalf(&l_eTime - &l_sTime),time12.2));
		%PUT >>> censusapi_getDataApiQueryRspns :>>> Total RunTime = &l_rTime;
		;
%MEND censusapi_getDataApiQueryRspns;