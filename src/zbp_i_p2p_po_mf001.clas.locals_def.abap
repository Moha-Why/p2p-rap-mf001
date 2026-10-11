"Pure checks shared by the RAP validations and ABAP Unit tests.
CLASS lcl_p2p_rules DEFINITION FINAL.
  PUBLIC SECTION.
    CONSTANTS currency TYPE zp2p_po_mf001-currency_code VALUE 'EGP'.
    CONSTANTS unit TYPE zp2p_poit_mf001-unit_code VALUE 'EA'.
    CONSTANTS pending TYPE zp2p_po_mf001-status VALUE 'N'.
    CONSTANTS released TYPE zp2p_po_mf001-status VALUE 'R'.
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
      RETURNING VALUE(issues) TYPE tt_issues.
    CLASS-METHODS check_item
      IMPORTING item TYPE zp2p_poit_mf001 product_exists TYPE abap_bool
      RETURNING VALUE(issues) TYPE tt_issues.
    CLASS-METHODS duplicate_items
      IMPORTING items TYPE tt_item_keys
      RETURNING VALUE(duplicates) TYPE tt_item_keys.
ENDCLASS.
