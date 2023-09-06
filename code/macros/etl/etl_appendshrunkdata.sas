/**
  @file etl_appendshrunkdata.sas
  @brief Appends shrunk data sets
  @details 
  Appends two data sets while maintaining the longest lengths of the variables across 
  the two data sets, in order to prevent truncation.

      Usage Example:
      %etl_appendShrunkData(p_baseDsName=WORK.TEST, p_dataDsName=SASHELP.PRDSALE)

  @param [in] p_baseDsName= Data set name to be appended to
  @param [in] p_dataDsName= Data set name to be appended
  @param [in] p_tmpltDsName= Template data set name containing required column attributes
  @param [in] p_moveData_yn= Y/N Flag to process the data, Default:Y.

  @version SAS 9.4
  @author Ahmed Al-Attar

**/

%macro etl_appendShrunkData(p_baseDsName=, p_dataDsName=
, p_tmpltDsName=_tmpltOutDs, p_moveData_yn=Y);
    %LOCAL  
        l_eTime
        l_MSG
        l_RC
        l_rTime
        l_sTime;

    %LOCAL  
        l_dsLib1
        l_DsName1
        l_dsLib2
        l_DsName2
        l_memName1
        l_memName2;

    /********** BEGIN -- Macro Parameter Validation **********/

    %if (%superq(p_baseDsName) EQ ) %then
    %do;/* Missing p_baseDsName value in macro call */
        %let l_rc  = 1;
        %let l_msg = ERROR>>> etl_appendShrunkData: p_baseDsName is invalid. Please specify non-missing value;
        %goto exit;
    %end;
    %else
    %do;/* Confirm Dataset Exists */
        %if (%sysfunc(exist(&p_baseDsName,DATA)) = 1) OR
            (%sysfunc(exist(&p_baseDsName,VIEW)) = 1) %then
        %do;
            /* Data set exists */
            %if (%index(&p_baseDsName,%str(.)) EQ 0) %then
            %do;
                %let l_dsLib1=WORK;
                %let l_DsName1=%upcase(&p_baseDsName);
            %end;
            %else
            %do;
                /* Capture Library and Data set Names from &p_baseDsName */
                %let l_dsLib1=%upcase(%scan(&p_baseDsName,1,%str(.)));
                %let l_DsName1=%upcase(%scan(&p_baseDsName,2,%str(.)));
            %end;

            /* Added new code to handle name literals */
            %let l_memName1 = &l_DsName1;
            %if (%index(%superq(l_DsName1),%str(%')) GT 0) OR (%index(%superq(l_DsName1),%str(%")) GT 0) %then 
            %do;
                %let l_len1 = %length(%superq(l_DsName1));
                %let l_memName1 = %substr(%superq(l_DsName1),2, %eval(&l_len-3));
            %end;
        %end;
        %else
        %do;  /* Master Data set does not exist */
            %let l_rc  = 2;
            %let l_msg = ERROR>>> etl_appendShrunkData: p_baseDsName is invalid. %upcase(&p_baseDsName) does not exist;
            %goto exit;
        %end;
    %end;

    %if (%superq(p_dataDsName) EQ ) %then
    %do;/* Missing p_dataDsName value in macro call */
        %let l_rc  = 3;
        %let l_msg = ERROR>>> etl_appendShrunkData: p_dataDsName is invalid. Please specify non-missing value;
        %goto exit;
    %end;
    %else
    %do;/* Confirm Dataset Exists */
        %if (%sysfunc(exist(&p_dataDsName,DATA)) = 1) OR
            (%sysfunc(exist(&p_dataDsName,VIEW)) = 1) %then
        %do;
            /* Data set exists */
            %if (%index(&p_dataDsName,%str(.)) EQ 0) %then
            %do;
                %let l_dsLib2=WORK;
                %let l_DsName2=%upcase(&p_dataDsName);
            %end;
            %else
            %do;
                /* Capture Library and Data set Names from &p_dataDsName */
                %let l_dsLib2=%upcase(%scan(&p_dataDsName,1,%str(.)));
                %let l_DsName2=%upcase(%scan(&p_dataDsName,2,%str(.)));
            %end;
            
            /* Added new code to handle name literals */
            %let l_memName2 = &l_DsName2;
            %if (%index(%superq(l_DsName2),%str(%')) GT 0) OR (%index(%superq(l_DsName2),%str(%")) GT 0) %then 
            %do;
                %let l_len2 = %length(%superq(l_DsName2));
                %let l_memName2 = %substr(%superq(l_DsName2),2, %eval(&l_len2-3));
            %end;
        %end;
        %else
        %do;  /* Master Data set does not exist */
            %let l_rc  = 3;
            %let l_msg = ERROR>>> etl_appendShrunkData: p_dataDsName is invalid. %upcase(&p_dataDsName) does not exist;
            %goto exit;
        %end;
    %end;


    /********** END -- Macro Parameter Validation **********/

    %let l_sTime=%sysfunc(time());

    /* --------------------------------------------------------------------- */
    /* Dynamically create a data set by cosalidating the two input data sets */
    /* and using the longest column lengths from both data sets.             */ 
    /* --------------------------------------------------------------------- */
    FILENAME newdata TEMP;

    /* Compose the Data Step code to create the template data set */
    DATA _NULL_;
        IF (0) Then 
            SET SASHELP.vcolumn(KEEP=name type length label format informat);

        FILE newdata lrecl=300;
        PUT "DATA &p_tmpltDsName;"; 

        /* Declare Hash Object for holding required columns */
        DECLARE hash outCols(ordered:'a') ;
        outCols.defineKey('name');
        outCols.defineData('name','type','length','label','format','informat');
        outCols.defineDone();

        /* Load the Base Data Set columns */
        do until(eof);
            SET SASHELP.vcolumn(WHERE=(libname="&l_dsLib1" AND memname="&l_memName1") 
                KEEP=libname memname name type length label format informat) END=eof;

            if (type = 'char') then type = '$';
            else type = '';

            outCols.add(key:STRIP(translate(name,'_',' '))
            ,data:STRIP(name)
            ,data:type
            ,data:length 
            ,data:coalescec(STRIP(label),STRIP(name))
            ,data:STRIP(format)
            ,data:STRIP(informat));
        end; /* End do until(eof) */

        /* Overlay the Data data set columns while Preserving the longest column length */
        do until(eof2);
            SET SASHELP.vcolumn(WHERE=(libname="&l_dsLib2" AND memname="&l_memName2") 
                KEEP=libname memname name type length label format informat
                RENAME=(name=_name type=_type
                        length=_length label=_label
                        format=_format informat=_informat)) END=eof2;

            if (_type = 'char') then _type = '$';
            else _type = '';

            /* Try to find matching column name */
            rc = outCols.find(KEY:STRIP(_name));
            if (rc NE 0) then
            do;
                /* New column */
                outCols.add(key:STRIP(_name)
                ,data:STRIP(_name)
                ,data:_type
                ,data:_length 
                ,data:coalescec(STRIP(_label),STRIP(_name))
                ,data:STRIP(_format)
                ,data:STRIP(_informat));
            end;
            else
            do; /* Existing column - may require update */
                if ((length LT _length) AND (type = _type)) then
                do;
                    outCols.replace(key:STRIP(name)
                    ,data:STRIP(name)
                    ,data:type
                    ,data:_length 
                    ,data:coalescec(STRIP(label),STRIP(_label))
                    ,data:STRIP(_format)
                    ,data:STRIP(_informat));
                end;
                else if (type NE _type) then
                do;
                    /* Treat as New column, because same name, different type */
                    outCols.add(key:CATS(_name,'_')
                    ,data:CATS(_name,'_')
                    ,data:_type
                    ,data:_length 
                    ,data:coalescec(STRIP(_label),STRIP(_name))
                    ,data:STRIP(_format)
                    ,data:STRIP(_informat));
                end;
            end;
        end; /* End do until (eof2) */

        /* Declare Hash Object Iterator and loop through the items in the Hash Object */
        declare hiter hiter('outCols');
        do while (hiter.next() = 0);
            len = CATS(type,length);
            PUT +3 'ATTRIB ' name 'LENGTH=' len ' LABEL="' label +(-1) '"' @;

            if (not missing(format)) then
                PUT ' FORMAT=' format @; 

            if (missing(informat)) then
                PUT ';';
            else
                PUT ' INFORMAT=' informat ';';
        end; 
        PUT +3 'STOP;';
        PUT 'RUN;';
        STOP;
    RUN;

    /* Execute the Data Step to create the template data set */
    %include newdata;

    %if (%upcase(&p_moveData_yn) EQ Y) %then
    %do;
        /* Populate the template data set */
        PROC APPEND BASE=&p_tmpltDsName DATA=&p_baseDsName FORCE; RUN;

        /* Delete and Replace the base data set with the new template data set */
        PROC DELETE DATA=&p_baseDsName; RUN;
        
        %if (%sysfunc(exist(WORK.&l_dsName1))) %then
        %do;
            PROC DELETE DATA=WORK.&l_dsName1; RUN;
        %end;
        
        PROC DATASETS LIB=WORK NOLIST;
            CHANGE &p_tmpltDsName=&l_dsName1;
        %if (&l_dsLib1 NE WORK) %then
        %do;
            COPY OUT=&l_dsLib1 MOVE; SELECT &l_dsName1;
        %end;
        RUN; QUIT;

        /* Append the input data to the newly created/modified base data set */
        PROC APPEND BASE=&p_baseDsName DATA=&p_dataDsName FORCE; RUN;
    %end;
    
    %goto finished;

    %exit:
        %put *** ERROR: etl_appendShrunkData  ***;
        %put *** l_RC must be zero (0).   ***;
        %put *** l_RC= &l_RC    .         ***;
        %put *** &l_MSG ***;
        %put *** ERROR: etl_appendShrunkData  ***;

   %finished:
        %let l_eTime=%sysfunc(time());
        %let l_rTime=%sysfunc(putn(%sysevalf(&l_eTime - &l_sTime),time12.2));
        %put >>> etl_appendShrunkData :>>> Total RunTime = &l_rTime;
        ;

%mend etl_appendShrunkData;
