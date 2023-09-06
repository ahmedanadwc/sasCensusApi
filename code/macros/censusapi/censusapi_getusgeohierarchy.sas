/**
  @file censusapi_getusgeohierarchy.sas
  @brief Creates a standard Census US GeoHierarchy data set that contains 
  Census defined Regions and Divisions
  @details
  Creates a standard Census US GeoHierarchy data set that contains 
  Census defined Regions and Divisions based on info found in 
  https://www2.census.gov/geo/pdfs/maps-data/maps/reference/us_regdiv.pdf

      Usage Example:
      %censusapi_getUsGeoHierarchy(p_outDsName=work.test_query)

  @param [in] p_outDsName= The output data set name. Required

  @version SAS 9.4
  @author Ahmed Al-Attar

**/

%MACRO censusapi_getUsGeoHierarchy(p_outDsName=);
	/* Based on info found in https://www2.census.gov/geo/pdfs/maps-data/maps/reference/us_regdiv.pdf */

	%LOCAL
		l_sTime
		l_eTime
		l_rTime
		l_rc
		l_msg
		;

	* Record Starting Time;
	%let l_sTime = %sysfunc(time());

	/********** BEGIN -- Macro Parameter Validation **********/

	%if (%superq(p_outDsName) EQ ) %then
	%do;
		/* Missing p_outDsName value in macro call */
		%let l_rc  = 1;
		%let l_msg = ERROR: censusapi_getUsGeoHierarchy: p_outDsName is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	/********** END -- Macro Parameter Validation **********/

	PROC FORMAT LIB=WORK;
		VALUE $CENSUSREGION
		'1' = 'Northeast'
		'2' = 'Midwest'
		'3' = 'South'
		'4' = 'West';

		VALUE $CENSUSDIVISION
		'1' = 'New England'
		'2' = 'Middle Atlantic'
		'3' = 'East North Central'
		'4' = 'West North Central'
		'5' = 'South Atlantic'
		'6' = 'East South Central'
		'7' = 'West South Central'
		'8' = 'Mountain'
		'9' = 'Pacific'
		;

		VALUE CENSUSREGION
		1 = 'Northeast'
		2 = 'Midwest'
		3 = 'South'
		4 = 'West';

		VALUE CENSUSDIVISION
		1 = 'New England'
		2 = 'Middle Atlantic'
		3 = 'East North Central'
		4 = 'West North Central'
		5 = 'South Atlantic'
		6 = 'East South Central'
		7 = 'West South Central'
		8 = 'Mountain'
		9 = 'Pacific'
		;
	RUN;

	PROC SQL NOPRINT;
		CREATE TABLE &p_outDsName AS
		SELECT	
			  CASE WHEN state in (9,23,25,33,34,36,42,44,50) then '1'
			  	 WHEN state in (17,18,19,20,26,27,29,31,38,39,46,55) then '2'
				 WHEN state in (1,5,10,11,12,13,21,22,24,28,37,40,45,47,48,51,54) then '3'
				 ELSE '4'
			  END AS REGION LENGTH=1 FORMAT=$1. label='Census Region'
			, PUT(calculated REGION,$CENSUSREGION.) AS REGIONNAME LENGTH=9 FORMAT=$9. label='Census Region Name'
			, CASE WHEN state in (9,23,25,33,44,50) then '1'
			  	 WHEN state in (34,36,42) then '2'
			  	 WHEN state in (17,18,26,39,55) then '3'
			  	 WHEN state in (19,20,27,29,31,38,46) then '4'
				 WHEN state in (10,11,12,13,24,37,45,51,54) then '5'
				 WHEN state in (1,21,28,47) then '6'
				 WHEN state in (5,22,40,48) then '7'
				 WHEN state in (4,8,16,30,32,35,49,56) then '8'
				 ELSE '9'
			  END AS DIVISION LENGTH=1 FORMAT=$1. label='Census Division'
			, PUT(calculated DIVISION,$CENSUSDIVISION.) AS DIVISIONNAME LENGTH=18 FORMAT=$18. label='Census Division Name'
			, PUT(state,z2.) AS STATEFIPS length=2 format=$2. label='State Fips Code'
			, CATX(' ',statename,CATS('(',statecode,')')) AS STATENAME LENGTH=26 label='Name of State'

		FROM	MAPS.US2
		WHERE state NE 72
		ORDER BY 1,3,5;
	QUIT;

	%goto finished;

	%exit:
		%PUT *** ERROR: censusapi_getUsGeoHierarchy  ***;
		%PUT *** l_RC must be zero (0).   ***;
		%PUT *** l_RC= &l_RC    .         ***;
		%PUT &l_MSG ;
		%PUT *** ERROR: censusapi_getUsGeoHierarchy  ***;

	%finished:
		%let l_eTime=%sysfunc(time());
		%let l_rTime=%sysfunc(putn(%sysevalf(&l_eTime - &l_sTime),time12.2));
		%PUT >>> censusapi_getUsGeoHierarchy :>>> Total RunTime = &l_rTime;

%MEND censusapi_getUsGeoHierarchy;