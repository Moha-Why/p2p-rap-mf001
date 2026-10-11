# P2P application on SAP BTP ABAP Environment

Custom purchase order → goods receipt → supplier invoice application using RAP
and Fiori. Package: ZP2P_MF001. This repository is the backend source backup.

Current revision: 011 (2026-10-11). Revision 010 was activated, tested, and
the generated Fiori elements app (List Report, OData V4) runs in SAP Business
Application Studio. Revision 011 removes the ABAP contract check warnings
"UNPRIVILEGED SELECT" in ZI_P2P_PO_MF001; its SAP activation is pending (see
docs/IMPORT.md).

Read [import and test instructions](docs/IMPORT.md) and the
[review record](docs/REVIEW-20261011.md) before importing.

Receipt/invoice behavior, matching, manual payment tracking,
reporting, and a saved Fiori frontend remain later milestones. Current OData
entity sets: PurchaseOrders, PurchaseOrderItems, Suppliers, Products,
OrderStatuses.

Use abapGit PREFIX folder logic with /src/ as the starting folder. Keep local
source and exports outside the SAP trial. No credentials belong in this repository.
SAP sample metadata attribution is under third_party/sap-rap100.
