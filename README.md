# P2P application on SAP BTP ABAP Environment

Custom purchase order → goods receipt → supplier invoice application using RAP
and Fiori. Package: ZP2P_MF001. This repository is the backend source backup.

Current revision: 007 (2026-10-11). Revision 006 was activated and tested in
SAP. Purchase-order drafts, owner access, reference selections, and backend
validations are implemented. Revision 007 adds unique order references,
ownership-only authorization, and CDS-based reference checks; its SAP
activation and ABAP Unit run are pending (see docs/IMPORT.md).

Read [import and test instructions](docs/IMPORT.md) and the
[review record](docs/REVIEW-20261011.md) before importing.

Totals/release, receipt/invoice behavior, matching, manual payment tracking,
reporting, and a saved Fiori frontend remain later milestones. Current OData
entity sets: PurchaseOrders, PurchaseOrderItems, Suppliers, Products.

Use abapGit PREFIX folder logic with /src/ as the starting folder. Keep local
source and exports outside the SAP trial. No credentials belong in this repository.
SAP sample metadata attribution is under third_party/sap-rap100.
