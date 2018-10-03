/**************************************************************************
 Program:  Ncdb_2010_dc_blk.sas
 Library:  Horning
 Project:  NeighborhoodInfo DC
 Author:   P. Tatian
 Created:  04/06/11
 Version:  SAS 9.1
 Environment:  Windows
 
 Description:  Export 2010 block data for mapping.

 Modifications:
**************************************************************************/

%include "K:\Metro\PTatian\DCData\SAS\Inc\Stdhead.sas";

** Define libraries **;
%DCData_lib( Horning )
%DCData_lib( NCDB )

data Horning.Ncdb_2010_dc_blk (compress=no);

  set NCDB.Ncdb_2010_dc_blk (keep=geoblk2010 trctpop1 adult1n child1n);
  
run;

/*
filename fexport "D:\DCData\Libraries\Horning\Maps\Ncdb_2010_dc_blk.csv" lrecl=256;

proc export data=Ncdb_2010_dc_blk
    outfile=fexport
    dbms=csv replace;

run;

filename fexport clear;


