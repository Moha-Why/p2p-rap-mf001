CLASS zcl_p2p_seed_mf001 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_p2p_seed_mf001 IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    " Bootstrap fixture only. Run sequentially before developing RAP behavior.
    " Interactive business writes must later use RAP, not this console class.
    DATA(lv_owner) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA lv_due_date TYPE d.
    lv_due_date = lv_date + 30.
    DATA lv_now TYPE timestampl.
    GET TIME STAMP FIELD lv_now.
    out->write( |Demo owner: { lv_owner }| ).

    TRY.
        SELECT SINGLE po_uuid
          FROM zp2p_po_mf001
          WHERE created_by = @lv_owner
            AND po_number = 'DEMO-PO-001'
          INTO @DATA(lv_existing).
        IF sy-subrc = 0.
          out->write( 'Demo purchase order already exists for your user; kept unchanged.' ).
          out->write( 'Milestone 2: no duplicate documents created.' ).
          RETURN.
        ENDIF.

        DATA(lv_po) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_po_item) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_receipt) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_receipt_item) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_invoice) = cl_system_uuid=>create_uuid_x16_static( ).
        DATA(lv_invoice_item) = cl_system_uuid=>create_uuid_x16_static( ).

        DATA lt_suppliers TYPE STANDARD TABLE OF zp2p_supp_mf001 WITH EMPTY KEY.
        lt_suppliers = VALUE #(
          ( client = sy-mandt owner_id = lv_owner
            supplier_id = 'DEMO01' supplier_name = 'Demo fasteners supplier'
            created_by = lv_owner created_at = lv_now
            local_last_changed_by = lv_owner local_last_changed_at = lv_now
            last_changed_at = lv_now )
          ( client = sy-mandt owner_id = lv_owner
            supplier_id = 'DEMO02' supplier_name = 'Alternate demo supplier'
            created_by = lv_owner created_at = lv_now
            local_last_changed_by = lv_owner local_last_changed_at = lv_now
            last_changed_at = lv_now ) ).

        DATA lt_products TYPE STANDARD TABLE OF zp2p_prod_mf001 WITH EMPTY KEY.
        lt_products = VALUE #(
          ( client = sy-mandt owner_id = lv_owner
            product_id = 'PROD01' product_name = 'Demo bolts' unit_code = 'EA'
            created_by = lv_owner created_at = lv_now
            local_last_changed_by = lv_owner local_last_changed_at = lv_now
            last_changed_at = lv_now )
          ( client = sy-mandt owner_id = lv_owner
            product_id = 'PROD02' product_name = 'Demo washers' unit_code = 'EA'
            created_by = lv_owner created_at = lv_now
            local_last_changed_by = lv_owner local_last_changed_at = lv_now
            last_changed_at = lv_now ) ).

        DATA(ls_po) = VALUE zp2p_po_mf001(
          client = sy-mandt
          po_uuid = lv_po
          po_number = 'DEMO-PO-001'
          supplier_id = 'DEMO01'
          order_date = lv_date
          currency_code = 'EGP'
          status = 'R'
          total_amount = '1000.00'
          created_by = lv_owner
          created_at = lv_now
          local_last_changed_by = lv_owner
          local_last_changed_at = lv_now
          last_changed_at = lv_now ).
        DATA(ls_po_item) = VALUE zp2p_poit_mf001(
          client = sy-mandt
          item_uuid = lv_po_item
          po_uuid = lv_po
          item_number = '00010'
          product_id = 'PROD01'
          description = 'Demo bolts'
          unit_code = 'EA'
          currency_code = 'EGP'
          quantity = '10.000'
          unit_price = '100.00'
          net_amount = '1000.00'
          created_by = lv_owner
          created_at = lv_now
          local_last_changed_by = lv_owner
          local_last_changed_at = lv_now
          last_changed_at = lv_now ).
        DATA(ls_receipt) = VALUE zp2p_gr_mf001(
          client = sy-mandt
          receipt_uuid = lv_receipt
          po_uuid = lv_po
          receipt_number = 'DEMO-GR-001'
          receipt_date = lv_date
          status = 'P'
          created_by = lv_owner
          created_at = lv_now
          local_last_changed_by = lv_owner
          local_last_changed_at = lv_now
          last_changed_at = lv_now ).
        DATA(ls_receipt_item) = VALUE zp2p_grit_mf001(
          client = sy-mandt
          receipt_item_uuid = lv_receipt_item
          po_uuid = lv_po
          receipt_uuid = lv_receipt
          po_item_uuid = lv_po_item
          item_number = '00010'
          unit_code = 'EA'
          quantity = '6.000'
          created_by = lv_owner
          created_at = lv_now
          local_last_changed_by = lv_owner
          local_last_changed_at = lv_now
          last_changed_at = lv_now ).
        DATA(ls_invoice) = VALUE zp2p_inv_mf001(
          client = sy-mandt
          invoice_uuid = lv_invoice
          po_uuid = lv_po
          invoice_number = 'DEMO-INV-001'
          supplier_id = 'DEMO01'
          supplier_reference = 'DEMO-SUP-INV-001'
          normalized_reference = 'DEMO-SUP-INV-001'
          invoice_date = lv_date
          due_date = lv_due_date
          currency_code = 'EGP'
          status = 'P'
          payment_status = 'U'
          total_amount = '400.00'
          created_by = lv_owner
          created_at = lv_now
          local_last_changed_by = lv_owner
          local_last_changed_at = lv_now
          last_changed_at = lv_now ).
        DATA(ls_invoice_item) = VALUE zp2p_invit_mf001(
          client = sy-mandt
          invoice_item_uuid = lv_invoice_item
          po_uuid = lv_po
          invoice_uuid = lv_invoice
          po_item_uuid = lv_po_item
          item_number = '00010'
          unit_code = 'EA'
          currency_code = 'EGP'
          quantity = '4.000'
          unit_price = '100.00'
          net_amount = '400.00'
          created_by = lv_owner
          created_at = lv_now
          local_last_changed_by = lv_owner
          local_last_changed_at = lv_now
          last_changed_at = lv_now ).

        " Keep existing reference-data rows; never overwrite another dataset.
        INSERT zp2p_supp_mf001 FROM TABLE @lt_suppliers ACCEPTING DUPLICATE KEYS.
        INSERT zp2p_prod_mf001 FROM TABLE @lt_products ACCEPTING DUPLICATE KEYS.
        INSERT zp2p_po_mf001 FROM @ls_po.
        IF sy-subrc <> 0.
          ROLLBACK WORK.
          out->write( 'Fixture insertion failed in zp2p_po_mf001; nothing saved.' ).
          RETURN.
        ENDIF.
        INSERT zp2p_poit_mf001 FROM @ls_po_item.
        IF sy-subrc <> 0.
          ROLLBACK WORK.
          out->write( 'Fixture insertion failed in zp2p_poit_mf001; nothing saved.' ).
          RETURN.
        ENDIF.
        INSERT zp2p_gr_mf001 FROM @ls_receipt.
        IF sy-subrc <> 0.
          ROLLBACK WORK.
          out->write( 'Fixture insertion failed in zp2p_gr_mf001; nothing saved.' ).
          RETURN.
        ENDIF.
        INSERT zp2p_grit_mf001 FROM @ls_receipt_item.
        IF sy-subrc <> 0.
          ROLLBACK WORK.
          out->write( 'Fixture insertion failed in zp2p_grit_mf001; nothing saved.' ).
          RETURN.
        ENDIF.
        INSERT zp2p_inv_mf001 FROM @ls_invoice.
        IF sy-subrc <> 0.
          ROLLBACK WORK.
          out->write( 'Fixture insertion failed in zp2p_inv_mf001; nothing saved.' ).
          RETURN.
        ENDIF.
        INSERT zp2p_invit_mf001 FROM @ls_invoice_item.
        IF sy-subrc <> 0.
          ROLLBACK WORK.
          out->write( 'Fixture insertion failed in zp2p_invit_mf001; nothing saved.' ).
          RETURN.
        ENDIF.

        " Check the linked fixture inside the same LUW before committing.
        SELECT COUNT( * )
          FROM zp2p_po_mf001 AS po
          INNER JOIN zp2p_poit_mf001 AS pi ON pi~po_uuid = po~po_uuid
          INNER JOIN zp2p_gr_mf001 AS gr ON gr~po_uuid = po~po_uuid
          INNER JOIN zp2p_grit_mf001 AS gi
            ON gi~receipt_uuid = gr~receipt_uuid
            AND gi~po_uuid = po~po_uuid
            AND gi~po_item_uuid = pi~item_uuid
          INNER JOIN zp2p_inv_mf001 AS ih ON ih~po_uuid = po~po_uuid
          INNER JOIN zp2p_invit_mf001 AS ii
            ON ii~invoice_uuid = ih~invoice_uuid
            AND ii~po_uuid = po~po_uuid
            AND ii~po_item_uuid = pi~item_uuid
          WHERE po~po_uuid = @lv_po
            AND po~created_by = @lv_owner
            AND pi~created_by = @lv_owner
            AND gr~created_by = @lv_owner
            AND gi~created_by = @lv_owner
            AND ih~created_by = @lv_owner
            AND ii~created_by = @lv_owner
          INTO @DATA(lv_linked_rows).
        IF lv_linked_rows <> 1.
          ROLLBACK WORK.
          out->write( 'Fixture relationship check failed; nothing saved.' ).
          RETURN.
        ENDIF.

        COMMIT WORK.
        out->write( 'P2P milestone 2: demo fixture created.' ).
        out->write( 'DEMO-PO-001: ordered 10 EA at 100 EGP each.' ).
        out->write( 'DEMO-GR-001: received 6 EA.' ).
        out->write( 'DEMO-INV-001: invoiced 4 EA; net value 400 EGP.' ).
        out->write( 'Available to invoice: 2 EA.' ).
        out->write( 'These are seeded fixtures; posting behavior is implemented later.' ).
      CATCH cx_uuid_error cx_sy_open_sql_db INTO DATA(lx_error).
        ROLLBACK WORK.
        out->write( 'Demo load failed; this execution was rolled back.' ).
        out->write( lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

