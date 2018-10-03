/**************************************************************************
 Program:  Horning_2011_02_tr.sas
 Library:  Requests
 Project:  NeighborhoodInfo DC
 Author:   P. Tatian
 Created:  02/14/11
 Version:  SAS 9.1
 Environment:  Windows
 
 Description:  Prepare data for Horning Family Fund data request
 (memo 2/20/11).
 
 TRACT LEVEL DATA.
 
 NOTE:  Have to manually correct the percent income change for the Total
 of all census tracts. 

 Modifications:
  04/01/11 PAT Add 2010 Census population data.
  04/18/11 PAT Added unborn children to TANF, FS tables.
**************************************************************************/

%include "K:\Metro\PTatian\DCData\SAS\Inc\Stdhead.sas";

** Define libraries **;
%DCData_lib( Requests )
%DCData_lib( Census )
%DCData_lib( ACS )
%DCData_lib( Tanf )
%DCData_lib( Vital )
%DCData_lib( NLIHC )
%DCData_lib( HUD )
%DCData_lib( NCDB )
%DCData_lib( RealProp )

******  Create tract selection format  ******;

** Read tract list **;

filename fimport "D:\DCData\Libraries\Horning\Maps\2933_Stanton_Rd_SE_1_2mi_tracts.csv" lrecl=256;

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

** Subsidized housing/NLIHC catalog **;

proc format;
  value ProgCat (notsorted)
    1 = 'Public Housing only'
    2 = 'Section 8 only'
    9 = 'Section 8 and other subsidies'
    3 = 'LIHTC only'
    4 = 'HOME only'
    5 = 'CDBG only'
    6 = 'HPTF only'
    /*7 = 'Other single subsidy'*/
    8 = 'LIHTC and Tax Exempt Bond only'
    7, 10 = 'All other combinations';
run;

proc sort data=NLIHC.Assisted_units out=Assisted_units;
  by ssl;
  
data NLIHC_cat_pr NLIHC_cat_pr_all;

  merge 
    Assisted_units (keep=NLIHC_ID ProgCat mid_asst_units ssl Proj_Name Proj_Addr_ref in=in1)
    RealProp.Parcel_geo (keep=ssl geo2000 x_coord y_coord);
  by ssl;
  
  if in1;
  
  if put( geo2000, $trsel. ) ~= '' then select = 1;
  else select = 0;
  
  select ( ProgCat );
    when ( 1 ) asst_units_pub_hsng = mid_asst_units;
    when ( 2 ) asst_units_s8_only  = mid_asst_units;
    when ( 9 ) asst_units_s8_plus  = mid_asst_units;
    otherwise  asst_units_other = mid_asst_units;
  end;
  
  Proj_Name = propcase( left( Proj_Name ) );
  
  Proj_Name = tranwrd( Proj_Name, "Ii", "II" );
  Proj_Name = tranwrd( Proj_Name, "Se", "SE" );
  
  rename mid_asst_units=asst_units_total;
  
  format ProgCat ProgCat.; 
  
  if select then output NLIHC_cat_pr;
  
  output NLIHC_cat_pr_all;
  
run;

filename fexport "D:\DCData\Libraries\Horning\Maps\Horning_all_projects.csv" lrecl=2000;

proc export data=NLIHC_cat_pr_all
    outfile=fexport
    dbms=csv replace;

run;

filename fexport clear;

filename fexport "D:\DCData\Libraries\Horning\Maps\Horning_sel_projects.csv" lrecl=2000;

proc export data=NLIHC_cat_pr
    outfile=fexport
    dbms=csv replace;

run;

filename fexport clear;

proc print data=NLIHC_cat_pr n;
run;

proc summary data=NLIHC_cat_pr nway;
  class geo2000;
  var asst_units_: ;
  output out=NLIHC_cat sum= ;
run;

** 2010 estimate for population under 5 **;

proc summary data=NCDB.PopUnder5years_2010_blk nway;
  var PopUnder5years_2010;
  class geo2000;
  output out=PopUnder5years_2010 sum=;
run;

** Combine all data **;

