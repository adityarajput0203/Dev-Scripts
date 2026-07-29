# Oracle EBS Query Repository

A curated collection of commonly used SQL/PLSQL queries for Oracle E-Business Suite (R12), covering day-to-day diagnostics, functional research, and technical troubleshooting across modules.

---

## 📋 About

This repository is a personal/team reference of reusable Oracle EBS queries — the kind you end up rewriting from scratch every few months if they're not saved somewhere. Each query is documented with its purpose, the tables/columns involved, and any assumptions or version-specific notes.

**Target environment:** Oracle EBS R12.x
**Tested against:** *(update with your version, e.g. 12.2.9)*

---

## 🗂️ Repository Structure

Queries are organized by module. Update this list to match your actual folder structure.

```
├── AP/                 # Payables — invoices, payments, holds
├── AR/                 # Receivables — invoices, receipts, aging
├── GL/                 # General Ledger — journals, balances, periods
├── FA/                 # Fixed Assets — asset details, depreciation
├── INV/                # Inventory — on-hand, transactions, item setup
├── WIP/                # Work in Process — jobs, move orders, status
├── PO/                 # Purchasing — requisitions, POs, receipts
├── OM/                 # Order Management — sales orders, shipping
├── SYSADMIN/           # Concurrent programs, profiles, users, responsibilities
├── FORM_PERSONALIZATION/  # Reference queries used alongside FP rules
└── MISC/               # Grants, synonyms, AD_ZD / Online Patching helpers
```

---

## 🚀 How to Use

1. Browse to the relevant module folder.
2. Each `.sql` file is self-contained and includes a header comment block (see template below).
3. Replace bind variables (`&param_name` or `:param_name`) with actual values before running.
4. **Always test in a non-production instance first**, especially anything beyond a plain `SELECT`.

### File header template

Every query file follows this format for consistency:

```sql
/*
  Purpose     : <what this query answers, in one line>
  Module      : <e.g. WIP>
  Tables Used : <key tables/views>
  Parameters  : <bind variables expected, if any>
  Notes       : <version caveats, assumptions, known limitations>
  Author      : <name>
  Last Tested : <EBS version / date>
*/

SELECT ...
```

---

## 🔍 Sample Entries

A few examples of the kind of query this repo collects:

| File | Module | Purpose |
|---|---|---|
| `WIP/wip_job_status_lookup.sql` | WIP | Decode `WIP_DISCRETE_JOBS.STATUS_TYPE` to its meaning |
| `WIP/move_order_allocated_not_transacted.sql` | WIP/INV | Find jobs with an allocated but untransacted Move Order |
| `INV/move_order_status_check.sql` | INV | Query `MTL_TXN_REQUEST_HEADERS`/`LINES` status and quantities |
| `MISC/grant_privs_custom_object.sql` | MISC | Standard `AD_ZD.GRANT_PRIVS` pattern for granting custom objects |
| `SYSADMIN/concurrent_request_status.sql` | SYSADMIN | Check status/log of a concurrent request by request ID |

---

## ⚠️ Disclaimer

- These queries are provided as-is, for reference and troubleshooting purposes.
- Read-only (`SELECT`) queries are generally safe to run directly; anything involving `UPDATE`, `DELETE`, or API calls should be reviewed and tested in a sandbox/test instance before use in production.
- Table/column names and status codes can vary slightly across EBS versions and patch levels — verify against your instance (e.g. via `FND_LOOKUP_VALUES`) before relying on hardcoded status codes.
- Not affiliated with or endorsed by Oracle Corporation.

---

## 🤝 Contributing

1. Fork the repo.
2. Add your query under the appropriate module folder, following the header template above.
3. Open a pull request with a short description of what the query does.

---

## 📄 License

*(Add a license — e.g. MIT — if this repo is public.)*
