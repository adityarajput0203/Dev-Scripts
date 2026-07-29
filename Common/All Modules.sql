/*
  ================================================================================
  Batch: SYSADMIN / Concurrent Manager / Profile / Form Personalization queries
  Most entries are SYSADMIN; a couple are tagged AR/OM and INV individually below.
  ================================================================================
*/

/*
  Purpose     : Find which responsibility(ies) a concurrent program is attached to,
                via its request group
  Module      : SYSADMIN
  Tables Used : FND_REQUEST_GROUPS, FND_APPLICATION_TL, FND_REQUEST_GROUP_UNITS,
                FND_CONCURRENT_PROGRAMS, FND_CONCURRENT_PROGRAMS_TL,
                FND_RESPONSIBILITY, FND_RESPONSIBILITY_TL, FND_EXECUTABLES
  Parameters  : fcpl.user_concurrent_program_name (LIKE filter, currently
                'Min-max planning report')
  Notes       : Returns one row per responsibility if the program is attached to
                more than one request group/responsibility
*/
SELECT DISTINCT fcpl.user_concurrent_program_name,
                fcp.concurrent_program_name,
                fapp.application_name,
                frg.request_group_name,
                fnrtl.responsibility_name,
                fe.execution_file_name
  FROM apps.fnd_request_groups frg,
       apps.fnd_application_tl fapp,
       apps.fnd_request_group_units frgu,
       apps.fnd_concurrent_programs fcp,
       apps.fnd_concurrent_programs_tl fcpl,
       apps.fnd_responsibility fnr,
       apps.fnd_responsibility_tl fnrtl,
       apps.fnd_executables fe
WHERE  1 = 1
	   AND frg.application_id = fapp.application_id
       AND frg.application_id = frgu.application_id
       AND frg.request_group_id = frgu.request_group_id
       AND frg.request_group_id = fnr.request_group_id
       AND fnr.responsibility_id = fnrtl.responsibility_id
       AND frgu.request_unit_id = fcp.concurrent_program_id
       AND frgu.unit_application_id = fcp.application_id
       AND fcp.concurrent_program_id = fcpl.concurrent_program_id
       AND fe.executable_id = fcp.executable_id
       AND fcpl.user_concurrent_program_name LIKE 'Min-max planning report'
;


/*
  Purpose     : Show status/timing of previous runs for a concurrent program,
                searched by (partial) program name
  Module      : SYSADMIN
  Tables Used : FND_CONCURRENT_REQUESTS, FND_CONCURRENT_PROGRAMS,
                FND_CONCURRENT_PROGRAMS_TL, FND_USER, FND_CONC_REQ_SUMMARY_V
  Parameters  : :USER_CONCURRENT_PROGRAM_NAME
  Notes       : PHASE_CODE and STATUS_CODE are decoded inline for readability;
                uncomment the actual_start_date filter to restrict to recent days
*/
SELECT distinct ft.user_concurrent_program_name "Conc Program Name",
fr.REQUEST_ID "Request ID",
to_char(fr.ACTUAL_START_DATE,'dd-MON-yy hh24:mi:ss') "Started at",
to_char(fr.ACTUAL_COMPLETION_DATE,'dd-MON-yy hh24:mi:ss') "Completed at",
decode(fr.PHASE_CODE,'C','Completed','I','Inactive','P','Pending','R','Running','NA') "Phasecode",
decode(fr.STATUS_CODE, 'A','Waiting', 'B','Resuming', 'C','Normal', 'D','Cancelled', 'E','Error', 'F','Scheduled', 'G','Warning', 'H','On Hold', 'I','Normal', 'M',
'No Manager', 'Q','Standby', 'R','Normal', 'S','Suspended', 'T','Terminating', 'U','Disabled', 'W','Paused', 'X','Terminated', 'Z','Waiting') "Status",fr.argument_text "Parameters",
fu.user_name "Username",
round(((nvl(fv.actual_completion_date,sysdate)-fv.actual_start_date)*24*60),2) "ElapsedTime(Mins)"
FROM
apps.fnd_concurrent_requests fr ,
apps.fnd_concurrent_programs fp ,
apps.fnd_concurrent_programs_tl ft,
apps.fnd_user fu, apps.fnd_conc_req_summary_v fv
WHERE 
fr.CONCURRENT_PROGRAM_ID = fp.CONCURRENT_PROGRAM_ID
--AND fr.actual_start_date >= (sysdate - :NUMBER_OF_DAYS)
AND   fr.PROGRAM_APPLICATION_ID = fp.APPLICATION_ID
AND ft.concurrent_program_id=fr.concurrent_program_id
AND fr.REQUESTED_BY=fu.user_id
AND fv.request_id=fr.request_id
and ft.user_concurrent_program_name like '%'||:USER_CONCURRENT_PROGRAM_NAME||'%'
order by to_char(fr.ACTUAL_COMPLETION_DATE,'dd-MON-yy hh24:mi:ss') desc
;


