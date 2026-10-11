CLASS ltc_p2p_rules DEFINITION FINAL FOR TESTING
  DURATION SHORT RISK LEVEL HARMLESS.
  PRIVATE SECTION.
    DATA header TYPE zp2p_po_mf001.
    DATA item TYPE zp2p_poit_mf001.
    METHODS setup.
    METHODS valid_header FOR TESTING.
    METHODS header_required_fields FOR TESTING.
    METHODS foreign_supplier FOR TESTING.
    METHODS invalid_calendar_date FOR TESTING.
    METHODS header_currency_status FOR TESTING.
    METHODS valid_item FOR TESTING.
    METHODS item_required_fields FOR TESTING.
    METHODS zero_and_negative_values FOR TESTING.
    METHODS foreign_product FOR TESTING.
    METHODS wrong_unit_currency FOR TESTING.
    METHODS amount_overflow FOR TESTING.
    METHODS duplicate_lines FOR TESTING.
    METHODS other_orders_and_drafts FOR TESTING.
    METHODS blank_numbers_not_duplicates FOR TESTING.
    METHODS order_reference_taken FOR TESTING.
    METHODS blank_reference_not_taken FOR TESTING.
    METHODS net_amount_rounding FOR TESTING.
    METHODS net_amount_overflow FOR TESTING.
    METHODS order_total_limit FOR TESTING.
    METHODS po_number_format FOR TESTING.
    METHODS item_number_sequence FOR TESTING.
ENDCLASS.

