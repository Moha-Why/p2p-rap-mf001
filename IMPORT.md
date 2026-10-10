# Import the reviewed purchase-order draft application

Current revision: 006, reviewed 2026-10-11. This replaces the earlier snippets
and prepared ZIPs 001–005. All required edits are already in abapgit/src.
You do not need to apply the earlier currency or behavior patches separately.

## What is ready

Managed draft purchase orders/items, owner-filtered reads and creator-based
writes, defaults, supplier/product choices, Fiori annotations, and an OData V4
service definition. Backend save validations now check required fields, valid
owner-scoped references, date validity, positive quantities/prices, EGP/EA, line
amount capacity, and unique item numbers within one order.

The current service has four entity sets: PurchaseOrders, PurchaseOrderItems,
Suppliers, and Products. Item currency/unit are editable and default to EGP/EA;
other values are rejected on activation. Totals are not exposed until their
calculation is implemented. An empty pending order is allowed; an order must
have valid items before the future ReleaseOrder action can succeed.

There are still 30 development objects (31 XML files including the package).
The src folder now has 56 files, including the new local rule definitions and
ABAP Unit include of the existing behavior class. No table schema changed.
The seed source and repository README are intentional revisions of the original
export; that original ZIP is preserved separately.

## Import this revision

1. Preserve any additional Eclipse edits that are not in our saved source.
   Review abapGit's local changes; Stage and Push the current active package as
   a restore point when appropriate. Save unactivated edits separately because
   an export of active objects does not necessarily preserve those edits.
2. In the linked GitHub repository, choose Add file > Upload files.
3. From C:/Users/Precision/eclipse-workspace/p2p-rebuild/abapgit, upload src,
   third_party, docs, and README.md into the repository root. Keep the folders.
   Commit with a message such as Review and harden PO draft application.
   The existing .abapgit.xml remains unchanged. Do not upload the ZIP as source.
4. In Eclipse's abapGit Repositories view, Pull the linked ZP2P_MF001 repository.
   Review changes/conflicts. This revision updates existing objects and adds
   includes to one existing class; no development object is deliberately deleted.
5. Save and jointly activate the changed objects in ZP2P_MF001. Use package-scoped
   activation (Ctrl+Shift+F3), excluding unrelated student exercises.

Dependency order if needed:

- Application tables, then draft tables and supplier/product CDS.
- Existing interface parent/child CDS and their roles.
- ZI_P2P_PO_MF001 behavior and ZBP_I_P2P_PO_MF001 together, including Local Types
  and Test Classes. The new rule definition include belongs to this same class.
- ZC_P2P_PO_MF001 and ZC_P2P_POIT_MF001 together, then their behavior/roles and
  metadata extensions, then ZUI_P2P_MF001.

The root projection has provider contract transactional_query. Its child inherits
through REDIRECTED TO PARENT and does not repeat the contract. Preserve this.

The reported Inverted Individual primary-key warning still requires inspecting
ADT table technical settings and exporting the resulting SAP metadata. This
revision does not invent serialized index settings to suppress the warning.

## Run the SAP checks

1. Check/activate the package and run the applicable ABAP Cloud/ATC checks.
2. Run As > ABAP Unit Test on ZBP_I_P2P_PO_MF001. There are 13 test methods.
3. Record failures with the object, line, and exact message before proceeding.

The local parser and package checks pass. These are not substitutes for SAP
activation, ABAP Unit, API-release checks, or runtime verification.

## Service binding and preview

If ZUI_P2P_MF001_O4 already exists, reuse it. Otherwise create one Service Binding
in ZP2P_MF001 with that name, service definition ZUI_P2P_MF001, and type
OData V4 - UI. Save/activate it, publish from the binding editor, select
PurchaseOrders, and open Preview. Refresh/reopen the preview after this import
so that it reads the revised service metadata.

The binding is created and published in your SAP system. The assistant has not
published an endpoint. Fiori preview is the current checkpoint; the saved Fiori
application is a later milestone.

## Required runtime gate

1. Open DEMO-PO-001. Released header/item edits and deletion must be rejected.
2. Create PO-TEST-001 using your own supplier DEMO01, today's date, and item
   00010 / PROD01 / quantity 10 / unit price 100. Confirm EGP/EA defaults.
3. Save/reopen, change quantity to 9, and save/reopen again.
4. Change quantity to 8 in a draft, leave/reopen it, then discard. Active quantity
   must remain 9. A discarded new-order draft must leave no active order behind.
5. Try missing required fields, unknown supplier/product IDs, zero/negative
   quantities/prices, USD currency, KG unit, and two items numbered 00010.
   Activation must fail with field-specific messages. Correct the data and verify
   that old errors clear. A second order may reuse item number 00010.
6. Include one good and one bad item: the entire draft activation must fail.
7. Verify direct OData calls enforce the same validation and released-document
   restrictions. Technical UUID/creator/status fields remain backend read-only.
8. With a second SAP user, verify root and child reads hide the first user's
   records; updates, deletes, and item creation against their UUIDs must fail.
9. Verify service metadata contains the four expected entity sets and does not
   expose TotalAmount or NetAmount yet.
10. Run the seed class twice sequentially: the named linked fixture is verified
    and left unchanged. Do not run concurrent bootstrap sessions.

Detailed findings, limitations, and a larger test table are in
REVIEW-20261011.md. No runtime result above is marked passed yet.

After the gate, Stage and Push the activated package including the binding.
Download a new GitHub ZIP and reconcile it as the next verified SAP baseline.

## References

- SAP validations: https://github.com/SAP-samples/abap-platform-rap120/blob/main/exercises/ex04/README.md
- SAP draft preparation: https://help.sap.com/docs/abap-cloud/abap-rap/preparing-draft-instances-for-activation
- Service binding: https://help.sap.com/docs/abap-cloud/abap-development-tools-user-guide/using-service-binding-editor-for-odata-v4-service?locale=en-US
