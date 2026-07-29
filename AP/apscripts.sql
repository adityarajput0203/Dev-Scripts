/*
  Purpose     : Get invoice header details with true approval and payment status
  Module      : AP
  Tables Used : AP_INVOICES_ALL
  Parameters  : &p_invoice_num
  Notes       : Uses AP_INVOICES_PKG.GET_APPROVAL_STATUS - same logic the Invoice Workbench uses
*/
SELECT ai.invoice_id,
       ai.invoice_num,
       ai.invoice_date,
       ai.invoice_amount,
       ai.amount_paid,
       ai.invoice_type_lookup_code,
       DECODE(ai.payment_status_flag,'Y','Fully Paid','N','Unpaid','P','Partially Paid',ai.payment_status_flag) payment_status,
       AP_INVOICES_PKG.GET_APPROVAL_STATUS(ai.invoice_id, ai.invoice_amount, ai.payment_status_flag, ai.invoice_type_lookup_code) approval_status
FROM   ap_invoices_all ai
WHERE  ai.invoice_num = '&p_invoice_num';


/*
  Purpose     : List active (unreleased) holds on an invoice
  Module      : AP
  Tables Used : AP_HOLDS_ALL, AP_INVOICES_ALL
  Parameters  : &p_invoice_num
  Notes       : RELEASE_LOOKUP_CODE IS NULL = hold still active
*/
SELECT ai.invoice_num,
       ah.hold_lookup_code,
       ah.hold_reason,
       ah.held_by,
       ah.creation_date  hold_date
FROM   ap_holds_all ah,
       ap_invoices_all ai
WHERE  ah.invoice_id = ai.invoice_id
AND    ai.invoice_num = '&p_invoice_num'
AND    ah.release_lookup_code IS NULL;


/*
  Purpose     : Show check/payment details for a given invoice
  Module      : AP
  Tables Used : AP_INVOICE_PAYMENTS_ALL, AP_CHECKS_ALL, AP_INVOICES_ALL
  Parameters  : &p_invoice_num
*/
SELECT ai.invoice_num,
       ac.check_number,
       ac.check_date,
       ac.status_lookup_code  payment_status,
       aip.amount             amount_applied
FROM   ap_invoice_payments_all aip,
       ap_checks_all           ac,
       ap_invoices_all         ai
WHERE  aip.check_id   = ac.check_id
AND    aip.invoice_id = ai.invoice_id
AND    ai.invoice_num = '&p_invoice_num';


/*
  Purpose     : Find supplier and site details (address, sites enabled for pay/purchasing)
  Module      : AP
  Tables Used : AP_SUPPLIERS, AP_SUPPLIER_SITES_ALL
  Parameters  : &p_vendor_name (partial match)
  Notes       : AP_SUPPLIERS is a view over the TCA (POZ_SUPPLIERS) model in R12 - still the standard query point
*/
SELECT asup.vendor_id,
       asup.segment1        supplier_number,
       asup.vendor_name,
       asup.enabled_flag,
       ass.vendor_site_id,
       ass.vendor_site_code,
       ass.address_line1,
       ass.city,
       ass.pay_site_flag,
       ass.purchasing_site_flag
FROM   ap_suppliers asup,
       ap_supplier_sites_all ass
WHERE  asup.vendor_id = ass.vendor_id
AND    UPPER(asup.vendor_name) LIKE UPPER('%&p_vendor_name%');


/*
  Purpose     : List unpaid invoices with days-overdue for a supplier or org
  Module      : AP
  Tables Used : AP_INVOICES_ALL, AP_PAYMENT_SCHEDULES_ALL, AP_SUPPLIERS
  Parameters  : &p_org_id
  Notes       : AP_PAYMENT_SCHEDULES_ALL is the correct source for due dates/remaining amount - not AP_INVOICES_ALL directly
*/
SELECT asup.vendor_name,
       ai.invoice_num,
       ai.invoice_date,
       aps.due_date,
       aps.amount_remaining,
       TRUNC(SYSDATE) - aps.due_date  days_overdue
FROM   ap_invoices_all ai,
       ap_payment_schedules_all aps,
       ap_suppliers asup
WHERE  ai.invoice_id = aps.invoice_id
AND    ai.vendor_id  = asup.vendor_id
AND    aps.amount_remaining > 0
AND    ai.org_id = &p_org_id
ORDER  BY days_overdue DESC;