/*
  Purpose     : Get technical details of a concurrent program (executable name,
                execution method, application top, parameter list) by name
  Module      : SYSADMIN
  Tables Used : FND_CONCURRENT_PROGRAMS, FND_CONCURRENT_PROGRAMS_TL,
                FND_EXECUTABLES, FND_EXECUTABLES_TL, FND_APPLICATION,
                FND_DESCR_FLEX_COL_USAGE_VL
  Parameters  : fcpt.user_concurrent_program_name IN-list (currently one program)
  Notes       : parameter_list uses LISTAGG against the $SRS$ descriptive flexfield
                to show all defined parameters for the program in one column
*/
SELECT fcp.concurrent_program_id,
       fcp.concurrent_program_name,
       fcpt.user_concurrent_program_name,
       fcpt.description,
       fe.executable_name,
       fet.user_executable_name,
       fe.execution_file_name,
       fe.execution_method_code,
       fp.application_short_name,
       fp.basepath application_top,
       (
           SELECT LISTAGG(par.end_user_column_name, ', ')
                    WITHIN GROUP (ORDER BY par.column_seq_num)
             FROM apps.fnd_descr_flex_col_usage_vl par
            WHERE par.descriptive_flexfield_name =
                     '$SRS$.' || fcp.concurrent_program_name
       ) parameter_list
  FROM apps.fnd_concurrent_programs    fcp,
       apps.fnd_concurrent_programs_tl fcpt,
       apps.fnd_executables            fe,
       apps.fnd_executables_tl         fet,
       apps.fnd_application            fp
 WHERE fp.application_id = fe.application_id
   AND fe.executable_id = fet.executable_id
   AND fcp.concurrent_program_id = fcpt.concurrent_program_id
   AND fcpt.language = fet.language
   AND fcp.executable_id = fe.executable_id
   AND fcp.executable_application_id = fe.application_id
   AND fcpt.language = 'US'
  AND fcpt.user_concurrent_program_name IN (
       'Koel GST STD Invoice Printing for Engines-XML'
      )
;


