/**************************************************************************
 Program:  Horning_2011_02.sas
 Library:  Requests
 Project:  NeighborhoodInfo DC
 Author:   P. Tatian
 Created:  02/14/11
 Version:  SAS 9.1
 Environment:  Windows
 
 Description:  Prepare data for Horning Family Fund data request
 (memo 2/20/11).

 Modifications:
**************************************************************************/

%include "K:\Metro\PTatian\DCData\SAS\Inc\Stdhead.sas";

** Define libraries **;
%DCData_lib( Requests )
%DCData_lib( Census )
%DCData_lib( ACS )

******  Create block group selection format  ******;

** Read block list **;

filename fimport "D:\DCData\Libraries\Requests\Maps\2011\2933_Stanton_Rd_SE_1_2mi_blocks.csv" lrecl=256;

data a2933_Stanton_Rd_SE_1_2mi_blocks;

  infile fimport dsd stopover firstobs=2;

  input
    cjrTractBl : $9.
    Cnt_cjrTra : $1.
    FullArea
    Shape_Leng 
    Shape_Area
  ;

  %Octo_GeoBlk2000()
    
run;

filename fimport clear;

proc sort data=a2933_Stanton_Rd_SE_1_2mi_blocks;
  by geoblk2000;
run;

data All_blocks;

  merge 
    Census.Cen2000_sf1_dc_blks (keep=geoblk2000 p1i1)
    a2933_Stanton_Rd_SE_1_2mi_blocks (keep=geoblk2000 in=in2);
  by geoblk2000;
  
  length GeoBg2000 $ 12;
  
  GeoBg2000 = geoblk2000;
  
  in_buffer = in2;
  
  
run;


%File_info( data=All_blocks, printobs=50 )

run;

proc summary data=All_blocks;
  by GeoBg2000;
  var p1i1;
  output out=BG_pop sum=Bg_pop;
run;

proc summary data=All_blocks;
  where in_buffer;
  by GeoBg2000;
  var p1i1;
  output out=BG_selected_pop sum=Bg_selected_pop;
run;

data BG_selected;

  merge
    BG_pop (drop=_type_ _freq_) BG_selected_pop (drop=_type_ _freq_);
  by GeoBg2000;
  
  if Bg_selected_pop / Bg_pop >= 0.5;
  
run;

proc print data=BG_selected;
run;

%Data_to_format(
  FmtLib=work,
  FmtName=$BGsel,
  Desc=,
  Data=BG_selected,
  Value=GeoBg2000,
  Label=GeoBg2000,
  OtherLabel='',
  DefaultLen=.,
  MaxLen=.,
  MinLen=.,
  Print=Y,
  Contents=N
  )


******  Create tract selection format  ******;

** Read block list **;

filename fimport "D:\DCData\Libraries\Requests\Maps\2011\2933_Stanton_Rd_SE_1_2mi_tracts.csv" lrecl=256;

data a2933_Stanton_Rd_SE_1_2mi_tr;

  infile fimport dsd stopover firstobs=2;

  input
    OBJECTID
    GIS_ID : $16.
    FEDTRACTNO : $16.
    TRACTNO : $16.
    AREASQMI
    POPDENSITY
    TOTAL
    NAME : $40.
    SHAPE_AREA
    SHAPE_LEN
  ;

  %Fedtractno_geo2000()
    
run;

filename fimport clear;

proc sort data=a2933_Stanton_Rd_SE_1_2mi_tr;
  by geo2000;
run;

proc print;
run;

%Data_to_format(
  FmtLib=work,
  FmtName=$Trsel,
  Desc=,
  Data=a2933_Stanton_Rd_SE_1_2mi_tr,
  Value=Geo2000,
  Label=Geo2000,
  OtherLabel='',
  DefaultLen=.,
  MaxLen=.,
  MinLen=.,
  Print=Y,
  Contents=N
  )


******  Compile data  ******;

%let year = 2005_09;
%let year_lbl = 2005-09;
%let year_dollar = 2009;

