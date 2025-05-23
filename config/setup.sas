/**
  @file setup.sas
  @brief Initializes and sets up the SAS session
  @details 
  Contains various SAS statements that gets executed automatically whenever a SAS session is started,
  in order to customize the SAS session and initialize required application settings.

  <h4> SAS Macros </h4>
  @li censusapi_getusgeohierarchy.sas

  <h4> Related Programs </h4>
 
  @version SAS 9.4
  @author Ahmed Al-Attar

**/

/* ----------------------------- */
/* Define global macro variables */
/* ----------------------------- */
%GLOBAL
	g_projRootPath  /* Location of EG Project Root/Parent dir */
	g_apiKey		/* Personal US Census Data API Key */
	;

%LET g_projRootPath = <Put your value here>;	*<---- Specify installation path. Do not include trailing slash!;
%LET g_apiKey = <Put your value here>;	*<---- Specify your Developer API Key.; 
	 * You can use this link (https://api.census.gov/data/key_signup.html) to request a key;

/* ========== Do not modify below this line ========== */

/* ----------------------------- */
/* Define global macro variables */
/* ----------------------------- */
%GLOBAL
	g_slash			/* OS Specific slash representation */
	g_sasauto		/* OS Sepecific SASAUTOS representation */
	g_computeHostName	/* Host name running this SAS session */
	g_sasCodeRoot   /* Location of custom SAS Code files  */
	g_sasProgramRoot /* Location of custom SAS Program files  */
	g_sasMacroRoot  /* Location of custom SAS Macro Files */
	;
/* ------------------------------- */
/* Host and Environment Parameters */
/* ------------------------------- */

/* Declare inner utility macro to Assign host OS specific macro
   variables */
%macro inner_hostMacros;

	%if (&SYSSCP = WIN) %then
	%do; /* Windows Operating System */
		%let g_slash   = %str(\);
		%let g_sasauto = SASAUTOS;
	%end; /* Windows Operating System */
	%else
	%do; /* Otherwise assume it's UNIX */
		%let g_slash   = %str(/);
		%let g_sasauto = "!SASROOT/sasautos";
	%end; /* Otherwise assume it's UNIX */
	%let g_computeHostName = &SYSTCPIPHOSTNAME;

%mend inner_hostMacros;

/* Execute inner utility macro */
%inner_hostMacros;

%let g_sasCodeRoot     = &g_projRootPath.&g_slash.code;
%let g_sasProgramRoot  = &g_sasCodeRoot.&g_slash.programs;
%let g_sasMacroRoot    = &g_sasCodeRoot.&g_slash.macros;
%let g_outputRoot      = &g_projRootPath.&g_slash.output;

OPTIONS 
	SASAUTOS = (&g_sasauto ,
	"&g_sasMacroRoot.&g_slash.censusapi" ,"&g_sasMacroRoot.&g_slash.etl" ,"&g_sasMacroRoot.&g_slash.util")
	MAUTOSOURCE ;

OPTIONS 
	FULLSTIMER /* Writes all available system performance statistics to the SAS log */
	SORTEQUALS /* Controls how PROC SORT orders observations with identical BY values in the output data set */
	OBS=MAX    /* Specifies when to stop processing observations or records */
	MSGLEVEL=I /* Controls the level of detail in messages that are written to the SAS log */
	SPOOL      /* Controls whether SAS writes SAS statements to a utility data set in the WORK data library */
	NOSYNTAXCHECK	/* Does not enable syntax check mode for statements that are submitted within a */
					/* non-interactive or batch SAS session.       */
	COMAMID=TCP	/* Identifies the communications access method for connecting a client and a server across */
				/* a network */
	AUTOSIGNON	/* Automatically signs on to the server when the client issues a remote submit request */
				/* for server processing.                      */
	VALIDVARNAME=ANY  /* Allows the use of column names that contain embedded spaces and special characters */
	NOTES
	/*SOURCE
	SOURCE2*/
	NOMPRINT
	DEBUG=DBMS_SELECT	/* shows only the select statements generated */
	sastrace=',,t,dsab' /* Display a summary of all generated SQL code, any threaded read/write operations, */
						/* and timing summary & details. */
	sastraceloc=saslog 
	nostsuffix
	DLCREATEDIR /* Specifies to create a directory for the SAS library that is named in a LIBNAME statement */
				/* if the directory does not exist. */
	;

/*proc options option=sasautos; run;*/
LIBNAME apilib "&g_projRootPath.&g_slash.data";
OPTIONS FMTSEARCH=(WORK apilib);

/* Generate Census Bureau-designated regions and divisions Goegraphy Hierarchy Lookup table */
%censusapi_getUsGeoHierarchy(p_outDsName=apilib.Census_reg_div_lkup)