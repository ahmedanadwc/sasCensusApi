/**
  @file etl_shrinkmydata.sas
  @brief Shrinks the input data set and saves it as the output data set.
  @details
  Shrinks the input data set by reducing the variables lengths to fit the largest value found in all the records.

      Usage Example:
      %etl_shrinkMyData(p_inDsName=SASHELP.PRDSALE, p_outDsName=WORK.TEST, p_noCompress=)

  @param [in] p_inDsName= Two level data set name to be shrinked
  @param [in] p_outDsName= The name of the shrunk output table
  @param [in] p_noCompress= List of variables to be excluded from shrinking, Or it could be
                            _character_/_numeric_ Name List
  @param [in] p_switchLimit= Number of records controlling which Method to use for calculating
                             Variables Max Length. Default:5,000,000  
  @param [in] p_moveData_yn= Y/N Flag to process the data, Default:Y.

  @version SAS 9.4
  @author Ahmed Al-Attar

**/

%macro etl_shrinkMyData(
	p_inDsName=
	, p_outDsName=
	, p_noCompress= /* [optional] variables to be omitted from the minimum-length computation process */
	, p_switchLimit=5000000
	, p_moveData_yn=Y
	)/ minoperator;

  %LOCAL  l_eTime
		l_MSG
		l_RC
		l_rTime
		l_sTime
		l_dsLib
		l_dsName
		l_outDsName
		l_noCompress
		l_special
		l_lenStmt
		l_fmtStmt
		l_lblStmt
		l_inDsNobs
		l_useSqlMax
		l_outLib
		l_outDs
	  ;

    /********** BEGIN -- Macro Parameter Validation **********/
	%if (%superq(p_inDsName) EQ ) %then
	%do;
		/* Missing p_inDsName value in macro call */
		%let l_rc  = 1;
		%let l_msg = ERROR>>> etl_shrinkMyData: p_inDsName is invalid. Please specify non-missing value;
		%goto exit;
	%end;
  %else
  %do;
	  /* Confirm Dataset Exists */
	  %if (%sysfunc(exist(&p_inDsName,DATA)) = 1) OR
	      (%sysfunc(exist(&p_inDsName,VIEW)) = 1) %then
	  %do;
      /* Data set exists */
      /* alatt001-04/07/2022: Find Total number of records in the input data set */
      %let l_inDsNobs = 0;

      %if (%sysfunc(exist(&p_inDsName,DATA)) = 1) %then
      %do;
        DATA _NULL_;
          if 0 then SET &p_inDsName NOBS=nobs;
          CALL SYMPUTX('l_inDsNobs',nobs);
        RUN;
      %end;

      %if ((%sysfunc(exist(&p_inDsName,VIEW)) = 1) OR (&l_inDsNobs LE 0)) %then
      %do;
        /* When dealing with Views or RDBMS Tables, need to run a query to get record count */
        PROC SQL NOPRINT;
          SELECT COUNT(*)
          INTO :l_inDsNobs TRIMMED
          FROM &p_inDsName;
        QUIT;
	      %end;

	      /*%PUT &=l_inDsNobs;*/
	      %if (%index(&p_inDsName,%str(.)) EQ 0) %then
	      %do;
	        %let l_dsLib=WORK;
	        %let l_dsName=%upcase(&p_inDsName);
	      %end;
	      %else
	      %do;
	        /* Capture Library and Data set Names from &p_inDsName */
	        %let l_dsLib=%upcase(%scan(&p_inDsName,1,%str(.)));
	        %let l_dsName=%upcase(%scan(&p_inDsName,2,%str(.)));
	      %end;

	      /* Assign a default output Data set name if it was not specified */
	      %let l_outDsName = %superq(p_outDsName);
	      %if (%superq(p_outDsName) EQ ) %then
	      %do;
	        %let l_outDsName = WORK._shrnk;
	        %let l_outLib = WORK;
	        %let l_outDs  = _SHRNK;
	      %end;
		  %else
		  %do;
	      %if (%index(&p_outDsName,%str(.)) EQ 0) %then
	      %do;
	        %let l_outLib = WORK;
	        %let l_outDs  = %upcase(&p_outDsName);
	      %end;
	      %else
	      %do;
	        /* Capture Library and Data set Names from &p_outDsName */
	        %let l_outLib = %upcase(%scan(&p_outDsName,1,%str(.)));
	        %let l_outDs  = %upcase(%scan(&p_outDsName,2,%str(.)));
	      %end;
		  %end;
	  %end;
	  %else
	  %do;
	    /* Master Data set does not exist */
	    %let l_rc  = 2;
	    %let l_msg = ERROR>>> etl_shrinkMyData: p_inDsName is invalid. %upcase(&p_inDsName) does not exist;
	    %goto exit;
	  %end;
  %end;

  /********** END -- Macro Parameter Validation **********/
  /* alatt001-04/28/2017: Added logic to support Special SAS Variable Name List */
  %if (%superq(p_noCompress) EQ ) %then %let l_noCompress =;
  %else %let l_noCompress =%lowcase(&p_noCompress);

  %let l_sTime=%sysfunc(time());

  /* alatt001-04/07/2022: Switch the method/query variables Max Legnth
  *                       values are computed, based on size of the data
  *                       (>= 5000000 records[Default])
  */
  %let l_useSqlMax = 1; /* Set default */

  %if (&l_inDsNobs GE &p_switchLimit) %then
    %let l_useSqlMax = 0;

  /* alatt001-04/07/2022: Declare inner macros to generate required SAS
  *                       code statements used in the Max Length query
  *                       and data step.
  */

  /* ---------------------------------------------------------- */
  /* Declare an internal macros for analyzing numeric variables */
  /* ---------------------------------------------------------- */
  %macro inner_maxNumLen(variable);
    MAX(
    CASE 
      WHEN MISSING(&variable) = 1 then 3
      ELSE
        CASE
          WHEN &variable NE TRUNC(&variable,7) then 8
          WHEN &variable NE TRUNC(&variable,6) then 7
          WHEN &variable NE TRUNC(&variable,5) then 6
          WHEN &variable NE TRUNC(&variable,4) then 5
          WHEN &variable NE TRUNC(&variable,3) then 4
          ELSE 3
        END
    END)
  %mend inner_maxNumLen;

  %macro inner_numLen(variable);
    ifn(MISSING(&variable),3,
      ifn(&variable NE TRUNC(&variable,7),8,
        ifn(&variable NE TRUNC(&variable,6),7,
          ifn(&variable NE TRUNC(&variable,5),6,
            ifn(&variable NE TRUNC(&variable,4),5,
              ifn(&variable NE TRUNC(&variable,3),4,3))))));
  %mend inner_numLen;

  /* ------------------------------------------------------------ */
  /* Declare an internal macros for analyzing character variables */
  /* ------------------------------------------------------------ */
  %macro inner_maxCharLen(variable);
    MAX(LENGTH(&variable))
  %mend inner_maxCharLen;

  %macro inner_charLen(variable);
    LENGTH(&variable);
  %mend inner_charLen;

  /* -------------------------------------------------------------------------- */
  /* Create dataset of variable names whose lengths are to be minimized         */
  /* exclude from the computation all names in &p_noCompress                    */
  /* -------------------------------------------------------------------------- */
  /* alatt001-04/28/2017: Added logic to support Special SAS Variable Name List */
  %if (%superq(l_noCompress) NE ) %then
  %do;
    %if(&l_noCompress IN (_character_ _numeric_)) %then
    %do;
      %let l_special = %substr(&l_noCompress,2,3);
      PROC SQL NOPRINT;
        SELECT  STRIP(name)
        INTO    :l_noCompress separated by ' '
        FROM    DICTIONARY.COLUMNS
        WHERE   libname = upcase("&l_dslib")
        AND     memname = upcase("&l_dsName")
        AND     memtype IN ('DATA','VIEW')
        AND     type LIKE "&l_special%";
      QUIT;
    %end;

    /* alatt001-04/04/2022:Modified the code logic to preserve the label attribute */
    /* alatt001-12/14/2020:Modified the code logic to preserve the attributes of the excluded column(s) */
    PROC CONTENTS
      DATA=&p_inDsName(KEEP=&l_noCompress)
      OUT=_cntnts2_(KEEP=name type varnum length label format formatl formatd)
      VARNUM NOPRINT MEMTYPE=data;
    RUN;

    PROC SQL NOPRINT;
      SELECT  
         CATX(' ',NAME,ifc(type=2,'$',''),LENGTH)
        ,CATX(' ',NAME,CATS(FORMAT,CATX('.',FORMATL,FORMATD)))
        ,CATS(NAME,"='",LABEL,"'")
      INTO    
         :l_lenStmt separated by ' '
        ,:l_fmtStmt separated by ' '
        ,:l_lblStmt separated by ' '
      FROM    WORK._CNTNTS2_
      ORDER BY varnum
      ;
    QUIT;

  %end; /* (%superq(l_noCompress) NE ) */

  PROC CONTENTS
	  DATA=&p_inDsName(DROP=&l_noCompress)
	  OUT=_cntnts_(KEEP=name type varnum length label format formatl formatd)
	  VARNUM NOPRINT MEMTYPE=data;
  RUN;

  /* Sort the data by the variables position */
  PROC SORT DATA=_cntnts_;
    BY varnum;
  RUN;

  /* Assign a temporary file to hold the auto generated SAS code */
  FILENAME tmpFile TEMP;

  /* ------------------------------------------------------------------------ */
  /* Generate a sorted list of all variables to be used in a RETAIN Statement */
  /* in order to preserve original columns/variables order                    */
  /* ------------------------------------------------------------------------ */
  PROC SQL NOPRINT;
    CREATE TABLE WORK._retain_ AS
    SELECT  varnum, STRIP(name) AS name
    FROM    dictionary.columns
    WHERE   libname = upcase("&l_dslib")
    AND     memname = upcase("&l_dsName")
    AND     memtype IN ('DATA','VIEW')
    ORDER BY varnum;
  QUIT;

  /* alatt001-04/04/2022:Modified the code logic to preserve the label attribute */
  /* ----------------------------------------------------------- */
  /* Start generating the required SAS code Statements and Steps */
  /* ----------------------------------------------------------- */
  DATA _NULL_;

    SET work._cntnts_ end=last nobs=nobs;
    BY  varnum;

    /* alatt001-04/07/2022: Use Hash Objects and Hash Iterators to store and
    * retrieve variable attributes instead of using long string/character variables.
    */
    LENGTH  str $200 newLenMacVar $32 spr $1;
    LENGTH  lenStr $50 frmtStr $70 lblStr $300 intoStr $35 num_name $40;

    FILE tmpFile LRECL=600;

    CALL SYMPUTX('l_totObs',nobs);

    if (nobs = 0) then STOP;

    spr = ',';

    if (_n_=1) then
    do;
      spr = '';

      /* alatt001-04/07/2022: Use Hash Objects and Hash Iterators to store and
      * retrieve variable attributes instead of using long string/character variables.
      */
      declare hash retainH (dataset:'WORK._retain_', ordered:'a');
      declare hiter retainIter('retainH');
      rc = retainH.defineKey('varnum','name');
      rc = retainH.defineDone();

      declare hash lenH (ordered:'a');
      declare hiter lenIter('lenH');
      rc = lenH.defineKey('varnum','lenStr');
      rc = lenH.defineDone();

      declare hash frmtH (ordered:'a');
      declare hiter frmtIter('frmtH');
      rc = frmtH.defineKey('varnum','frmtStr');
      rc = frmtH.defineDone();

      declare hash lblH (ordered:'a');
      declare hiter lblIter('lblH');
      rc = lblH.defineKey('varnum','lblStr');
      rc = lblH.defineDone();

      declare hash intoH (ordered:'a');
      declare hiter intoIter('intoH');
      rc = intoH.defineKey('varnum','intoStr');
      rc = intoH.defineDone();

      /* alatt001-04/07/2022: Switch the method/query variables Max Legnth
      *                       values are computed, baseed on size of the data
      *                       (>= 5000000 records)
      */
      %if(&l_useSqlMax = 1) %then
      %do;
        PUT 'PROC SQL NOPRINT;';
        PUT +3 'SELECT ';
      %end;
      %else
      %do;
        PUT 'DATA lengths_view (KEEP=l_v:)/VIEW=lengths_view; ';
        PUT +3 "SET &p_inDsName ;";
      %end;

      PUT;
    end; /* End - (_n_=1) */

    newLenMacVar = CATS('l_V',varnum);

    /* Define the Label clause and store it in its Hash Object */
    lblStr = CATS(NAME,'=',PUT(COALESCEC(LABEL,NAME),$quote.));
    rc = lblh.add();

    /* Define the INTO clause and store it in its Hash Object */
    intoStr = CATT(spr,':',newLenMacVar,' TRIMMED');
    rc = intoh.add();

    if (type = 2) then
    do;
      %if(&l_useSqlMax = 1) %then
      %do;
        str = CATS(spr,'%inner_maxCharLen(',name,')');
      %end;
      %else
      %do;
        str = CATT('l_V',varnum,' = %inner_charLen(',name,')');
      %end;

      PUT +3 str;

      /* Define the Length clause and store it in its Hash Object */
      lenStr = CATT(NAME,' $&',newLenMacVar);
      rc = lenh.add();

      /* Define the Format clause and store it in its Hash Object */
      frmtStr = CATX(' ',STRIP(NAME),COALESCEC(STRIP(FORMAT),'$'));
      if ((STRIP(FORMAT) NE "") AND (formatl EQ 0)) then
      do;
        frmtStr = CATT(frmtStr,'.');
      end;
      /* alatt001-10/15/2020:Modified the code logic to preserve exiting variable format (formatl.formatd) */
      else if ((STRIP(FORMAT) NE "") AND (formatl GT 0)) then
      do;
        frmtStr = CATT(frmtStr,CATX('.',formatl,formatd));
      end;
      else
      do;
        frmtStr = CATT(frmtStr,CATX('.','&'||STRIP(newLenMacVar)||'.',formatd));
      end;
      rc = frmth.add();
    end; /* End - (type = 2) */
    else /* (type = 1) */
    do;
      %if(&l_useSqlMax = 1) %then
      %do;
        str = CATS(spr,'%inner_maxNumLen(',name,')');
      %end;
      %else
      %do;
        str = CATT('l_V',varnum,' = %inner_numLen(',name,')');
      %end;

      PUT +3 str;

      /* Define the Length clause and store it in its Hash Object */
      lenStr = CATT(NAME,' &',newLenMacVar);
      rc = lenh.add();

      /* Define the Format clause and store it in its Hash Object */
      frmtStr = CATX(' ',STRIP(NAME),COALESCEC(STRIP(FORMAT),'BEST'));
      if ((STRIP(FORMAT) NE "") AND (formatl EQ 0)) then
      do;
        frmtStr = CATT(frmtStr,'.');
      end;
      /* alatt001-10/15/2020:Modified the code logic to preserve exiting variable format (formatl.formatd) */
      else if ((STRIP(FORMAT) NE "") AND (formatl GT 0)) then
      do;
        frmtStr = CATT(frmtStr,CATX('.',formatl,formatd));
      end;
      else
      do;
        frmtStr = CATT(frmtStr,CATX('.','&'||STRIP(newLenMacVar)||'.',formatd));
      end;
      rc = frmth.add();
    end; /* End - (type = 1) */

    if (last) then
    do;
      PUT;
      CALL MISSING(lenStr,frmtStr,lblStr,intoStr);

      %if(&l_useSqlMax = 1) %then
      %do;
        PUT +3 "INTO ";

        /* Retrieve and Compose the INTO Variables */
        rc = intoIter.first();
        do while (rc = 0);
            PUT +6 intoStr;
            rc = intoIter.next();
        end;
        PUT;
        PUT +3 "FROM    &p_inDsName ;";
        PUT 'QUIT;';
      %end; /* End - (&l_useSqlMax = 1) */
      %else /* (&l_useSqlMax = 0) */
      %do;
        PUT 'RUN; ';
        PUT;
        PUT 'PROC SUMMARY DATA=lengths_view NWAY; ';
        PUT +3 'VAR l_v: ; ';
        PUT +3 'OUTPUT OUT=max_lengths(DROP=_:) MAX= ; ';
        PUT 'RUN; ';
        PUT;
        PUT 'DATA _NULL_; ';
        PUT +3 "SET max_lengths; ";
        PUT +3 "ARRAY lvs {*} 8 l_v:; ";
        PUT +3 "DO v=1 to DIM(lvs);";
        PUT +6 "CALL SYMPUTX(CATS('l_v',v), lvs[v]);";
        PUT +3 "END; ";
        PUT 'RUN; ';
        PUT;
        PUT 'PROC DATASETS LIB=WORK NOLIST MT=all; DELETE lengths_view max_lengths / mt=all; QUIT; ';
      %end; /* End - (&l_useSqlMax = 0) */

      PUT;
      PUT '%MACRO innerTempConv; ';
      PUT +3 "DATA &l_outDsName ;";
      PUT;

      /* Retrieve and Compose the RETAIN Statement */
      PUT +6 "RETAIN ";
      rc = retainIter.first();
      do while (rc = 0);
        PUT +6 name;
        rc = retainIter.next();
      end;
      PUT +6 ';';
      PUT;

      /* alatt001-04/04/2022:Modified the code logic to preserve the label attribute */
      /* alatt001-12/14/2020:Modified the code logic to preserve the attributes of the excluded column(s) */
      %if (%superq(l_noCompress) NE ) %then
      %do;
        PUT +6 " LENGTH &l_lenStmt ;";
        PUT +6 " FORMAT &l_fmtStmt ;";
        PUT +6 " LABEL  &l_lblStmt ;";
        PUT;
      %end;

      /* Retrieve and Compose the LENGTH Statement */
      PUT +6 "LENGTH ";
      rc = lenIter.first();
      do while (rc = 0);
        PUT +6 lenStr;
        rc = lenIter.next();
      end;
      PUT +6 ';';
      PUT;

      /* Retrieve and Compose the FORMAT Statement */
      PUT +6 "FORMAT ";
      rc = frmtIter.first();
      do while (rc = 0);
        PUT +6 frmtStr;
        rc = frmtIter.next();
      end;
      PUT +6 ';';
      PUT;

      /* Retrieve and Compose the LABEL Statement */
      PUT +6 "LABEL ";
      rc = lblIter.first();
      do while (rc = 0);
        PUT +6 lblStr;
        rc = lblIter.next();
      end;
      PUT +6 ';';
      PUT;

      %if (%upcase(&p_inDsName) NE %upcase(&p_outDsName)) %then
      %do;
        PUT +6 "STOP;";
      %end;
      %else %if (%upcase(&p_moveData_yn) EQ Y) %then
      %do;
        PUT +6 "SET &p_inDsName ;";
      %end;

      PUT;
      PUT +3 'RUN;';
      PUT;

      %if ( (%upcase(&p_inDsName) NE %upcase(&p_outDsName))
	       AND (%upcase(&p_moveData_yn) EQ Y) ) %then
      %do;
        PUT +3 "PROC APPEND BASE=&l_outDsName DATA=&p_inDsName FORCE NOWARN;";
        PUT +3 'RUN;';
      %end;
	  %else %if (%upcase(&p_moveData_yn) NE Y) %then
	  %do;
        PUT;
        PUT +3 "DATA &l_outDsName ;";
        PUT;
        PUT +6 "SET sashelp.vcolumn(where=(libname='&l_outLib' and memname='&l_outDs') ";
        PUT +6 'KEEP=libname memname varnum name type length label format informat); ';
        PUT +6 "if (type = 'char') then type = '$'; ";
        PUT +6 "else type = ''; ";
        PUT +6 "name = translate(STRIP(name),'_',' '); ";
        PUT;
        PUT +3 'RUN;';
        PUT;
	  %end;

      PUT '%MEND innerTempConv; ';
      PUT '%innerTempConv; ';
    end; /* End - (last) */
  RUN;

  %include tmpFile / lrecl=600;
  %goto finished;

  %exit:
    %PUT *** ERROR: etl_shrinkMyData  ***;
    %PUT *** l_RC must be zero (0).   ***;
    %PUT *** l_RC= &l_RC    .         ***;
    %PUT *** &l_MSG ***;
    %PUT *** ERROR: etl_shrinkMyData  ***;

  %finished:
    /* Clean-up */
    PROC DATASETS LIB=WORK NOLIST;
        DELETE _cntnts_ _retain_ / MT=DATA;
    QUIT;
    %let l_eTime=%sysfunc(time());
    %let l_rTime=%sysfunc(putn(%sysevalf(&l_eTime - &l_sTime),time12.2));
    %PUT >>> etl_shrinkMyData :>>> Total RunTime = &l_rTime;
    ;
%mend etl_shrinkMyData;