data ACS_tr;

  merge
    ACS.acs_sf_2005_09_tr00 
      (keep=geo2000 b01001e: b01003e1 B11001e1 B11003e: B11013e: B17001e: B23001e:)
    Acs.Acs_5yr_sum_tr_tr00 
      (keep=geo2000 aggfamilyincome_2005_09 numfamilies_2005_09)
    Tanf.Tanf_sum_tr00
      (keep=geo2000 tanf_client_2010 tanf_unborn_2010 tanf_child_2010 tanf_adult_2010)
    Tanf.Fs_sum_tr00
      (keep=geo2000 fs_client_2010 fs_unborn_2010 fs_child_2010 fs_adult_2010)
    Vital.Births_sum_tr00
      (keep=geo2000 births_total_2007 births_teen_2007 births_single_2007 births_prenat_inad_2007)
    Vital.Deaths_sum_tr00
      (keep=geo2000 deaths_total_2007 deaths_violent_2007 deaths_heart_2007)
    NLIHC_cat
      (keep=geo2000 asst_units_total asst_units_pub_hsng asst_units_s8_only asst_units_s8_plus asst_units_other)
    Hud.Apsh_2008_vouchers_dc
      (keep=geo2000 number_reported)
    Ncdb.Ncdb_sum_tr00 
      (keep=geo2000 totpop_2000 PopUnder5years_2000 popunder18years_2000 avgfamilyincome_2000)
    Ncdb.Ncdb_sum_2010_tr00 
      (keep=geo2000 totpop_2010 popunder18years_2010)
    PopUnder5years_2010 
      (keep=geo2000 PopUnder5years_2010)
  ;
  by geo2000;
  
  where put( geo2000, $trsel. ) ~= '';
  
  Pop18andOverYears_2000 = totpop_2000 - popunder18years_2000;
  Pop18andOverYears_2010 = totpop_2010 - popunder18years_2010;
  
  ** Change **;
  
  Chg_TotPop_2000_10 = TotPop_2010 - TotPop_2000;
  Chg_Pop18andOverYears_2000_10 = Pop18andOverYears_2010 - Pop18andOverYears_2000;
  Chg_PopUnder5years_2000_10 = PopUnder5years_2010 - PopUnder5years_2000;
  Chg_PopUnder18years_2000_10 = PopUnder18years_2010 - PopUnder18years_2000;
  
  ** Recode missings to 0 **;

  array a{*} asst_units_: number_reported;
  
  do i = 1 to dim( a );
    if a{i} = . then a{i} = 0;
  end;
  
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
    
    ** Family income **;
    
    if numfamilies_2005_09 > 0 then avgfamilyincome_2005_09  = aggfamilyincome_2005_09 / numfamilies_2005_09;
    
    %dollar_convert( avgfamilyincome_2000, avgfamilyincome_2000_d09, 1999, 2009 )
    
    chg_avgfamilyincome_2000_0509 = avgfamilyincome_2005_09 - avgfamilyincome_2000_d09;
    
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
    
    rename number_reported=asst_units_vouchers;
      
run;

%File_info( data=ACS_tr, contents=n, printobs=0 )

run;

%fdate() 

options nodate nonumber orientation=landscape;

ods rtf file="D:\DCData\Libraries\Horning\Prog\Horning_2011_02_tr.rtf" style=Styles.Rtf_arial_9pt;

