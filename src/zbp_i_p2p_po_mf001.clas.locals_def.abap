"Pure checks shared by the RAP validations and ABAP Unit tests.
CLASS lcl_p2p_rules DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS currency TYPE zp2p_po_mf001-currency_code VALUE 'EGP'.
    CONSTANTS unit TYPE zp2p_poit_mf001-unit_code VALUE 'EA'.
    CONSTANTS pending TYPE zp2p_po_mf001-status VALUE 'N'.
    CONSTANTS released TYPE zp2p_po_mf001-status VALUE 'R'.
    "Largest value that fits the CURR(15,2) amount columns.
    CONSTANTS max_amount TYPE zp2p_po_mf001-total_amount VALUE '9999999999999.99'.
    "Order numbers: number range object ZP2P_MF001, interval 01 (7 digits).
    CONSTANTS po_number_object TYPE cl_numberrange_runtime=>nr_object VALUE 'ZP2P_MF001'.
    CONSTANTS po_number_interval TYPE cl_numberrange_runtime=>nr_interval VALUE '01'.
    CONSTANTS po_number_prefix TYPE string VALUE `PO-`.
    CONSTANTS item_number_step TYPE i VALUE 10.
    TYPES:
      BEGIN OF ty_issue,
        field_name TYPE c LENGTH 30,
        text TYPE string,
      END OF ty_issue,
      tt_issues TYPE STANDARD TABLE OF ty_issue WITH EMPTY KEY,
      BEGIN OF ty_item_key,
        is_draft TYPE abp_behv_flag,
        po_uuid TYPE sysuuid_x16,
        item_uuid TYPE sysuuid_x16,
        item_number TYPE zp2p_poit_mf001-item_number,
      END OF ty_item_key,
      tt_item_keys TYPE STANDARD TABLE OF ty_item_key WITH EMPTY KEY.

    CLASS-METHODS check_header
      IMPORTING header TYPE zp2p_po_mf001 supplier_exists TYPE abap_bool
                number_taken TYPE abap_bool DEFAULT abap_false
                order_total TYPE decfloat34 DEFAULT 0
      RETURNING VALUE(issues) TYPE tt_issues.
    CLASS-METHODS check_item
      IMPORTING item TYPE zp2p_poit_mf001 product_exists TYPE abap_bool
      RETURNING VALUE(issues) TYPE tt_issues.
    "Quantity times price, rounded half up to 2 decimals; 0 if it does not fit.
    CLASS-METHODS net_amount
      IMPORTING quantity TYPE zp2p_poit_mf001-quantity
                unit_price TYPE zp2p_poit_mf001-unit_price
      RETURNING VALUE(result) TYPE zp2p_poit_mf001-net_amount.
    "The amount itself if it fits the amount columns, otherwise 0.
    "Validations report the overflow, so a 0 is never activated.
    CLASS-METHODS fit_amount
      IMPORTING amount TYPE decfloat34
      RETURNING VALUE(result) TYPE zp2p_po_mf001-total_amount.
    "PO- followed by the 7-digit counter, e.g. PO-0000042.
    CLASS-METHODS format_po_number
      IMPORTING counter TYPE int8
      RETURNING VALUE(result) TYPE zp2p_po_mf001-po_number.
    "Next item number after the highest one (10, 20, 30 ...); initial if none fits.
    CLASS-METHODS next_item_number
      IMPORTING highest TYPE zp2p_poit_mf001-item_number
      RETURNING VALUE(result) TYPE zp2p_poit_mf001-item_number.
    CLASS-METHODS duplicate_items
      IMPORTING items TYPE tt_item_keys
      RETURNING VALUE(duplicates) TYPE tt_item_keys.
ENDCLASS.
