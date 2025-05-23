/**
  @file util_getdsidvalues.sas
  @brief Returns system generated _ROWID_ and unique_Ds_ID
  @details
  Returns system generated _ROWID_ and unique_Ds_ID values for the specified API Base URL.

      Usage Example:
      %GLOBAL g_rowId g_uniqueId;
      %util_getDsIdValues(p_apiBaseUrl=http://api.census.gov/data/1986/cbp 
        , p_rtrnRowIDMacVarName=g_rowId, p_rtrnUniqueIDMacVarName=g_uniqueId)

  @param [in] p_registryDsName= Registration Data Set name. Default:APILIB._API_ALL_DATA
  @param [in] p_apiBaseUrl= API Base URL for the registered data set
  @param [in] p_rtrnRowIDMacVarName= Macro variable name to hold the associated _ROWID_ value
  @param [in] p_rtrnUniqueIDMacVarName= Macro variable name to hold the associated ds_unique_id value

  @version SAS 9.4
  @author Ahmed Al-Attar

**/

%MACRO util_getDsIdValues(p_registryDsName=APILIB._API_ALL_DATA ,p_apiBaseUrl= ,p_rtrnRowIDMacVarName= ,p_rtrnUniqueIDMacVarName=);

	%LOCAL l_lastChar;
	%let l_lastChar = ;
	%if ("%SUBSTR(%SYSFUNC(REVERSE(&p_apiBaseUrl)),1,1)" NE "/") %then
		%let p_apiBaseUrl = &p_apiBaseUrl/;

	PROC SQL NOPRINT;
		SELECT 
			STRIP(ds_unique_id)
			, _ROWID_
		INTO :&p_rtrnUniqueIDMacVarName
			,:&p_rtrnRowIDMacVarName TRIMMED
		FROM &p_registryDsName
			WHERE BaseURL = "&p_apiBaseUrl";
	QUIT;
%MEND util_getDsIdValues;