/*
  Purpose     : List pending/scheduled concurrent requests along with their
                repeat pattern (interval, days-of-week) and requestor details
  Module      : SYSADMIN
  Tables Used : FND_CONCURRENT_REQUESTS, FND_USER, FND_CONCURRENT_PROGRAMS,
                FND_CONCURRENT_PROGRAMS_TL, FND_PRINTER_STYLES_TL,
                FND_CONC_RELEASE_CLASSES, FND_RESPONSIBILITY_TL, FND_LOOKUPS
  Parameters  : none (filters PHASE_CODE = 'P' i.e. Pending)
  Notes       : the CLASS_INFO substrings decode the release-class repeat
                interval and days-of-week bitmask for periodic/scheduled requests
*/
SELECT 
	fcr.request_id ,
	fcpt.user_concurrent_program_name
	|| NVL2(fcr.description, ' ('
	|| fcr.description
	|| ')', NULL) conc_prog ,
	fu.user_name requestor ,
	fu.description requested_by ,
	fu.email_address ,
	frt.responsibility_name requested_by_resp ,
	TRIM(fl.meaning) STATUS ,
	fcr.phase_code ,
	fcr.status_code ,
	fcr.argument_text "PARAMETERS" ,
	TO_CHAR(fcr.request_date, 'DD-MON-YYYY HH24:MI:SS') requested ,
	TO_CHAR(fcr.requested_start_date, 'DD-MON-YYYY HH24:MI:SS') requested_start ,
	TO_CHAR((fcr.requested_start_date), 'HH24:MI:SS') start_time ,
	DECODE(fcr.hold_flag, 'Y', 'Yes', 'N', 'No') on_hold ,
	CASE
	WHEN fcr.hold_flag = 'Y'
	THEN SUBSTR( fu.description , 0 , 40 )
	END last_update_by ,
	CASE
	WHEN fcr.hold_flag = 'Y'
	THEN fcr.last_update_date
	END last_update_date ,
	fcr.increment_dates ,
	CASE
	WHEN fcrc.CLASS_INFO IS NULL
	THEN 'Yes: '
		|| TO_CHAR(fcr.requested_start_date, 'DD-MON-YYYY HH24:MI:SS')
	ELSE 'n/a'
	END run_once ,
	CASE
	WHEN fcrc.class_type = 'P'
	THEN 'Repeat every '
		|| SUBSTR(fcrc.class_info, 1, instr(fcrc.class_info, ':')           - 1)
		|| DECODE(SUBSTR(fcrc.class_info, instr(fcrc.class_info, ':', 1, 1) + 1, 1), 'N', ' minutes', 'M', ' months', 'H', ' hours', 'D', ' days')
		|| DECODE(SUBSTR(fcrc.class_info, instr(fcrc.class_info, ':', 1, 2) + 1, 1), 'S', ' from the start of the prior run', 'C', ' from the completion of the prior run')
	ELSE 'n/a'
	END set_days_of_week ,
	CASE
	WHEN fcrc.class_type                         = 'S'
	AND instr(SUBSTR(fcrc.class_info, 33),'1',1) > 0
	THEN 'Days of week: '
		|| DECODE(SUBSTR(fcrc.class_info, 33, 1), '1', 'Sun, ')
		|| DECODE(SUBSTR(fcrc.class_info, 34, 1), '1', 'Mon, ')
		|| DECODE(SUBSTR(fcrc.class_info, 35, 1), '1', 'Tue, ')
		|| DECODE(SUBSTR(fcrc.class_info, 36, 1), '1', 'Wed, ')
		|| DECODE(SUBSTR(fcrc.class_info, 37, 1), '1', 'Thu, ')
		|| DECODE(SUBSTR(fcrc.class_info, 38, 1), '1', 'Fri, ')
		|| DECODE(SUBSTR(fcrc.class_info, 39, 1), '1', 'Sat ')
	ELSE 'n/a'
	END days_of_week
FROM apps.fnd_concurrent_requests fcr ,
	apps.fnd_user fu ,
	apps.fnd_concurrent_programs fcp ,
	apps.fnd_concurrent_programs_tl fcpt ,
	apps.fnd_printer_styles_tl fpst ,
	apps.fnd_conc_release_classes fcrc ,
	apps.fnd_responsibility_tl frt ,
	apps.fnd_lookups fl
WHERE 1 = 1
	AND fcp.application_id       = fcpt.application_id
	AND fcr.requested_by           = fu.user_id
	AND fcr.concurrent_program_id  = fcp.concurrent_program_id
	AND fcr.program_application_id = fcp.application_id
	AND fcr.concurrent_program_id  = fcpt.concurrent_program_id
	AND fcr.responsibility_id      = frt.responsibility_id
	AND fcr.print_style            = fpst.printer_style_name(+)
	AND fcr.release_class_id       = fcrc.release_class_id(+)
	AND fcr.status_code            = fl.lookup_code
	AND fl.lookup_type             = 'CP_STATUS_CODE'
	AND fcr.phase_code             = 'P'
	AND frt.language               = 'US'
	AND fpst.language              = 'US'
	AND fcpt.language              = 'US'
ORDER BY Fu.Description,
	Fcr.Requested_Start_Date ASC
;


