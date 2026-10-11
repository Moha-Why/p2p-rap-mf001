# Import the reviewed purchase-order draft application

## Revision 010 (current) — status texts, names, Release, live totals

New objects: table ZP2P_STAT_MF001 (status texts) and CDS view
ZI_P2P_POSTAT_MF001 (status text and color). Changed: interface views
ZI_P2P_PO_MF001 and ZI_P2P_POIT_MF001 (new associations to supplier, product,
and status), both projections and metadata extensions, both behavior
definitions, behavior class ZBP_I_P2P_PO_MF001, setup class
ZCL_P2P_SETUP_MF001, and service definition ZUI_P2P_MF001 (new entity set
OrderStatuses). No existing table changes.

- Status shows as text with a color: Pending (orange), Released (green). The
  order list has a Status filter.
- Supplier and product show their names next to their IDs.
- Release button: on the order list (select an order) and in the order page
  header. It works only on saved pending orders with at least one item. A
  released order can no longer be edited or deleted.
- While you edit an item, the net amount and the order total refresh as soon
  as quantity or unit price change (no save needed).
- Choosing a product fills the item description with the product name. You
  can still overwrite the description afterwards.
- ABAP Unit: one test added (22 in total).

Pull, set up, and test:

1. In abapGit, Pull. Activate all inactive objects together (Ctrl+Shift+F3).
   If an object stays inactive, activate it on its own and record the message.
2. Run ZCL_P2P_SETUP_MF001 again (F9). It must print "Order status texts saved
   (2 values)." and "Order number interval 01 already exists."
3. Run As > ABAP Unit Test on ZBP_I_P2P_PO_MF001. All 22 methods must pass.
4. Open the preview from service binding ZUI_P2P_MF001_O4 (refresh the browser
   page if it was already open). The list shows Status as Pending/Released
   with colors, supplier names, and a Status filter.
5. Create an order. Add an item and choose a product: the description fills
   in. Enter quantity and price: Net amount and Order total update without
   saving. Save.
6. With the saved order open (not in edit mode), choose Release. Status
   becomes Released (green); Edit and Delete are no longer available.
7. Create and save an order without items, then choose Release: it fails with
   "Add at least one item before releasing the order."
8. While an order is in edit mode, Release is not available.

Record any failure with the object, line, and exact message.


## Revision 009 — automatic order and item numbers

Activated in SAP on 2026-10-11 and confirmed working. abapGit imported number
range object ZP2P_MF001 inactive; it had to be activated manually before the
setup class could create the interval.

New objects: domain ZP2P_PONR_MF001 (7-digit counter), number range object
ZP2P_MF001, and class ZCL_P2P_SETUP_MF001 (one-time interval setup). Changed:
behavior definition ZI_P2P_PO_MF001, behavior class ZBP_I_P2P_PO_MF001, and
metadata extension ZC_P2P_PO_MF001 (label "Order number"). No table changes.

- A new order gets its number as soon as it is created: PO- plus a 7-digit
  counter, for example PO-0000001. The field is read-only.
- Numbers are drawn when the draft is created, as in SAP's own RAP samples.
  A discarded draft leaves a gap in the sequence. That is normal; SAP's
  standard purchase order numbers have gaps too.
- A new item gets the next item number (highest in the order + 10). You can
  still overwrite it; duplicates are still rejected.
- Existing orders keep their current references (PO-TEST-001, DEMO-PO-001).
- ABAP Unit: two tests added (21 in total).

Pull, set up, and test:

1. In abapGit, Pull. It creates the domain, the number range object, and the
   setup class. Activate all inactive objects together (Ctrl+Shift+F3).
   If abapGit cannot create number range object ZP2P_MF001, create it in ADT
   in package ZP2P_MF001 (New > Other ABAP Repository Object, search "Number
   Range"): name ZP2P_MF001, number length domain ZP2P_PONR_MF001, warning
   10%, buffering in main memory. Then activate.
2. Run ZCL_P2P_SETUP_MF001 once (F9). It must print "Order number interval 01
   created: PO-0000001 to PO-9999999." A second run prints "already exists".
3. Run As > ABAP Unit Test on ZBP_I_P2P_PO_MF001. All 21 methods must pass.
4. In the app, choose Create. The new draft shows an order number such as
   PO-0000001 right away, and the field cannot be edited.
5. Add three items without typing item numbers: they get 00010, 00020, 00030.
6. Change the third item's number to 00015, then add another item: it gets
   00025. Change it to 00010: saving fails with the duplicate message.
7. Fix the number, enter supplier, product, quantity, and price, and save.
8. Create another order and discard the draft, then create a third order.
   The third order skips one number (the discarded draft used it).
9. Open PO-TEST-001: it keeps its old reference and can still be edited.

If step 2 or step 4 fails, record the exact message. Without the interval,
new orders show a number range message and cannot be saved.


## Revision 008 — amounts

Activated and tested in SAP on 2026-10-11: all 19 ABAP Unit tests passed.

Revision 008 calculates amounts. Changed objects: behavior definition
ZI_P2P_PO_MF001, behavior class ZBP_I_P2P_PO_MF001, projections
ZC_P2P_PO_MF001 and ZC_P2P_POIT_MF001, and their metadata extensions. No table
changes. Nothing is deleted.

- Net amount = quantity × unit price, rounded half up to 2 decimals. It is
  recalculated as soon as an item's quantity or price changes.
- Order total = sum of the item net amounts. It updates while you edit items.
  It is also recalculated on every save, which covers deleted items and orders
  saved before this revision (their amounts are still 0 until saved again).
- Net amount and Order total are read-only and now visible in the app:
  Order total in the order list and order header, Net amount in the item list
  and item page.
- A total too large for the amount column is rejected on the Order total field.
- ABAP Unit: three tests added (19 in total).

The app does not refresh the order total on screen after every keystroke. If
the header total looks stale while editing, it is correct after Save or after
refreshing the page.

Pull and test:

1. In abapGit, Pull. Activate all changed objects together (Ctrl+Shift+F3):
   the behavior definition and the behavior class must activate together.
2. Run As > ABAP Unit Test on ZBP_I_P2P_PO_MF001. All 19 methods must pass.
3. Create order PO-TEST-003 (or another unused reference) with item 00010,
   PROD01, quantity 10, unit price 100. Save. Net amount 1,000.00 EGP and
   Order total 1,000.00 EGP.
4. Edit, add item 00020, PROD02, quantity 2, unit price 50.50. Save. Net amount
   101.00 and Order total 1,101.00.
5. Edit, change item 00010 quantity to 9. Save. Net amount 900.00 and Order
   total 1,001.00.
6. Edit, delete item 00020. Save. Order total 900.00.
7. Open PO-TEST-001 from before. Edit and Save without changes. Its amounts
   are now filled in.
8. Open DEMO-PO-001 (released). It still shows 1,000.00 and cannot be edited.
9. Service metadata now contains TotalAmount and NetAmount. This replaces
   step 9 of the runtime gate below ("totals absent").

Record any failure with the object, line, and exact message.


## Revision 007 — what changed and how to test it

Activated and tested in SAP on 2026-10-11: all 16 ABAP Unit tests passed.

Revision 006 was activated and tested in SAP. Revision 007 changes only the
behavior class ZBP_I_P2P_PO_MF001 and deletes one unused class:

- Order references must be unique among your own active orders. Saving a second
  order with an existing reference fails on the Order reference field.
- Authorization now checks ownership only. Released orders are still frozen by
  feature control, so the UI and OData behave the same as before.
- Supplier/product checks read the CDS views ZI_P2P_SUPP_MF001 and
  ZI_P2P_PROD_MF001, so their access roles and the EA rule apply in one place.
- Two items with an empty item number now get only the "Enter an item number"
  message, not an extra "must be unique" message.
- ZCL_P2P_START_MF001 (milestone-1 hello world) is deleted. When abapGit shows
  it as an object to delete during Pull, confirm the deletion.
- ABAP Unit: one meaningless assertion removed, three tests added (16 in total).

Pull and test:

1. In abapGit, Pull. Accept the changed behavior class and the deletion.
2. Activate ZBP_I_P2P_PO_MF001.
3. Run As > ABAP Unit Test on ZBP_I_P2P_PO_MF001. All 16 methods must pass.
4. Create an order with reference PO-TEST-001 again while your existing
   PO-TEST-001 is still there. Saving must fail on Order reference. Change it
   to PO-TEST-002 and the save must succeed.
5. Open an existing order, change only the quantity, and save. It must not
   complain about its own reference.
6. Open DEMO-PO-001 (released). Edit and Delete must still be unavailable.
7. Choose an unknown supplier or product. Saving must still fail.
8. Add two items without item numbers. Each item shows one message only.
9. With a second SAP user, confirm that you still can't see or change the
   first user's orders.

Record any failure with the object, line, and exact message. The rest of this
file describes revision 006 and still applies.


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