data ACS_bg;

  set ACS.acs_sf_2005_09_bg00 (keep=geobg2000 b01001e: b01003e1 B11001e1 B11003e1 B17001e: B23001e:);
  
  where put( geobg2000, $bgsel. ) ~= '';
  
    ** Demographics **;
    
    TotPop_&year = B01003e1;
    
    NumHshlds_&year = B11001e1;

    NumFamilies_&year = B11003e1;

    PopUnder5Years_&year = sum( B01001e3, B01001e27 );
    
    PopUnder18Years_&year = 
      sum( B01001e3, B01001e4, B01001e5, B01001e6, 
           B01001e27, B01001e28, B01001e29, B01001e30 );
    
    Pop65andOverYears_&year = 
      sum( B01001e20, B01001e21, B01001e22, B01001e23, B01001e24, B01001e25, 
           B01001e44, B01001e45, B01001e46, B01001e47, B01001e48, B01001e49 );
    
    ** Poverty **;
    
    ChildrenPovertyDefined_&year = 
      sum( B17001e4, B17001e5, B17001e6, B17001e7, B17001e8, B17001e9, 
           B17001e18, B17001e19, B17001e20, B17001e21, B17001e22, B17001e23,
           B17001e33, B17001e34, B17001e35, B17001e36, B17001e37, B17001e38, 
           B17001e47, B17001e48, B17001e49, B17001e50, B17001e51, B17001e52
          );

    ElderlyPovertyDefined_&year = 
      sum( B17001e15, B17001e16, B17001e29, B17001e30,
           B17001e44, B17001e45, B17001e58, B17001e59
      );

    PersonsPovertyDefined_&year = B17001e1;
    
    PopPoorChildren_&year = 
      sum( B17001e4, B17001e5, B17001e6, B17001e7, B17001e8, B17001e9, 
           B17001e18, B17001e19, B17001e20, B17001e21, B17001e22, B17001e23 );

    PopPoorElderly_&year = 
      sum( B17001e15, B17001e16, B17001e29, B17001e30 );

    PopPoorPersons_&year = B17001e2;
    
    PopPoorAdults_&year = PopPoorPersons_&year - ( PopPoorChildren_&year + PopPoorElderly_&year );
    
    label
      PopPoorPersons_&year = "Persons below the poverty level last year, &year_lbl"
      PersonsPovertyDefined_&year = "Persons with poverty status determined, &year_lbl"
      PopPoorChildren_&year = "Children under 18 years old below the poverty level last year, &year_lbl"
      ChildrenPovertyDefined_&year = "Children under 18 years old with poverty status determined, &year_lbl"
      PopPoorElderly_&year = "Persons 65 years old and over below the poverty level last year, &year_lbl"
      ElderlyPovertyDefined_&year = "Persons 65 years old and over with poverty status determined, &year_lbl"
    ;
    
    ** Employment **;
    
    PopCivilianEmployed_&year = 
      sum( B23001e7, B23001e14, B23001e21, B23001e28, B23001e35, B23001e42, B23001e49, 
           B23001e56, B23001e63, B23001e70, B23001e75, B23001e80, B23001e85,
           B23001e93, B23001e100, B23001e107, B23001e114, B23001e121, B23001e128, 
           B23001e135, B23001e142, B23001e149, B23001e156, B23001e161, B23001e166, B23001e171 );

    PopUnemployed_&year = 
      sum( B23001e8, B23001e15, B23001e22, B23001e29, B23001e36, B23001e43, B23001e50, 
           B23001e57, B23001e64, B23001e71, B23001e76, B23001e81, B23001e86, 
           B23001e94, B23001e101, B23001e108, B23001e115, B23001e122, B23001e129, 
           B23001e136, B23001e143, B23001e150, B23001e157, B23001e162, B23001e167, B23001e172 );
    
    PopInCivLaborForce_&year = sum( PopCivilianEmployed_&year, PopUnemployed_&year );
    
    Pop16andOverEmployed_&year = PopCivilianEmployed_&year +
      sum( B23001e5, B23001e12, B23001e19, B23001e26, B23001e33, B23001e40, 
           B23001e47, B23001e54, B23001e61, B23001e68,
           B23001e91, B23001e98, B23001e105, B23001e112, B23001e119, B23001e126, 
           B23001e133, B23001e140, B23001e147, B23001e154 );

    Pop16andOverYears_&year = B23001e1;
    
    label
      PopCivilianEmployed_&year = "Persons 16+ years old in the civilian labor force and employed, &year_lbl"
      PopUnemployed_&year = "Persons 16+ years old in the civilian labor force and unemployed, &year_lbl"
      PopInCivLaborForce_&year = "Persons 16+ years old in the civilian labor force, &year_lbl"
      Pop16andOverEmployed_&year = "Persons 16+ years old who are employed (includes armed forces), &year_lbl"
      Pop16andOverYears_&year = "Persons 16+ years old, &year_lbl"
    ;
    
    
 run;