/*
  Purpose     : List scheduled/pending Request Sets (FNDRSSUB wrapper program)
  Module      : SYSADMIN
  Tables Used : FND_CONCURRENT_REQUESTS, FND_USER, FND_RESPONSIBILITY_TL,
                FND_CONCURRENT_PROGRAMS
  Parameters  : none
  Notes       : filters concurrent_program_name = 'FNDRSSUB', the standard
                internal program that drives Request Sets
*/
SELECT
    r.request_id,
    r.description request_set_name,
    u.user_name,
    frt.responsibility_name,
    r.request_date,
    r.requested_start_date,
    r.resubmit_interval,
    r.resubmit_interval_unit_code,
    r.hold_flag,
    r.phase_code,
    r.status_code
FROM apps.fnd_concurrent_requests r
JOIN apps.fnd_user u
     ON r.requested_by = u.user_id
JOIN apps.fnd_responsibility_tl frt
     ON r.responsibility_id = frt.responsibility_id
JOIN apps.fnd_concurrent_programs cp
     ON r.concurrent_program_id = cp.concurrent_program_id
    AND r.program_application_id = cp.application_id
WHERE cp.concurrent_program_name = 'FNDRSSUB'   -- Request Set program
AND r.phase_code = 'P'                          -- Pending (Scheduled)
ORDER BY r.requested_start_date
;


/*
  Purpose     : Get the request group name attached to a given responsibility
  Module      : SYSADMIN
  Tables Used : FND_REQUEST_GROUPS, FND_RESPONSIBILITY_VL
  Parameters  : responsibility_name filter (currently 'Benefits Administrator')
  Notes       : n/a
*/
SELECT responsibility_name ,
  request_group_name        ,
  frg.description
   FROM fnd_request_groups frg,
  fnd_responsibility_vl frv
  WHERE frv.request_group_id = frg.request_group_id
  --AND request_group_name LIKE 'US SHRMS Reports % Processes'
AND responsibility_name LIKE 'Benefits Administrator'
ORDER BY responsibility_name;


/*
  Purpose     : List all parameters (and their value sets) defined on a
                concurrent program
  Module      : SYSADMIN
  Tables Used : FND_CONCURRENT_PROGRAMS, FND_CONCURRENT_PROGRAMS_TL,
                FND_DESCR_FLEX_COL_USAGE_VL, FND_FLEX_VALUE_SETS,
                FND_LOOKUP_VALUES
  Parameters  : :CONCURRENT_NAME
  Notes       : n/a
*/
SELECT
    fcpl.user_concurrent_program_name "Concurrent Program Name",
    fcp.concurrent_program_name "Short Name",
    fdfcuv.end_user_column_name "Parameter Name",
    fdfcuv.form_left_prompt "Prompt",
    fdfcuv.enabled_flag "Enabled Flag",
    fdfcuv.required_flag "Required Flag",
    fdfcuv.display_flag "Display Flag",
    fdfcuv.flex_value_set_id "Value Set Id",
    ffvs.flex_value_set_name "Value Set Name",
    flv.meaning "Default Type",
    fdfcuv.DEFAULT_VALUE "Default Value"
FROM
    fnd_concurrent_programs fcp,
    fnd_concurrent_programs_tl fcpl,
    fnd_descr_flex_col_usage_vl fdfcuv,
    fnd_flex_value_sets ffvs,
    fnd_lookup_values flv
WHERE
    fcp.concurrent_program_id = fcpl.concurrent_program_id
    AND fcpl.user_concurrent_program_name = :CONCURRENT_NAME
    AND fdfcuv.descriptive_flexfield_name = '$SRS$.'
    || fcp.concurrent_program_name
    AND ffvs.flex_value_set_id = fdfcuv.flex_value_set_id
    AND flv.lookup_type(+) = 'FLEX_DEFAULT_TYPE'
    AND flv.lookup_code(+) = fdfcuv.default_type
    AND fcpl.LANGUAGE = USERENV('LANG')
    AND flv.LANGUAGE(+) = USERENV('LANG')
ORDER BY
    fdfcuv.column_seq_num
;


