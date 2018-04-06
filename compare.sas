
libname proclib '/u04/dataloader/JARVIS';

proc sort data=proclib.vs;
 by STUDYID SUBJID;
run;

proc sort data=proclib.v_s;
 by STUDYID SUBJID;
run;

proc compare base=proclib.vs compare=proclib.v_s out=proclib.result(keep=STUDYID SUBJID) OUTNOEQUAL;
   by STUDYID SUBJID;
run;


data proclib.out;
	set proclib.vs (in=a)
		proclib.v_s (in=b);
	by SUBJID;
	if a=1 then do;
		source='DMW';
		output;
	end;
	if b=1 then do;
		source='ADVERSE';
		output;
	end;
run;

data proclib.finale;
merge proclib.out(in=a) proclib.result(in=b);
by STUDYID SUBJID;
if b=1 then diff=1;
output;
run;
ODS LISTING CLOSE;
ods html body='/u04/dataloader/JARVIS/external-HTML-file.html';
ods excel file='/u04/dataloader/JARVIS/external-HTML-file.xlsx';
ods rtf file='/u04/dataloader/JARVIS/external-HTML-file.rtf';

proc report data=proclib.finale nowd headline headskip;
	column STUDYID	SUBJID	VSDTC	VSTMC	VSTPTNUM	VSTPTCD	VSTPT	VSTESTCD	VSTEST	VSORRES	VSORRESU	VSPOS	VSGRPID	VSSPID	VISIT	VISITNUM	DOMAIN	source;
/*	define diff / display;*/
	compute diff;
	if diff = 1 then call define(_row_,"style","style={background=yellow}");
   endcomp;
run;

ods html close;
ods pdf close;
ods rtf close;