CLASS ltc_p2p_rules IMPLEMENTATION.
  METHOD setup.
    header = VALUE #( po_number = 'TEST-PO' supplier_id = 'DEMO01'
                      order_date = '20261011' currency_code = 'EGP' status = 'N' ).
    item = VALUE #( item_number = '00010' product_id = 'PROD01'
                    quantity = '10.000' unit_price = '100.00'
                    unit_code = 'EA' currency_code = 'EGP' ).
  ENDMETHOD.

  METHOD valid_header.
    cl_abap_unit_assert=>assert_initial(
      act = lcl_p2p_rules=>check_header( header = header supplier_exists = abap_true ) ).
    header-status = 'R'.
    cl_abap_unit_assert=>assert_initial(
      act = lcl_p2p_rules=>check_header( header = header supplier_exists = abap_true ) ).
  ENDMETHOD.

  METHOD header_required_fields.
    CLEAR: header-po_number, header-supplier_id, header-order_date.
    DATA(issues) = lcl_p2p_rules=>check_header( header = header supplier_exists = abap_false ).
    cl_abap_unit_assert=>assert_equals( exp = 3 act = lines( issues ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( issues[ field_name = 'PURCHASEORDERNUMBER' ] ) ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( issues[ field_name = 'SUPPLIERID' ] ) ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( issues[ field_name = 'ORDERDATE' ] ) ) ).
  ENDMETHOD.

  METHOD foreign_supplier.
    DATA(issues) = lcl_p2p_rules=>check_header( header = header supplier_exists = abap_false ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( issues ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'SUPPLIERID' act = issues[ 1 ]-field_name ).
  ENDMETHOD.

  METHOD invalid_calendar_date.
    header-order_date = '20260230'.
    DATA(issues) = lcl_p2p_rules=>check_header( header = header supplier_exists = abap_true ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( issues[ field_name = 'ORDERDATE' ] ) ) ).
    header-order_date = '20240229'.
    cl_abap_unit_assert=>assert_initial(
      act = lcl_p2p_rules=>check_header( header = header supplier_exists = abap_true ) ).
  ENDMETHOD.

  METHOD header_currency_status.
    header-currency_code = 'USD'.
    header-status = 'X'.
    DATA(issues) = lcl_p2p_rules=>check_header( header = header supplier_exists = abap_true ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( issues ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( issues[ field_name = 'CURRENCYCODE' ] ) ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( issues[ field_name = 'STATUS' ] ) ) ).
  ENDMETHOD.

  METHOD valid_item.
    cl_abap_unit_assert=>assert_initial(
      act = lcl_p2p_rules=>check_item( item = item product_exists = abap_true ) ).
    item-quantity = '0.001'.
    item-unit_price = '0.01'.
    cl_abap_unit_assert=>assert_initial(
      act = lcl_p2p_rules=>check_item( item = item product_exists = abap_true ) ).
  ENDMETHOD.

  METHOD item_required_fields.
    CLEAR: item-item_number, item-product_id.
    DATA(issues) = lcl_p2p_rules=>check_item( item = item product_exists = abap_false ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( issues ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( issues[ field_name = 'ITEMNUMBER' ] ) ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( issues[ field_name = 'PRODUCTID' ] ) ) ).
  ENDMETHOD.

  METHOD zero_and_negative_values.
    item-quantity = 0.
    item-unit_price = 0.
    DATA(issues) = lcl_p2p_rules=>check_item( item = item product_exists = abap_true ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( issues ) ).
    item-quantity = -1.
    item-unit_price = -1.
    issues = lcl_p2p_rules=>check_item( item = item product_exists = abap_true ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( issues[ field_name = 'QUANTITY' ] ) ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( issues[ field_name = 'UNITPRICE' ] ) ) ).
  ENDMETHOD.

  METHOD foreign_product.
    DATA(issues) = lcl_p2p_rules=>check_item( item = item product_exists = abap_false ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( issues ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'PRODUCTID' act = issues[ 1 ]-field_name ).
  ENDMETHOD.

  METHOD wrong_unit_currency.
    item-unit_code = 'KG'.
    item-currency_code = 'USD'.
    DATA(issues) = lcl_p2p_rules=>check_item( item = item product_exists = abap_true ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( issues ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( issues[ field_name = 'UNITCODE' ] ) ) ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( issues[ field_name = 'CURRENCYCODE' ] ) ) ).
  ENDMETHOD.

  METHOD amount_overflow.
    item-quantity = 1.
    item-unit_price = '9999999999999.99'.
    cl_abap_unit_assert=>assert_initial(
      act = lcl_p2p_rules=>check_item( item = item product_exists = abap_true ) ).
    item-quantity = 2.
    DATA(issues) = lcl_p2p_rules=>check_item( item = item product_exists = abap_true ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( issues ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'UNITPRICE' act = issues[ 1 ]-field_name ).
  ENDMETHOD.

  METHOD duplicate_lines.
    DATA(items) = VALUE lcl_p2p_rules=>tt_item_keys(
      ( is_draft = if_abap_behv=>mk-on po_uuid = '00000000000000000000000000000001'
        item_uuid = '00000000000000000000000000000011' item_number = '00010' )
      ( is_draft = if_abap_behv=>mk-on po_uuid = '00000000000000000000000000000001'
        item_uuid = '00000000000000000000000000000012' item_number = '00010' )
      ( is_draft = if_abap_behv=>mk-on po_uuid = '00000000000000000000000000000001'
        item_uuid = '00000000000000000000000000000013' item_number = '00020' ) ).
    DATA(duplicates) = lcl_p2p_rules=>duplicate_items( items ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( duplicates ) ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( duplicates[ item_number = '00020' ] ) ) ).
  ENDMETHOD.

  METHOD other_orders_and_drafts.
    DATA(items) = VALUE lcl_p2p_rules=>tt_item_keys(
      ( is_draft = if_abap_behv=>mk-off po_uuid = '00000000000000000000000000000001'
        item_uuid = '00000000000000000000000000000011' item_number = '00010' )
      ( is_draft = if_abap_behv=>mk-on po_uuid = '00000000000000000000000000000001'
        item_uuid = '00000000000000000000000000000011' item_number = '00010' )
      ( is_draft = if_abap_behv=>mk-on po_uuid = '00000000000000000000000000000002'
        item_uuid = '00000000000000000000000000000012' item_number = '00010' ) ).
    cl_abap_unit_assert=>assert_initial( act = lcl_p2p_rules=>duplicate_items( items ) ).
  ENDMETHOD.

  METHOD blank_numbers_not_duplicates.
    "Blank numbers get one 'required' message from check_item, not a second duplicate message.
    DATA(items) = VALUE lcl_p2p_rules=>tt_item_keys(
      ( is_draft = if_abap_behv=>mk-on po_uuid = '00000000000000000000000000000001'
        item_uuid = '00000000000000000000000000000011' )
      ( is_draft = if_abap_behv=>mk-on po_uuid = '00000000000000000000000000000001'
        item_uuid = '00000000000000000000000000000012' ) ).
    cl_abap_unit_assert=>assert_initial( act = lcl_p2p_rules=>duplicate_items( items ) ).
  ENDMETHOD.

  METHOD order_reference_taken.
    DATA(issues) = lcl_p2p_rules=>check_header( header = header supplier_exists = abap_true
                                                number_taken = abap_true ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( issues ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'PURCHASEORDERNUMBER' act = issues[ 1 ]-field_name ).
  ENDMETHOD.

  METHOD blank_reference_not_taken.
    "A missing number gets the 'not assigned' message only, never the 'already used' one too.
    CLEAR header-po_number.
    DATA(issues) = lcl_p2p_rules=>check_header( header = header supplier_exists = abap_true
                                                number_taken = abap_true ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( issues ) ).
    cl_abap_unit_assert=>assert_equals(
      exp = 'No order number was assigned. Check the order number range setup.' act = issues[ 1 ]-text ).
  ENDMETHOD.

  METHOD net_amount_rounding.
    cl_abap_unit_assert=>assert_equals( exp = CONV zp2p_poit_mf001-net_amount( '1000.00' )
      act = lcl_p2p_rules=>net_amount( quantity = '10.000' unit_price = '100.00' ) ).
    "1.005 is rounded half up to 1.01.
    cl_abap_unit_assert=>assert_equals( exp = CONV zp2p_poit_mf001-net_amount( '1.01' )
      act = lcl_p2p_rules=>net_amount( quantity = '1.005' unit_price = '1.00' ) ).
    cl_abap_unit_assert=>assert_equals( exp = CONV zp2p_poit_mf001-net_amount( '0.00' )
      act = lcl_p2p_rules=>net_amount( quantity = '0.001' unit_price = '0.01' ) ).
  ENDMETHOD.

  METHOD net_amount_overflow.
    "Too large to store: 0 is returned and check_item reports the overflow.
    cl_abap_unit_assert=>assert_equals( exp = CONV zp2p_poit_mf001-net_amount( '9999999999999.99' )
      act = lcl_p2p_rules=>net_amount( quantity = 1 unit_price = '9999999999999.99' ) ).
    cl_abap_unit_assert=>assert_initial(
      act = lcl_p2p_rules=>net_amount( quantity = 2 unit_price = '9999999999999.99' ) ).
  ENDMETHOD.

  METHOD order_total_limit.
    cl_abap_unit_assert=>assert_initial( act = lcl_p2p_rules=>check_header(
      header = header supplier_exists = abap_true
      order_total = CONV decfloat34( lcl_p2p_rules=>max_amount ) ) ).
    DATA(issues) = lcl_p2p_rules=>check_header(
      header = header supplier_exists = abap_true
      order_total = CONV decfloat34( '10000000000000.00' ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( issues ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'TOTALAMOUNT' act = issues[ 1 ]-field_name ).
    cl_abap_unit_assert=>assert_initial( act = lcl_p2p_rules=>fit_amount( CONV decfloat34( '10000000000000.00' ) ) ).
  ENDMETHOD.

  METHOD po_number_format.
    cl_abap_unit_assert=>assert_equals( exp = 'PO-0000001'
      act = lcl_p2p_rules=>format_po_number( CONV int8( 1 ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'PO-9999999'
      act = lcl_p2p_rules=>format_po_number( CONV int8( 9999999 ) ) ).
  ENDMETHOD.

  METHOD item_number_sequence.
    cl_abap_unit_assert=>assert_equals( exp = CONV zp2p_poit_mf001-item_number( '00010' )
      act = lcl_p2p_rules=>next_item_number( '00000' ) ).
    "A manually entered 15 is followed by 25.
    cl_abap_unit_assert=>assert_equals( exp = CONV zp2p_poit_mf001-item_number( '00025' )
      act = lcl_p2p_rules=>next_item_number( '00015' ) ).
    cl_abap_unit_assert=>assert_equals( exp = CONV zp2p_poit_mf001-item_number( '99999' )
      act = lcl_p2p_rules=>next_item_number( '99989' ) ).
    "No room left: no number is proposed, validateItem asks for one.
    cl_abap_unit_assert=>assert_initial( act = lcl_p2p_rules=>next_item_number( '99990' ) ).
  ENDMETHOD.
ENDCLASS.