%File_info( data=ACS_bg, contents=n, printobs=0 )

run;


data ACS_tr;

  set ACS.acs_sf_2005_09_tr00 
        (keep=geo2000 b01001e: b01003e1 B11001e1 B11003e: B11013e: B17001e: B23001e:);
  
  where put( geo2000, $trsel. ) ~= '';
  
    ** Demographics **;
    
    TotPop_&year = B01003e1;
    
    NumHshlds_&year = B11001e1;

    NumFamilies_&year = B11003e1;

    PopUnder5Years_&year = sum( B01001e3, B01001e27 );
    
    PopUnder18Years_&year = 
      sum( B01001e3, B01001e4, B01001e5, B01001e6, 
           B01001e27, B01001e28, B01001e29, B01001e30 );
    
    Pop18andOverYears_&year = TotPop_&year - PopUnder18Years_&year;
    
    Pop65andOverYears_&year = 
      sum( B01001e20, B01001e21, B01001e22, B01001e23, B01001e24, B01001e25, 
           B01001e44, B01001e45, B01001e46, B01001e47, B01001e48, B01001e49 );
    
    ** Household type **;

    NumFamiliesOwnChildren_&year = 
      sum( B11003e3, B11003e10, B11003e16 ) + 
      sum( B11013e3, B11013e5, B11013e6 );
    
    NumFamiliesOwnChildrenFH_&year = B11003e16 + B11013e5;

    label
      NumFamiliesOwnChildren_&year = "Total families and subfamilies with own children, &year_lbl"
      NumFamiliesOwnChildrenFH_&year = "Female-headed families and subfamilies with own children, &year_lbl"
    ;
    
    ** Poverty **;
    
    ChildrenPovertyDefined_&year = 
      sum( B17001e4, B17001e5, B17001e6, B17001e7, B17001e8, B17001e9, 
           B17001e18, B17001e19, B17001e20, B17001e21, B17001e22, B17001e23,
           B17001e33, B17001e34, B17001e35, B17001e36, B17001e37, B17001e38, 
           B17001e47, B17001e48, B17001e49, B17001e50, B17001e51, B17001e52
          );

    ElderlyPovertyDefined_&year = 
      sum( B17001e15, B17001e16, B17001e29, B17001e30,
           B17001e44, B17001e45, B17001e58, B17001e59
      );

    PersonsPovertyDefined_&year = B17001e1;
    
    PopPoorChildren_&year = 
      sum( B17001e4, B17001e5, B17001e6, B17001e7, B17001e8, B17001e9, 
           B17001e18, B17001e19, B17001e20, B17001e21, B17001e22, B17001e23 );

    PopPoorElderly_&year = 
      sum( B17001e15, B17001e16, B17001e29, B17001e30 );

    PopPoorPersons_&year = B17001e2;
    
    PopPoorAdults_&year = PopPoorPersons_&year - ( PopPoorChildren_&year + PopPoorElderly_&year );

    label
      PopPoorPersons_&year = "Persons below the poverty level last year, &year_lbl"
      PersonsPovertyDefined_&year = "Persons with poverty status determined, &year_lbl"
      PopPoorChildren_&year = "Children under 18 years old below the poverty level last year, &year_lbl"
      ChildrenPovertyDefined_&year = "Children under 18 years old with poverty status determined, &year_lbl"
      PopPoorElderly_&year = "Persons 65 years old and over below the poverty level last year, &year_lbl"
      ElderlyPovertyDefined_&year = "Persons 65 years old and over with poverty status determined, &year_lbl"
    ;
    
    ** Employment **;
    
    PopCivilianEmployed_&year = 
      sum( B23001e7, B23001e14, B23001e21, B23001e28, B23001e35, B23001e42, B23001e49, 
           B23001e56, B23001e63, B23001e70, B23001e75, B23001e80, B23001e85,
           B23001e93, B23001e100, B23001e107, B23001e114, B23001e121, B23001e128, 
           B23001e135, B23001e142, B23001e149, B23001e156, B23001e161, B23001e166, B23001e171 );

    PopUnemployed_&year = 
      sum( B23001e8, B23001e15, B23001e22, B23001e29, B23001e36, B23001e43, B23001e50, 
           B23001e57, B23001e64, B23001e71, B23001e76, B23001e81, B23001e86, 
           B23001e94, B23001e101, B23001e108, B23001e115, B23001e122, B23001e129, 
           B23001e136, B23001e143, B23001e150, B23001e157, B23001e162, B23001e167, B23001e172 );
    
    PopInCivLaborForce_&year = sum( PopCivilianEmployed_&year, PopUnemployed_&year );
    
    Pop16andOverEmployed_&year = PopCivilianEmployed_&year +
      sum( B23001e5, B23001e12, B23001e19, B23001e26, B23001e33, B23001e40, 
           B23001e47, B23001e54, B23001e61, B23001e68,
           B23001e91, B23001e98, B23001e105, B23001e112, B23001e119, B23001e126, 
           B23001e133, B23001e140, B23001e147, B23001e154 );

    Pop16andOverYears_&year = B23001e1;
    
    label
      PopCivilianEmployed_&year = "Persons 16+ years old in the civilian labor force and employed, &year_lbl"
      PopUnemployed_&year = "Persons 16+ years old in the civilian labor force and unemployed, &year_lbl"
      PopInCivLaborForce_&year = "Persons 16+ years old in the civilian labor force, &year_lbl"
      Pop16andOverEmployed_&year = "Persons 16+ years old who are employed (includes armed forces), &year_lbl"
      Pop16andOverYears_&year = "Persons 16+ years old, &year_lbl"
    ;
    
    
 run;

