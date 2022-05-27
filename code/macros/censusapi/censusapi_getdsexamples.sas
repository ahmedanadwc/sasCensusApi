/*!
 ******************************************************
 * @author	Ahmed Al-Attar
 * @created	04/19/2022
 ******************************************************
 */

/**
******************************************************
* Parses the Data API query examples illustrated in the 
* specified examples.html file into SAS Data Set,
* using PROC HTTP and data step processing.
*
* <br><br>Usage Example:<br>
* %censusapi_getDsExamples(p_outDsName=WORK._ds_examples
* , p_examplesHtmlURL=%str(http://api.census.gov/data/1999/nonemp/examples.html))
* <br>
*
* @param p_outDsName	The output data set name. Required
* @param p_examplesHtmlURL	The Examples HTML URL. Required
******************************************************
*/

%MACRO censusapi_getDsExamples(p_outDsName=WORK._ds_examples
, p_examplesHtmlURL=);

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
		%let l_msg = ERROR: censusapi_getDsExamples: p_outDsName is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	%if (%superq(p_examplesHtmlURL) EQ ) %then
	%do;
		/* Missing p_examplesHtmlURL value in macro call */
		%let l_rc  = 2;
		%let l_msg = ERROR: censusapi_getDsExamples: p_examplesHtmlURL is invalid. Please specify non-missing value;
		%goto exit;
	%end;

	/********** END -- Macro Parameter Validation **********/

	/* Get the Examples HTML page */
	FILENAME exmpls TEMP;
	PROC HTTP
		METHOD="GET" URL="&p_examplesHtmlURL" OUT=exmpls;

		SYSECHO "Requesting the Examples HTML URL via Proc HTTP";
	RUN;

	/* Parse out the examples HTML page  */
	DATA &p_outDsName(KEEP=in_:);

		SYSECHO "Processing the returned HTML response and generating the &p_outDsName output data set";

		INFILE exmpls length=len lrecl=32767 firstobs=90 ;
		INPUT line $varying32767. len;
		LENGTH single_line $32767;
		RETAIN single_line;

		LENGTH tbody_s $1 tbody_e $1 found found2 url $1000;

		LENGTH	in_geoHier $350
				in_geoLvl $4
				in_exampleURL $500
				in_number $3
				;

		LABEL	in_geoHier	  = 'Geography Hierarchy'
				in_geoLvl     = 'Geography Level'
				in_exampleURL = 'Example URL'
				;

		ARRAY cvars {4} $ in_: ;

		RETAIN tbody_s tbody_e pattern_id pattern_id2 pattern_id3 in_: single_line snglRowColPos;

		if (_n_=1) then
		do;
			tbody_s = 'n'; 
			tbody_e = 'n';
			data_pattern = '/<td[^>]*?>[\s\S]*?<\/td>/';
			pattern_id = prxparse(data_pattern);
			href_pattern = '/<a[^>]*?>[\s\S]*?<\/a>/';
			pattern_id2 = prxparse(href_pattern);
			span_pattern = '/<span[^>]*?>[\s\S]*?<\/span>/';
			pattern_id3 = prxparse(span_pattern);
		end;

		line = strip(line);
	 	if len>0;
		single_line = CATS(single_line,line);

		 /* Ensure we have full Record Line */
		if (STRIP(line) EQ '</tr>') then
		do;
			line = STRIP(single_line);
			single_line='';

			/* Flag the beginning of the Table's Body */
			if (INDEX(line,'<tbody>') GT 0) then
				tbody_s='y';

			/* Only Capture Table Data Rows */
			if ((INDEX(line,'<td') GT 0) AND (tbody_s='y') AND (tbody_e='n')) then
			do;
				start=1;
				stop=length(line);
				d = 1;

				/* Loop through the table columns */
				call prxnext(pattern_id,start,stop,line,position,length);
				do while (position > 0);
					found = substr(line,position,length);

					/* Check if rowspan= used in the <td> tag */
					if (INDEX(found,'rowspan') EQ 0) then
					do;
						if (snglRowColPos LE 0) then snglRowColPos = d;
						else d = MAX(d,snglRowColPos);
					end;
					/* put; put '>>> ' snglRowColPos= d=; put;*/

					/* Remove the <td[^>]*?> and </td> tags */
					found=prxchange('s/<td[^>]*?>//',-1, found);
					found = STRIP(TRANWRD(found,'</td>',''));

					/* if it contains span - Remove it */
					if prxmatch(pattern_id3, found) then 
					do;
						found=prxchange('s/<span[^>]*?>//',-1, found);
						found = STRIP(TRANWRD(found,'</span>',''));
						found = STRIP(TRANWRD(found,'&rsaquo; ',' > '));
					end;
					/*put; put '>>> ' position= length= found= d=; put;*
					
					/* if it contains anchor - extract the Text */
					if prxmatch(pattern_id2, found) then
					do;
						start2=1;
						stop2=length(found);

						call prxnext(pattern_id2,start2,stop2,found,pos2,len2);

						do while (pos2 > 0);
							found2 = substr(found,pos2,len2);
							 url=SCAN(found2,2,'"');
							 if (INDEX(url,'https://api.census.gov') EQ 0) then
							 do;
							 	/*found2 = TRANWRD(found2,SCAN(found2,2,'"'),CATS('https://api.census.gov',url));*/
							 	found2 = CATS('https://api.census.gov',url);
								found2 = TRANWRD(STRIP(found2),'&amp;','&');
							 end;

							cvars[d] = found2;
							_ex_ROWID_+1;

							/*put; put '>>> ' found2= d=;	put;*/
							OUTPUT;

							call prxnext(pattern_id2,start2,stop2,found,pos2,len2);
						end;
					end;
					else 
						cvars[d] = found;

					d+1;
					/* put; put '>>>' d=; put; */
					call prxnext(pattern_id,start,stop,line,position,length);
				end;
				*put (cvars[*]) (=/) ;

			end;
		end; /* End - Ensure we have full Record Line */
		DROP in_number;
	RUN;

	%let l_outDsName = &p_outDsName;

	SYSECHO "Shrinking the &p_outDsName data set";
	%etl_shrinkMyData(p_inDsName=&l_outDsName, p_outDsName=&l_outDsName)

	%goto finished;

	%exit:
		%PUT *** ERROR: censusapi_getDsExamples  ***;
		%PUT *** l_RC must be zero (0).   ***;
		%PUT *** l_RC= &l_RC    .         ***;
		%PUT &l_MSG ;
		%PUT *** ERROR: censusapi_getDsExamples  ***;

	%finished:
		/* --- Clean up --- */
		FILENAME exmpls;
		%let l_eTime=%sysfunc(time());
		%let l_rTime=%sysfunc(putn(%sysevalf(&l_eTime - &l_sTime),time12.2));
		%PUT >>> censusapi_getDsExamples :>>> Total RunTime = &l_rTime;
%MEND censusapi_getDsExamples;