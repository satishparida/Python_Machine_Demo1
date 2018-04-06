%macro COMPARE;
/*We need to know the Primary key list*/
/*We need to know the coulmn mapping between 2 tables if they have different names*/

	option mprint;

	%let OUT_EXCEL=Y;
	%let OUT_RTF=Y;
	%let OUT_HTML=Y;
	%let OUT_MAIL=Y;
	%let REQUESTEE=TEST;
	%let IN_SOURCE_DMW=DMW;
	%let IN_SOURCE_ADVERSE=ADVERSE;
	%let WORKING_DIR=/u04/dataloader/skparida/App/ZZ;
	%let STUDY_NAME=TICIPS001;
	%let URL_ADVERSE=http://10.48.15.135:8006/RestAPI/jersey/data/alldata;

	%let PK_VARS = COUNTRY STUDYID SITEID SUBJID AETERM; *To be input from parameters;

	%let CSDW_DS=proclib.ae_csdw;
	%let ADVERSE_DS=proclib.ae_adv;


	%let WeekDate  = %sysfunc(date(),weekdate29.) ;
	%let Time      = %sysfunc(time(),time8.0)     ;

	libname proclib "&WORKING_DIR.";

/*	data proclib.mapper;*/
/*	input source1:$32. source2:$32.;*/
/*	datalines;*/
/*	COUNTRY COUNTRY*/
/*	STUDYID STUDY_PROTOCOL_NO*/
/*	SITEID SITE_ID*/
/*	SUBJID PATIENT_ID*/
/*	AESR AE_TYPE*/
/*	AETERM AE_PROBLEM_DESC*/
/*	AESTDTC AE_START_DATE */
/*	AEENDTC AE_END_DATE*/
/*	AEENRF ONGOING*/
/*	AESEV AE_DESC*/
/*	;*/
/*	run;*/

	data &CSDW_DS.;
	format AESTDTC AEENDTC date9.;
	set proclib.ae;
	AESTDTC=datepart(AESTDTC);
	AEENDTC=datepart(AEENDTC);
	run;

	filename resp "&WORKING_DIR./output.xml";
	proc http 
	   url="&URL_ADVERSE." 
	   out=resp
	   METHOD='GET';
	run;

	filename advers temp;
	libname advers xmlv2 "&WORKING_DIR./output.xml" automap=replace xmlmap=advers ;

	proc copy in=advers out=proclib noclone;
	run;

	data &ADVERSE_DS.(drop=STUDY_PROTOCOL_NO SITE_ID PATIENT_ID AE_TYPE AE_PROBLEM_DESC AE_START_DATE AE_END_DATE ONGOING AE_DESC);
	set advers.PVMODEL;
	COUNTRY=COUNTRY;
	STUDYID=PROTOCOL;
	SITEID=SITEID;
	SUBJID=PATIENTID;
	AESR=AE_TYPE;
	AETERM=DESCRIPTION;
	AESTDTC=datepart(AE_START_DATE);
	AEENDTC=.;
	AEENRF=ONGOING;
	AESEV=AE_DESC;
	run;

	proc sort data=&CSDW_DS.;
	 by &PK_VARS.;
	run;

	proc sort data=&ADVERSE_DS.;
	 by &PK_VARS.;
	run;

	proc compare base=&CSDW_DS. compare=&ADVERSE_DS. out=difference(keep=&PK_VARS.) OUTNOEQUAL;
	   by &PK_VARS.;
	run;

	proc compare base=&ADVERSE_DS. compare=&CSDW_DS. out=difference1(keep=&PK_VARS.) OUTNOEQUAL;
	   by &PK_VARS.;
	run;

	proc sql;
		create table difference_all as
		select * from difference
		union
		select * from difference1
		;
	quit;

	data appended_ds;
	length SOURCE $10.;
		set &ADVERSE_DS. (in=a)
			&ADVERSE_DS. (in=b);
		by &PK_VARS.;
		if a=1 then do;
			SOURCE="&IN_SOURCE_DMW.";
			output;
		end;
		if b=1 then do;
			SOURCE="&IN_SOURCE_ADVERSE.";
			output;
		end;
	run;

	data report;
	merge appended_ds(in=a) difference_all(in=b);
	by &PK_VARS.;
	if b=1 then diff=1;
	output;
	run;

	proc contents data=report out=col_names;
	run;

	proc sql noprint;
	select upcase(name) into : ALL_COLS separated by " " from col_names order by varnum;
	quit;

	%put all_cols: &ALL_COLS.;

	options orientation=landscape bottommargin = 1.0in Topmargin=1.0in leftmargin=1.0in rightmargin=1.0in;

	ODS LISTING CLOSE;
	%if &OUT_HTML.=Y %then %do;
		ods html body="&WORKING_DIR./&STUDY_NAME..html";
	%end;
	%if &OUT_EXCEL.=Y %then %do;
		ods excel file="&WORKING_DIR./&STUDY_NAME..xlsx";
	%end;
	%if &OUT_RTF.=Y %then %do;
		ods rtf file="&WORKING_DIR./&STUDY_NAME..rtf";
	%end;
	TITLE1 "Report requestee: &REQUESTEE.";

	TITLE2 "&WeekDate. &Time.";

	proc report data=report nowd headline headskip;
		column &ALL_COLS.;

		compute diff;
		if diff = 1 then call define(_row_,"style","style={background=red}");
	    endcomp;

		define diff / display noprint;
	run;
	%if &OUT_HTML.=Y %then %do;
		ods html close;
	%end;
	%if &OUT_EXCEL.=Y %then %do;
		ods excel close;
	%end;
	%if &OUT_RTF.=Y %then %do;
	ods rtf close;
	%end;
	ODS LISTING;

%mend COMPARE;
%COMPARE;