%File_info( data=ACS_tr, contents=n, printobs=0 )

run;

%fdate() 

options nodate nonumber orientation=landscape;

ods rtf file="D:\DCData\Libraries\Requests\Prog\2011\Horning_2011_02.rtf" style=Styles.Rtf_arial_9pt;

proc tabulate data=ACS_tr format=comma12.0 noseps missing;
  class geo2000;
  var TotPop_&year Pop18andOverYears_&year PopUnder18Years_&year NumHshlds_&year NumFamilies_&year
      NumFamiliesOwnChildren_&year NumFamiliesOwnChildrenFH_&year
      PopPoorPersons_&year PopPoorChildren_&year PopPoorAdults_&year PopPoorElderly_&year
      PopInCivLaborForce_&year PopCivilianEmployed_&year PopUnemployed_&year;
  table 
    /** Rows **/
    all='\b Total' geo2000=' ',
    /** Columns **/
    sum=' ' * ( 
      TotPop_&year="Population, &year_lbl" 
      Pop18andOverYears_&year="Adults, &year_lbl"
      PopUnder18Years_&year="Children, &year_lbl"
      NumHshlds_&year="Households, &year_lbl"
      NumFamilies_&year="Families, &year_lbl"
      NumFamiliesOwnChildren_&year="Families w/children, &year_lbl"
      NumFamiliesOwnChildrenFH_&year="Female-headed families w/children, &year_lbl"
    )
  ;
  table 
    /** Rows **/
    all='\b Total' geo2000=' ',
    /** Columns **/
    sum="Persons below federal poverty level, &year_lbl" * ( 
      PopPoorPersons_&year="Total"
      PopPoorChildren_&year="Children (under\~18)"
      PopPoorAdults_&year="Non-elderly adults (18-64)"
      PopPoorElderly_&year="Elderly (65+)"
    )
  ;
  table 
    /** Rows **/
    all='\b Total' geo2000=' ',
    /** Columns **/
    sum="Persons in civilan labor force, &year_lbl" * ( 
      PopInCivLaborForce_&year="Total"
      PopCivilianEmployed_&year="Employed" 
      PopUnemployed_&year="Unemployed"
    )
  ;
  title1 "Data for Census Tracts Within 1/2 Mile of 2933 Stanton Road SE";
  footnote1 height=9pt "Prepared for Horning Family Fund by NeighborhoodInfo DC (www.NeighborhoodInfoDC.org), &fdate..";
  footnote2 height=9pt j=r '{Page}\~{\field{\*\fldinst{\pard\b\i0\chcbpat8\qc\f1\fs19\cf1{PAGE }\cf0\chcbpat0}}}';
run;

ods rtf close;