proc tabulate data=ACS_tr format=comma12.0 noseps missing;
  class geo2000;
  var TotPop_2000 Pop18andOverYears_2000 PopUnder5years_2000 PopUnder18Years_2000
      TotPop_2010 Pop18andOverYears_2010 PopUnder5years_2010 PopUnder18Years_2010 
      Chg_TotPop_2000_10 Chg_Pop18andOverYears_2000_10 Chg_PopUnder5years_2000_10 Chg_PopUnder18Years_2000_10
      TotPop_&year NumHshlds_&year NumFamilies_&year
      NumFamiliesOwnChildren_&year NumFamiliesOwnChildrenFH_&year
      avgfamilyincome_2000_d09 avgfamilyincome_2005_09 chg_avgfamilyincome_2000_0509
      PopPoorPersons_&year PopPoorChildren_&year PopPoorAdults_&year PopPoorElderly_&year
      PopInCivLaborForce_&year PopCivilianEmployed_&year PopUnemployed_&year
      tanf_client_2010 tanf_unborn_2010 tanf_child_2010 tanf_adult_2010
      fs_client_2010 fs_unborn_2010 fs_child_2010 fs_adult_2010
      births_total_2007 births_teen_2007 births_single_2007 births_prenat_inad_2007
      deaths_total_2007 deaths_violent_2007 deaths_heart_2007
      asst_units_total asst_units_pub_hsng asst_units_s8_only asst_units_s8_plus asst_units_other
      asst_units_vouchers;
  table 
    /** Rows **/
    all='\b Total' geo2000=' ',
    /** Columns **/
    sum='Population' * ( 
      TotPop_2000="2000" 
      TotPop_2010="2010" 
    )
    pctsum<TotPop_2000>=' ' * 
      Chg_TotPop_2000_10='% change' * f=comma10.1
  ;
  table 
    /** Rows **/
    all='\b Total' geo2000=' ',
    /** Columns **/
    sum='Adults' * ( 
      Pop18andOverYears_2000="2000"
      Pop18andOverYears_2010="2010"
    )
    pctsum<TotPop_2000>=' ' * 
      Chg_Pop18andOverYears_2000_10='% change' * f=comma10.1

    sum='Children under\~5' * ( 
      PopUnder5Years_2000="2000"
      PopUnder5Years_2010="2010"
    )
    pctsum<TotPop_2000>=' ' * 
      Chg_PopUnder5Years_2000_10='% change' * f=comma10.1

    sum='Children under\~18' * ( 
      PopUnder18Years_2000="2000"
      PopUnder18Years_2010="2010"
    )
    pctsum<TotPop_2000>=' ' * 
      Chg_PopUnder18Years_2000_10='% change' * f=comma10.1
  ;
  table 
    /** Rows **/
    all='\b Total' geo2000=' ',
    sum=' ' * ( 
      NumHshlds_&year="Households, &year_lbl"
    )
    sum="Families, &year_lbl" * ( 
      NumFamilies_&year="Total"
      NumFamiliesOwnChildren_&year="With children"
      NumFamiliesOwnChildrenFH_&year="Female-headed w/children"
    )
    mean='Avg. family income ($ 2009)' * ( 
      avgfamilyincome_2000_d09 = "2000"
      avgfamilyincome_2005_09 = "&year_lbl"
    )
    pctsum<avgfamilyincome_2000_d09>=' ' * 
      chg_avgfamilyincome_2000_0509='% change' * f=comma10.1
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
    sum="Persons\~in\~civilian\~labor\~force,\~&year_lbl" * ( 
      PopInCivLaborForce_&year="Total"
      PopCivilianEmployed_&year="Employed" 
      PopUnemployed_&year="Unemployed"
    )
  ;
  table 
    /** Rows **/
    all='\b Total' geo2000=' ',
    /** Columns **/
    sum="Persons\~receiving\~TANF,\~2010" * ( 
      tanf_client_2010="Total" 
      tanf_unborn_2010="Unborn children" 
      tanf_child_2010="Children (under\~18)" 
      tanf_adult_2010="Adults (18+)"
    )
    sum="Persons\~receiving\~food\~stamps,\~2010" * ( 
      fs_client_2010="Total" 
      fs_unborn_2010="Unborn children" 
      fs_child_2010="Children (under\~18)" 
      fs_adult_2010="Adults (18+)"
    )
  ;
  table 
    /** Rows **/
    all='\b Total' geo2000=' ',
    /** Columns **/
    sum="Births,\~2007" * ( 
      births_total_2007="Total"
      births_teen_2007="Teenage mothers"
      births_single_2007="Single mothers" 
      births_prenat_inad_2007="Inadequate prenatal care"
    )
  ;
  table 
    /** Rows **/
    all='\b Total' geo2000=' ',
    /** Columns **/
    sum="Deaths,\~2007" * ( 
      deaths_total_2007="Total"
      deaths_violent_2007="From violent causes"
      deaths_heart_2007="From heart disease" 
    )
  ;
  table 
    /** Rows **/
    all='\b Total' geo2000=' ',
    /** Columns **/
    sum="Project-based assisted housing units,\~2007" * ( 
      asst_units_total="Total"
      asst_units_pub_hsng="Public housing" 
      asst_units_s8_only="Section 8 only"
      asst_units_s8_plus="Section 8 + other"
      asst_units_other="All other project-based"
    )
    sum="Housing\~Choice\~Voucher households, 2008" * ( 
      asst_units_vouchers=" "
    )
  ;
  title1 "Data for Census Tracts Within 1/2 Mile of 2933 Stanton Road SE";
  footnote1 height=9pt "Prepared for Horning Family Fund by NeighborhoodInfo DC (www.NeighborhoodInfoDC.org), &fdate..";
  footnote2 height=9pt j=r '{Page}\~{\field{\*\fldinst{\pard\b\i0\chcbpat8\qc\f1\fs19\cf1{PAGE }\cf0\chcbpat0}}}';
run;

ods rtf close;