/*
  Purpose     : Get the salesperson name linked to an AR invoice, via the
                originating Order Management sales order
  Module      : AR / OM
  Tables Used : RA_SALESREPS_ALL, OE_ORDER_HEADERS_ALL, RA_CUSTOMER_TRX_ALL
  Parameters  : add a WHERE filter on rct.customer_trx_id / rct.trx_number
                for a specific invoice
  Notes       : relies on the invoice being AutoInvoice-created from Order
                Management (INTERFACE_HEADER_CONTEXT = 'ORDER ENTRY',
                CREATED_FROM = 'RAXTRX'); won't return a row for manually
                entered AR invoices with no originating sales order
*/
select NAME from ra_salesreps_all WHERE SALESREP_ID=(
select oeh.SALESREP_ID
from oe_order_headers_all oeh,ra_customer_trx_all rct
where 1=1
and order_number = rct.interface_header_attribute1
and rct.INTERFACE_HEADER_CONTEXT  =  'ORDER ENTRY'
      AND rct.created_from = 'RAXTRX'
       )
;


/*
  Purpose     : Get the Forms (.fmb) file name behind a responsibility's
                menu/function
  Module      : SYSADMIN
  Tables Used : FND_RESPONSIBILITY, FND_RESPONSIBILITY_TL, FND_MENUS,
                FND_MENU_ENTRIES, FND_FORM_FUNCTIONS, FND_FORM
  Parameters  : responsibility_name filter
  Notes       : returns one row per function/form on the responsibility's menu
                tree, not just the top-level form
*/
SELECT frt.responsibility_name,
       --.prompt AS menu_prompt,
       ffu.function_name,
       ff.form_name AS fmb_file_name
       --ff.user_form_name
FROM fnd_responsibility fr
JOIN fnd_responsibility_tl frt ON fr.responsibility_id = frt.responsibility_id
JOIN fnd_menus fm ON fr.menu_id = fm.menu_id
JOIN fnd_menu_entries fme ON fm.menu_id = fme.menu_id
JOIN fnd_form_functions ffu ON fme.function_id = ffu.function_id
JOIN fnd_form ff ON ffu.form_id = ff.form_id
WHERE frt.responsibility_name = 'KOEL Pre-Quote Approval Superuser'
;


/*
  Purpose     : Find users and their currently active responsibilities,
                filtered by responsibility name
  Module      : SYSADMIN
  Tables Used : FND_USER_RESP_GROUPS_DIRECT, FND_USER, FND_RESPONSIBILITY_TL
  Parameters  : fr.responsibility_name (LIKE filter, currently 'LGM%')
  Notes       : END_DATE IS NULL restricts results to currently active
                responsibility assignments only
*/
select fu.user_name, fu.description,fr.responsibility_name, furg.START_DATE, furg.END_DATE
from fnd_user_resp_groups_direct furg, fnd_user fu, fnd_responsibility_tl fr
where furg.user_id = fu.user_id 
and furg.responsibility_id = fr.responsibility_id and fr.language = userenv('LANG')
and furg.end_date is null and fr.responsibility_name like 'LGM%';
 

/*
  Purpose     : List every profile option value assigned to a specific user,
                at any level (Site/Application/Responsibility/User/Server/Org)
  Module      : SYSADMIN
  Tables Used : FND_PROFILE_OPTION_VALUES, FND_PROFILE_OPTIONS,
                FND_PROFILE_OPTIONS_TL, FND_APPLICATION_TL, FND_USER,
                FND_RESPONSIBILITY_TL, FND_NODES, HR_ALL_ORGANIZATION_UNITS
  Parameters  : d.user_name (currently 'IS407703')
  Notes       : LEVEL_ID decode - 10001 Site, 10002 Application,
                10003 Responsibility, 10004 User, 10005 Server, 10006 Org.
                Uncomment the USER_PROFILE_OPTION_NAME filter to narrow to one
                specific profile option
*/
SELECT DISTINCT POT.PROFILE_OPTION_NAME "PROFILE_CODE" 
  , POT.USER_PROFILE_OPTION_NAME "PROFILE_NAME" 
       , DECODE (a.profile_option_value
             , '1', '1 (may be "Yes")'
             , '2', '2 (may be "No")'
             , a.profile_option_value
              ) "PF_VALUE"
     , DECODE (a.level_id
             , 10001, 'Site'
             , 10002, 'Application'
             , 10003, 'Responsibility'
             , 10004, 'User'
             , 10005, 'Server'
             , 10006, 'Organization'
             , a.level_id
              ) "LEVEL_IDENTIFIER"
     , DECODE (a.level_id
             , 10002, e.application_name
             , 10003, c.responsibility_name
             , 10004, D.USER_NAME
             , 10005, F.HOST || '.' || F.DOMAIN
             , 10006, g.name
             , '-'
              ) "LEVEL_NAME"
