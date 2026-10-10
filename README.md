# P2P application on SAP BTP ABAP Environment

Custom purchase order → goods receipt → supplier invoice application using RAP
and Fiori. Package: ZP2P_MF001. This repository is the backend source backup.

Current prepared revision: 006 (reviewed 2026-10-11). Purchase-order drafts,
owner access, reference selections, and basic backend validations are implemented
in source. Local parser/structural checks pass. SAP activation, ABAP Unit, and
runtime checks for this revision are still pending.

Read [import and test instructions](docs/IMPORT.md) and the
[review record](docs/REVIEW-20261011.md) before importing.

Totals/release, receipt/invoice behavior, matching, manual payment tracking,
reporting, and a saved Fiori frontend remain later milestones. Current OData
entity sets: PurchaseOrders, PurchaseOrderItems, Suppliers, Products.

Use abapGit PREFIX folder logic with /src/ as the starting folder. Keep local
source and exports outside the SAP trial. No credentials belong in this repository.
SAP sample metadata attribution is under third_party/sap-rap100.