FROM fnd_application_tl e ,
  fnd_user d ,
  fnd_responsibility_tl c ,
  fnd_profile_option_values a ,
  fnd_profile_options b ,
  fnd_profile_options_tl pot ,
  fnd_nodes f ,
  hr_all_organization_units g
WHERE 1=1
and d.user_name='IS407703'
AND a.level_id='10004'
--AND UPPER(pot.USER_PROFILE_OPTION_NAME) LIKE UPPER('MO: Default Operating Unit')
AND pot.profile_option_name = b.profile_option_name
AND b.application_id        = a.application_id(+)
AND b.profile_option_id     = a.profile_option_id(+)
AND a.level_value           = c.responsibility_id(+)
AND a.level_value           = d.user_id(+)
AND a.level_value           = e.application_id(+)
AND a.level_value           = f.node_id(+)
AND a.level_value           = g.organization_id(+)
AND pot.language            ='US'
ORDER BY PROFILE_NAME ,
  LEVEL_IDENTIFIER ,
  LEVEL_NAME ,
  PF_VALUE
;


/*
  Purpose     : Check a specific profile option's value(s) set at the
                Responsibility level for a given responsibility
  Module      : SYSADMIN
  Tables Used : FND_PROFILE_OPTIONS, FND_PROFILE_OPTIONS_VL,
                FND_PROFILE_OPTION_VALUES, FND_USER, FND_RESPONSIBILITY_VL,
                FND_APPLICATION
  Parameters  : g.responsibility_name filter
  Notes       : LEVEL_ID = 10003 restricts results to Responsibility-level
                profile values only (not Site/App/User)
*/
SELECT g.responsibility_id,b.user_profile_option_name "Long Name" ,
  a.profile_option_name "Short Name" ,
  NVL(g.responsibility_name,c.level_value)  "Level Value" ,
  c.PROFILE_OPTION_VALUE "Profile Value",
  b.sql_validation
FROM apps.fnd_profile_options a ,
  apps.FND_PROFILE_OPTIONS_VL b ,
  apps.FND_PROFILE_OPTION_VALUES c ,
  apps.FND_USER d ,
  apps.FND_USER e ,
  apps.FND_RESPONSIBILITY_VL g ,
  apps.FND_APPLICATION h
WHERE 1                   =1
AND a.profile_option_name = b.profile_option_name
AND a.profile_option_id   = c.profile_option_id
AND a.application_id      = c.application_id
AND c.last_updated_by     = d.user_id (+)
AND c.level_value         = e.user_id (+)
AND c.level_value         = g.responsibility_id (+)
AND c.level_value         = h.application_id (+)
  --
AND c.level_id            = 10003
AND UPPER(g.responsibility_name) like UPPER('SSOB-India Local Inventory Superuser')
--and g.responsibility_name  like '%PCP3%'
ORDER BY b.user_profile_option_name,  c.level_id
;


/*
  Purpose     : Get all currently active responsibilities attached to a user,
                with each responsibility's own effective date range
  Module      : SYSADMIN
  Tables Used : FND_USER, FND_USER_RESP_GROUPS_DIRECT, FND_RESPONSIBILITY_VL
  Parameters  : add a WHERE on fu.user_name for a specific user
  Notes       : date-range checks treat NULL start/end dates as "always active"
*/
SELECT
fu.user_name,
fu.user_id,
fu.start_date AS user_start_date,
fu.end_date AS user_end_date,
frv.responsibility_name,
furg.start_date AS responsibility_start_date,
furg.end_date AS responsibility_end_date
FROM
fnd_user fu
JOIN
fnd_user_resp_groups_direct furg
ON fu.user_id = furg.user_id
JOIN
fnd_responsibility_vl frv
ON furg.responsibility_id = frv.responsibility_id
WHERE
SYSDATE BETWEEN NVL(fu.start_date, SYSDATE) AND NVL(fu.end_date, SYSDATE + 1)
AND SYSDATE BETWEEN NVL(furg.start_date, SYSDATE) AND NVL(furg.end_date, SYSDATE + 1)
AND SYSDATE BETWEEN NVL(frv.start_date, SYSDATE) AND NVL(frv.end_date, SYSDATE + 1)
ORDER BY
fu.user_name;


/*
  Purpose     : Find the filesystem path (reports/US) and execution file name
                for a report executable, by execution file name
  Module      : SYSADMIN
  Tables Used : FND_EXECUTABLES_VL, FND_APPLICATION_VL
  Parameters  : EXECUTION_FILE_NAME (LIKE filter, currently '%KEXOASC%')
  Notes       : EXECUTION_METHOD_CODE filter is set to 'P' here to match this
                specific executable's type - confirm/adjust the code if
                reusing this for a different executable
*/
SELECT APPLICATION_NAME,
       '$' || BASEPATH || '/' || 'reports/US' Reports_Path,
       EXECUTION_FILE_NAME
  FROM APPS.FND_EXECUTABLES_VL A, APPS.FND_APPLICATION_VL B
 WHERE     EXECUTION_METHOD_CODE = 'P'
       AND A.APPLICATION_ID = B.APPLICATION_ID
       AND EXECUTION_FILE_NAME LIKE '%KEXOASC%'
;


/*
  Purpose     : Check Oracle Network ACL entries and privileges configured in
                the database (relevant when EBS/PLSQL calls out via UTL_HTTP,
                UTL_SMTP, UTL_TCP etc.)
  Module      : SYSADMIN / DBA
  Tables Used : DBA_NETWORK_ACLS, DBA_NETWORK_ACL_PRIVILEGES
  Parameters  : none
  Notes       : requires DBA-level privileges to query these dictionary views
*/
SELECT * FROM DBA_NETWORK_ACLS;
SELECT * FROM DBA_NETWORK_ACL_PRIVILEGES;


/*
  Purpose     : Get on-hand quantity for an item in a specific subinventory
                within an organization
  Module      : INV
  Tables Used : MTL_ONHAND_QUANTITIES, MTL_SYSTEM_ITEMS_KFV
  Parameters  : organization_id, subinventory_code, inventory_item_id are
                hardcoded below - parameterize with bind variables as needed
  Notes       : n/a
*/
SELECT msik.concatenated_segments, moq.transaction_quantity, moq.organization_id, moq.subinventory_code
FROM mtl_onhand_quantities moq, mtl_system_items_kfv msik
where moq.organization_id = 2966
and msik.inventory_item_id = moq.inventory_item_id
and moq.organization_id = msik.organization_id
and subinventory_code = '71IIBIN00'
and msik.inventory_item_id = 5
--and msik.concatenated_segments = ''
;


/*
  Purpose     : List Form Personalization rules/actions defined on a given
                form, optionally filtered by target object or property value
  Module      : SYSADMIN / FORM_PERSONALIZATION
  Tables Used : FND_FORM_VL, FND_FORM_CUSTOM_RULES, FND_FORM_CUSTOM_ACTIONS
  Parameters  : ffv.form_name (currently 'RCVTXERT'); target_object /
                property_value filter (currently '%DISPLAY5%')
  Notes       : ENABLED = 'Y' restricts results to currently active rules only
*/
  SELECT ffv.form_id,
         ffv.form_name,
         ffv.user_form_name,
         ffv.description      "Form Description",
         ffcr.sequence,
         ffcr.description     "Personalization Rule Name",
         ffca.*
    FROM fnd_form_vl            ffv,
         fnd_form_custom_rules  ffcr,
         fnd_form_custom_actions ffca
   WHERE     ffv.form_name = ffcr.form_name
         AND ffv.form_name = 'RCVTXERT'
         AND ffcr.ID = ffca.rule_id
         AND (   target_object LIKE '%DISPLAY5%'
              OR UPPER (property_value) LIKE UPPER ('%DISPLAY5%'))
         --    and UPPER(property_value) like UPPER('%DISPLAY%')

         AND ffca.enabled = 'Y'
ORDER BY ffv.form_name, ffcr.sequence
;