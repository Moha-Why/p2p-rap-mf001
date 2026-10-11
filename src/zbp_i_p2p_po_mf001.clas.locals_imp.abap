CLASS lcl_p2p_rules IMPLEMENTATION.
  METHOD check_header.
    IF header-po_number IS INITIAL.
      APPEND VALUE #( field_name = 'PURCHASEORDERNUMBER'
                      text = 'No order number was assigned. Check the order number range setup.' ) TO issues.
    ELSEIF number_taken = abap_true.
      APPEND VALUE #( field_name = 'PURCHASEORDERNUMBER'
                      text = 'Another of your orders already uses this order number.' ) TO issues.
    ENDIF.
    IF header-supplier_id IS INITIAL OR supplier_exists = abap_false.
      APPEND VALUE #( field_name = 'SUPPLIERID'
                      text = 'Choose a supplier from your own supplier list.' ) TO issues.
    ENDIF.
    DATA date_check TYPE timestamp ##NEEDED.
    CONVERT DATE header-order_date INTO TIME STAMP date_check TIME ZONE 'UTC'.
    IF header-order_date IS INITIAL OR sy-subrc <> 0.
      APPEND VALUE #( field_name = 'ORDERDATE'
                      text = 'Enter a valid order date.' ) TO issues.
    ENDIF.
    IF header-currency_code <> currency.
      APPEND VALUE #( field_name = 'CURRENCYCODE'
                      text = 'This application supports EGP currency only.' ) TO issues.
    ENDIF.
    IF header-status <> pending AND header-status <> released.
      APPEND VALUE #( field_name = 'STATUS'
                      text = 'The order has an invalid status.' ) TO issues.
    ENDIF.
    IF abs( order_total ) > max_amount.
      APPEND VALUE #( field_name = 'TOTALAMOUNT'
                      text = 'The order total exceeds the supported amount size.' ) TO issues.
    ENDIF.
  ENDMETHOD.

  METHOD check_item.
    IF item-item_number IS INITIAL.
      APPEND VALUE #( field_name = 'ITEMNUMBER'
                      text = 'Enter an item number greater than zero.' ) TO issues.
    ENDIF.
    IF item-product_id IS INITIAL OR product_exists = abap_false.
      APPEND VALUE #( field_name = 'PRODUCTID'
                      text = 'Choose a product from your own EA product list.' ) TO issues.
    ENDIF.
    IF item-quantity <= 0.
      APPEND VALUE #( field_name = 'QUANTITY'
                      text = 'Quantity must be greater than zero.' ) TO issues.
    ENDIF.
    IF item-unit_price <= 0.
      APPEND VALUE #( field_name = 'UNITPRICE'
                      text = 'Unit price must be greater than zero.' ) TO issues.
    ENDIF.
    IF item-unit_code <> unit.
      APPEND VALUE #( field_name = 'UNITCODE'
                      text = 'This application supports EA units only.' ) TO issues.
    ENDIF.
    IF item-currency_code <> currency.
      APPEND VALUE #( field_name = 'CURRENCYCODE'
                      text = 'This application supports EGP currency only.' ) TO issues.
    ENDIF.
    IF CONV decfloat34( item-quantity ) * CONV decfloat34( item-unit_price ) > max_amount.
      APPEND VALUE #( field_name = 'UNITPRICE'
                      text = 'Quantity times price exceeds the supported amount size.' ) TO issues.
    ENDIF.
  ENDMETHOD.

  METHOD net_amount.
    result = fit_amount( round( val = CONV decfloat34( quantity ) * CONV decfloat34( unit_price )
                                dec = 2 ) ).
  ENDMETHOD.

  METHOD fit_amount.
    IF abs( amount ) <= max_amount.
      result = amount.
    ENDIF.
  ENDMETHOD.

  METHOD format_po_number.
    DATA digits TYPE n LENGTH 7.
    digits = counter.
    result = |{ po_number_prefix }{ digits }|.
  ENDMETHOD.

  METHOD next_item_number.
    "Item numbers are NUMC (character-like), so calculate in an integer.
    CONSTANTS largest TYPE i VALUE 99999.
    DATA(next) = CONV i( highest ) + item_number_step.
    IF next <= largest.
      result = next.
    ENDIF.
  ENDMETHOD.

  METHOD release_blocker.
    IF status <> pending.
      result = `Only pending orders can be released.`.
    ELSEIF has_items = abap_false.
      result = `Add at least one item before releasing the order.`.
    ENDIF.
  ENDMETHOD.

  METHOD duplicate_items.
    "Blank numbers are reported as missing by check_item, not as duplicates.
    LOOP AT items INTO DATA(item) WHERE item_number IS NOT INITIAL
         GROUP BY ( is_draft = item-is_draft po_uuid = item-po_uuid
                    item_number = item-item_number size = GROUP SIZE )
         INTO DATA(group).
      IF group-size > 1.
        duplicates = VALUE #( BASE duplicates FOR member IN GROUP group ( member ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_purchaseorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR PurchaseOrder RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR PurchaseOrder RESULT result.
    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseOrder~setDefaults.
    METHODS validateHeader FOR VALIDATE ON SAVE
      IMPORTING keys FOR PurchaseOrder~validateHeader.
    METHODS assignOrderNumber FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseOrder~assignOrderNumber.
    METHODS calculateAmounts FOR DETERMINE ON SAVE
      IMPORTING keys FOR PurchaseOrder~calculateAmounts.
    METHODS recalculateAmounts FOR MODIFY
      IMPORTING keys FOR ACTION PurchaseOrder~recalculateAmounts.
    METHODS releaseOrder FOR MODIFY
      IMPORTING keys FOR ACTION PurchaseOrder~releaseOrder RESULT result.
ENDCLASS.

CLASS lhc_purchaseorder IMPLEMENTATION.
  METHOD get_instance_authorizations.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( CreatedBy ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      FAILED DATA(read_failed)
      REPORTED DATA(read_reported).
    MOVE-CORRESPONDING read_failed TO failed
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    MOVE-CORRESPONDING read_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.

    "Authorization is ownership only. Status rules (released orders are frozen)
    "belong to get_instance_features, so later receipt/invoice steps can still
    "be authorized on a released order.
    DATA(owner) = cl_abap_context_info=>get_user_technical_name( ).
    LOOP AT orders INTO DATA(order).
      "For a new draft the active-record creation user may not yet be populated.
      "RAP additionally enforces exclusive draft ownership through its admin data.
      DATA(own_order) = xsdbool(
        order-CreatedBy = owner OR
        ( order-CreatedBy IS INITIAL AND order-%is_draft = if_abap_behv=>mk-on ) ).
      DATA(permission) = COND #( WHEN own_order = abap_true
        THEN if_abap_behv=>auth-allowed ELSE if_abap_behv=>auth-unauthorized ).

      APPEND VALUE #( %tky = order-%tky
                      %update = permission
                      %delete = permission
                      %action-Edit = permission ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      FAILED DATA(read_failed)
      REPORTED DATA(read_reported).
    MOVE-CORRESPONDING read_failed TO failed
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    MOVE-CORRESPONDING read_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.

    "Release works on the saved (active) order, not on a draft being edited.
    result = VALUE #( FOR order IN orders
      LET editable = COND #( WHEN order-Status = lcl_p2p_rules=>pending
                             THEN if_abap_behv=>fc-o-enabled
                             ELSE if_abap_behv=>fc-o-disabled )
          releasable = COND #( WHEN order-Status = lcl_p2p_rules=>pending
                                AND order-%is_draft = if_abap_behv=>mk-off
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled )
      IN ( %tky = order-%tky
           %update = editable
           %delete = editable
           %action-Edit = editable
           %action-releaseOrder = releasable
           %assoc-_Items = editable ) ).
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( Status CurrencyCode OrderDate ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      REPORTED DATA(read_reported).
    "EML and determination responses have different derived types.
    MOVE-CORRESPONDING read_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.

    DELETE orders WHERE Status IS NOT INITIAL
                    AND CurrencyCode IS NOT INITIAL
                    AND OrderDate IS NOT INITIAL.
    CHECK orders IS NOT INITIAL.

    MODIFY ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder UPDATE FIELDS ( Status CurrencyCode OrderDate )
      WITH VALUE #( FOR order IN orders
        ( %tky = order-%tky
          Status = COND #( WHEN order-Status IS INITIAL
                           THEN lcl_p2p_rules=>pending ELSE order-Status )
          CurrencyCode = COND #( WHEN order-CurrencyCode IS INITIAL
                                 THEN lcl_p2p_rules=>currency ELSE order-CurrencyCode )
          OrderDate = COND #( WHEN order-OrderDate IS INITIAL
                              THEN cl_abap_context_info=>get_system_date( )
                              ELSE order-OrderDate ) ) )
      REPORTED DATA(modify_reported).
    MOVE-CORRESPONDING modify_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
  ENDMETHOD.

  METHOD validateHeader.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( PurchaseOrderNumber SupplierID OrderDate CurrencyCode Status )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      FAILED DATA(read_failed)
      REPORTED DATA(read_reported).
    MOVE-CORRESPONDING read_failed TO failed
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    MOVE-CORRESPONDING read_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    CHECK orders IS NOT INITIAL.

    "Behavior handlers read tables with an explicit owner filter. They must not
    "rely on CDS access control (ABAP contract check UNPRIVILEGED SELECT).
    DATA(owner) = cl_abap_context_info=>get_user_technical_name( ).
    DATA suppliers TYPE SORTED TABLE OF zp2p_supp_mf001-supplier_id
      WITH UNIQUE KEY table_line.
    SELECT FROM zp2p_supp_mf001
      FIELDS supplier_id
      FOR ALL ENTRIES IN @orders
      WHERE owner_id = @owner AND supplier_id = @orders-SupplierID
      INTO TABLE @suppliers.

    "Order numbers must be unique among the user's active orders. Editing an
    "existing order keeps its UUID, so the order never clashes with itself.
    SELECT FROM zp2p_po_mf001
      FIELDS po_uuid AS PurchaseOrderUUID, po_number AS PurchaseOrderNumber
      FOR ALL ENTRIES IN @orders
      WHERE created_by = @owner
        AND po_number = @orders-PurchaseOrderNumber
        AND po_uuid <> @orders-PurchaseOrderUUID
      INTO TABLE @DATA(clashes).

    "Net amounts are recalculated by calculateAmounts before validations run.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Items
        FIELDS ( PurchaseOrderUUID NetAmount ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    DATA number_taken TYPE abap_bool.
    LOOP AT orders INTO DATA(order).
      APPEND VALUE #( %tky = order-%tky %state_area = 'HEADER' ) TO reported-PurchaseOrder.
      "A batch can return this order's own active row for another order's lookup.
      number_taken = abap_false.
      LOOP AT clashes TRANSPORTING NO FIELDS
           WHERE PurchaseOrderNumber = order-PurchaseOrderNumber
             AND PurchaseOrderUUID <> order-PurchaseOrderUUID.
        number_taken = abap_true.
        EXIT.
      ENDLOOP.
      DATA(issues) = lcl_p2p_rules=>check_header(
        header = VALUE #( po_number = order-PurchaseOrderNumber supplier_id = order-SupplierID
                          order_date = order-OrderDate currency_code = order-CurrencyCode
                          status = order-Status )
        supplier_exists = xsdbool( line_exists( suppliers[ table_line = order-SupplierID ] ) )
        number_taken = number_taken
        order_total = REDUCE decfloat34( INIT sum = CONV decfloat34( 0 )
                        FOR item IN items WHERE ( %is_draft = order-%is_draft
                                                  AND PurchaseOrderUUID = order-PurchaseOrderUUID )
                        NEXT sum = sum + item-NetAmount ) ).
      IF issues IS NOT INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-PurchaseOrder.
      ENDIF.
      LOOP AT issues INTO DATA(issue).
        APPEND VALUE #( %tky = order-%tky %state_area = 'HEADER'
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error text = issue-text ) )
          TO reported-PurchaseOrder ASSIGNING FIELD-SYMBOL(<message>).
        CASE issue-field_name.
          WHEN 'PURCHASEORDERNUMBER'. <message>-%element-PurchaseOrderNumber = if_abap_behv=>mk-on.
          WHEN 'SUPPLIERID'. <message>-%element-SupplierID = if_abap_behv=>mk-on.
          WHEN 'ORDERDATE'. <message>-%element-OrderDate = if_abap_behv=>mk-on.
          WHEN 'CURRENCYCODE'. <message>-%element-CurrencyCode = if_abap_behv=>mk-on.
          WHEN 'STATUS'. <message>-%element-Status = if_abap_behv=>mk-on.
          WHEN 'TOTALAMOUNT'. <message>-%element-TotalAmount = if_abap_behv=>mk-on.
        ENDCASE.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD assignOrderNumber.
    "Numbers are drawn when an order is created (also as a draft), like SAP's
    "early numbering samples. A discarded draft leaves a gap; that is expected.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( PurchaseOrderNumber ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      REPORTED DATA(read_reported).
    "EML and determination responses have different derived types.
    MOVE-CORRESPONDING read_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    DELETE orders WHERE PurchaseOrderNumber IS NOT INITIAL.
    CHECK orders IS NOT INITIAL.

    TRY.
        cl_numberrange_runtime=>number_get(
          EXPORTING nr_range_nr       = lcl_p2p_rules=>po_number_interval
                    object            = lcl_p2p_rules=>po_number_object
                    quantity          = CONV #( lines( orders ) )
          IMPORTING number            = DATA(last_number)
                    returned_quantity = DATA(returned_quantity) ).
      CATCH cx_number_ranges INTO DATA(number_error).
        "The orders stay without a number; validateHeader blocks their activation.
        LOOP AT orders INTO DATA(order_without_number).
          APPEND VALUE #( %tky = order_without_number-%tky %msg = number_error )
            TO reported-PurchaseOrder.
        ENDLOOP.
        RETURN.
    ENDTRY.

    "The returned numbers are the last returned_quantity numbers up to last_number.
    "If the interval ran short, the remaining orders stay without a number.
    TYPES: BEGIN OF ty_order_number,
             is_draft TYPE abp_behv_flag,
             po_uuid TYPE sysuuid_x16,
             po_number TYPE zp2p_po_mf001-po_number,
           END OF ty_order_number.
    DATA order_numbers TYPE STANDARD TABLE OF ty_order_number WITH EMPTY KEY.
    DATA counter TYPE int8.
    counter = last_number - returned_quantity.
    LOOP AT orders INTO DATA(order).
      IF sy-tabix > returned_quantity.
        EXIT.
      ENDIF.
      counter = counter + 1.
      APPEND VALUE #( is_draft = order-%is_draft po_uuid = order-PurchaseOrderUUID
                      po_number = lcl_p2p_rules=>format_po_number( counter ) ) TO order_numbers.
    ENDLOOP.

    MODIFY ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder UPDATE FIELDS ( PurchaseOrderNumber )
      WITH VALUE #( FOR order_number IN order_numbers
        ( %is_draft = order_number-is_draft PurchaseOrderUUID = order_number-po_uuid
          PurchaseOrderNumber = order_number-po_number ) )
      REPORTED DATA(modify_reported).
    MOVE-CORRESPONDING modify_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
  ENDMETHOD.

  METHOD releaseOrder.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      FAILED DATA(read_failed)
      REPORTED DATA(read_reported).
    MOVE-CORRESPONDING read_failed TO failed
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    MOVE-CORRESPONDING read_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    CHECK orders IS NOT INITIAL.

    "Saved items were validated on activation, so only their existence is checked.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Items
        FIELDS ( PurchaseOrderUUID ) WITH CORRESPONDING #( orders )
      RESULT DATA(items).

    DATA releasable LIKE orders.
    LOOP AT orders INTO DATA(order).
      DATA(blocker) = lcl_p2p_rules=>release_blocker(
        status    = order-Status
        has_items = xsdbool( line_exists( items[ %is_draft = order-%is_draft
                                                 PurchaseOrderUUID = order-PurchaseOrderUUID ] ) ) ).
      IF blocker IS INITIAL.
        APPEND order TO releasable.
      ELSE.
        APPEND VALUE #( %tky = order-%tky ) TO failed-PurchaseOrder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message_with_text(
                          severity = if_abap_behv_message=>severity-error text = blocker ) )
          TO reported-PurchaseOrder.
      ENDIF.
    ENDLOOP.
    CHECK releasable IS NOT INITIAL.

    MODIFY ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder UPDATE FIELDS ( Status )
      WITH VALUE #( FOR order_to_release IN releasable
        ( %tky = order_to_release-%tky Status = lcl_p2p_rules=>released ) )
      FAILED DATA(modify_failed)
      REPORTED DATA(modify_reported).
    MOVE-CORRESPONDING modify_failed TO failed
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    MOVE-CORRESPONDING modify_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.

    "Return the released orders so the UI shows the new status at once.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder
        ALL FIELDS WITH CORRESPONDING #( releasable )
      RESULT DATA(released_orders).
    result = VALUE #( FOR released IN released_orders
      ( %tky = released-%tky %param = released ) ).
  ENDMETHOD.

  METHOD calculateAmounts.
    "Runs on every save and in Prepare (always), so deleted items and rows saved
    "before amounts were calculated are corrected when the order is activated.
    MODIFY ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder EXECUTE recalculateAmounts
      FROM CORRESPONDING #( keys )
      REPORTED DATA(modify_reported).
    MOVE-CORRESPONDING modify_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
  ENDMETHOD.

  METHOD recalculateAmounts.
    TYPES: BEGIN OF ty_item_amount,
             is_draft TYPE abp_behv_flag,
             item_uuid TYPE sysuuid_x16,
             net_amount TYPE zp2p_poit_mf001-net_amount,
           END OF ty_item_amount,
           BEGIN OF ty_order_total,
             is_draft TYPE abp_behv_flag,
             po_uuid TYPE sysuuid_x16,
             total_amount TYPE zp2p_po_mf001-total_amount,
           END OF ty_order_total.
    DATA item_amounts TYPE STANDARD TABLE OF ty_item_amount WITH EMPTY KEY.
    DATA order_totals TYPE STANDARD TABLE OF ty_order_total WITH EMPTY KEY.
    DATA total TYPE decfloat34.

    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( TotalAmount ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders)
      FAILED DATA(read_failed)
      REPORTED DATA(read_reported).
    MOVE-CORRESPONDING read_failed TO failed
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    MOVE-CORRESPONDING read_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    CHECK orders IS NOT INITIAL.

    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Items
        FIELDS ( PurchaseOrderUUID Quantity UnitPrice NetAmount ) WITH CORRESPONDING #( orders )
      RESULT DATA(items).

    "Only changed values are written, so repeated runs settle and never loop.
    LOOP AT orders INTO DATA(order).
      total = 0.
      LOOP AT items INTO DATA(item) WHERE %is_draft = order-%is_draft
                                      AND PurchaseOrderUUID = order-PurchaseOrderUUID.
        DATA(net_amount) = lcl_p2p_rules=>net_amount( quantity = item-Quantity
                                                      unit_price = item-UnitPrice ).
        IF net_amount <> item-NetAmount.
          APPEND VALUE #( is_draft = item-%is_draft item_uuid = item-PurchaseOrderItemUUID
                          net_amount = net_amount ) TO item_amounts.
        ENDIF.
        total = total + net_amount.
      ENDLOOP.
      DATA(total_amount) = lcl_p2p_rules=>fit_amount( total ).
      IF total_amount <> order-TotalAmount.
        APPEND VALUE #( is_draft = order-%is_draft po_uuid = order-PurchaseOrderUUID
                        total_amount = total_amount ) TO order_totals.
      ENDIF.
    ENDLOOP.
    CHECK item_amounts IS NOT INITIAL OR order_totals IS NOT INITIAL.

    MODIFY ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrderItem UPDATE FIELDS ( NetAmount )
        WITH VALUE #( FOR amount IN item_amounts
          ( %is_draft = amount-is_draft PurchaseOrderItemUUID = amount-item_uuid
            NetAmount = amount-net_amount ) )
      FAILED DATA(item_failed)
      REPORTED DATA(item_reported).
    MOVE-CORRESPONDING item_failed TO failed
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    MOVE-CORRESPONDING item_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.

    MODIFY ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder UPDATE FIELDS ( TotalAmount )
        WITH VALUE #( FOR order_total IN order_totals
          ( %is_draft = order_total-is_draft PurchaseOrderUUID = order_total-po_uuid
            TotalAmount = order_total-total_amount ) )
      FAILED DATA(order_failed)
      REPORTED DATA(order_reported).
    MOVE-CORRESPONDING order_failed TO failed
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    MOVE-CORRESPONDING order_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_purchaseorderitem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR PurchaseOrderItem RESULT result.
    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseOrderItem~setDefaults.
    METHODS validateItem FOR VALIDATE ON SAVE
      IMPORTING keys FOR PurchaseOrderItem~validateItem.
    METHODS calculateNetAmount FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseOrderItem~calculateNetAmount.
    METHODS assignItemNumber FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseOrderItem~assignItemNumber.
    METHODS setItemDescription FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseOrderItem~setItemDescription.
ENDCLASS.

CLASS lhc_purchaseorderitem IMPLEMENTATION.
  METHOD get_instance_features.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrderItem BY \_PurchaseOrder
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders) LINK DATA(item_links)
      FAILED DATA(read_failed)
      REPORTED DATA(read_reported).
    MOVE-CORRESPONDING read_failed TO failed
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    MOVE-CORRESPONDING read_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.

    LOOP AT keys INTO DATA(key).
      IF line_exists( failed-PurchaseOrderItem[ %tky = key-%tky ] ).
        CONTINUE.
      ENDIF.
      DATA(editable) = if_abap_behv=>fc-o-disabled.
      READ TABLE item_links INTO DATA(item_link) WITH KEY source-%tky = key-%tky.
      IF sy-subrc = 0.
        READ TABLE orders INTO DATA(order)
          WITH KEY id COMPONENTS %tky = item_link-target-%tky.
        IF sy-subrc = 0 AND order-Status = lcl_p2p_rules=>pending.
          editable = if_abap_behv=>fc-o-enabled.
        ENDIF.
      ENDIF.
      APPEND VALUE #( %tky = key-%tky
                      %update = editable
                      %delete = editable ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrderItem
        FIELDS ( UnitCode CurrencyCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      REPORTED DATA(read_reported).
    "EML and determination responses have different derived types.
    MOVE-CORRESPONDING read_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.

    DELETE items WHERE UnitCode IS NOT INITIAL AND CurrencyCode IS NOT INITIAL.
    CHECK items IS NOT INITIAL.

    MODIFY ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrderItem UPDATE FIELDS ( UnitCode CurrencyCode )
      WITH VALUE #( FOR item IN items
        ( %tky = item-%tky
          "Only default missing codes. Never silently relabel a supplied amount.
          UnitCode = COND #( WHEN item-UnitCode IS INITIAL
                             THEN lcl_p2p_rules=>unit ELSE item-UnitCode )
          CurrencyCode = COND #( WHEN item-CurrencyCode IS INITIAL
                                 THEN lcl_p2p_rules=>currency ELSE item-CurrencyCode ) ) )
      REPORTED DATA(modify_reported).
    MOVE-CORRESPONDING modify_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
  ENDMETHOD.

  METHOD validateItem.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrderItem
        FIELDS ( PurchaseOrderUUID ItemNumber ProductID Quantity UnitPrice UnitCode CurrencyCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      FAILED DATA(read_failed)
      REPORTED DATA(read_reported).
    MOVE-CORRESPONDING read_failed TO failed
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    MOVE-CORRESPONDING read_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    CHECK items IS NOT INITIAL.

    "Own EA products only (table read, see validateHeader for why).
    DATA(owner) = cl_abap_context_info=>get_user_technical_name( ).
    DATA products TYPE SORTED TABLE OF zp2p_prod_mf001-product_id
      WITH UNIQUE KEY table_line.
    SELECT FROM zp2p_prod_mf001
      FIELDS product_id
      FOR ALL ENTRIES IN @items
      WHERE owner_id = @owner AND product_id = @items-ProductID
        AND unit_code = @lcl_p2p_rules=>unit
      INTO TABLE @products.

    "Read siblings from the transactional buffer, including unsaved changes.
    DATA parent_keys TYPE TABLE FOR READ IMPORT zi_p2p_po_mf001\_Items.
    parent_keys = VALUE #( FOR src IN items
  ( %is_draft = src-%is_draft PurchaseOrderUUID = src-PurchaseOrderUUID ) ).
    SORT parent_keys BY %is_draft PurchaseOrderUUID.
    DELETE ADJACENT DUPLICATES FROM parent_keys COMPARING %is_draft PurchaseOrderUUID.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Items
        FIELDS ( PurchaseOrderUUID ItemNumber ) WITH parent_keys
      RESULT DATA(siblings)
      FAILED DATA(parent_failed)
      REPORTED DATA(parent_reported).
    MOVE-CORRESPONDING parent_failed TO failed
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    MOVE-CORRESPONDING parent_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    DATA(duplicates) = lcl_p2p_rules=>duplicate_items( VALUE #( FOR sibling IN siblings
      ( is_draft = sibling-%is_draft po_uuid = sibling-PurchaseOrderUUID
        item_uuid = sibling-PurchaseOrderItemUUID item_number = sibling-ItemNumber ) ) ).

    LOOP AT items INTO DATA(item).
      APPEND VALUE #( %tky = item-%tky %state_area = 'ITEM'
        %path-PurchaseOrder = VALUE #( %is_draft = item-%is_draft
                                      PurchaseOrderUUID = item-PurchaseOrderUUID ) )
        TO reported-PurchaseOrderItem.
      DATA(issues) = lcl_p2p_rules=>check_item(
        item = VALUE #( item_number = item-ItemNumber product_id = item-ProductID
                        quantity = item-Quantity unit_price = item-UnitPrice
                        unit_code = item-UnitCode currency_code = item-CurrencyCode )
        product_exists = xsdbool( line_exists( products[ table_line = item-ProductID ] ) ) ).
      IF line_exists( duplicates[ is_draft = item-%is_draft
                                  item_uuid = item-PurchaseOrderItemUUID ] ).
        APPEND VALUE #( field_name = 'ITEMNUMBER'
                        text = 'Item numbers must be unique within a purchase order.' ) TO issues.
      ENDIF.
      IF issues IS NOT INITIAL.
        APPEND VALUE #( %tky = item-%tky ) TO failed-PurchaseOrderItem.
      ENDIF.
      LOOP AT issues INTO DATA(issue).
        APPEND VALUE #( %tky = item-%tky %state_area = 'ITEM'
          %path-PurchaseOrder = VALUE #( %is_draft = item-%is_draft
                                        PurchaseOrderUUID = item-PurchaseOrderUUID )
          %msg = new_message_with_text(
            severity = if_abap_behv_message=>severity-error text = issue-text ) )
          TO reported-PurchaseOrderItem ASSIGNING FIELD-SYMBOL(<message>).
        CASE issue-field_name.
          WHEN 'ITEMNUMBER'. <message>-%element-ItemNumber = if_abap_behv=>mk-on.
          WHEN 'PRODUCTID'. <message>-%element-ProductID = if_abap_behv=>mk-on.
          WHEN 'QUANTITY'. <message>-%element-Quantity = if_abap_behv=>mk-on.
          WHEN 'UNITPRICE'. <message>-%element-UnitPrice = if_abap_behv=>mk-on.
          WHEN 'UNITCODE'. <message>-%element-UnitCode = if_abap_behv=>mk-on.
          WHEN 'CURRENCYCODE'. <message>-%element-CurrencyCode = if_abap_behv=>mk-on.
        ENDCASE.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD calculateNetAmount.
    "The order recalculates all its item amounts and its total in one place.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrderItem
        FIELDS ( PurchaseOrderUUID ) WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      REPORTED DATA(read_reported).
    "EML and determination responses have different derived types.
    MOVE-CORRESPONDING read_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    CHECK items IS NOT INITIAL.

    DATA order_keys TYPE TABLE FOR ACTION IMPORT zi_p2p_po_mf001~recalculateAmounts.
    order_keys = VALUE #( FOR item IN items
      ( %is_draft = item-%is_draft PurchaseOrderUUID = item-PurchaseOrderUUID ) ).
    SORT order_keys BY %is_draft PurchaseOrderUUID.
    DELETE ADJACENT DUPLICATES FROM order_keys COMPARING %is_draft PurchaseOrderUUID.

    MODIFY ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder EXECUTE recalculateAmounts FROM order_keys
      REPORTED DATA(modify_reported).
    MOVE-CORRESPONDING modify_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
  ENDMETHOD.

  METHOD assignItemNumber.
    "Proposes the next number (highest + 10) for new items left without one.
    "The number stays editable; validateItem still rejects duplicates.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrderItem
        FIELDS ( PurchaseOrderUUID ItemNumber ) WITH CORRESPONDING #( keys )
      RESULT DATA(new_items)
      REPORTED DATA(read_reported).
    "EML and determination responses have different derived types.
    MOVE-CORRESPONDING read_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    DELETE new_items WHERE ItemNumber IS NOT INITIAL.
    CHECK new_items IS NOT INITIAL.

    "Read siblings from the transactional buffer, including unsaved items.
    DATA parent_keys TYPE TABLE FOR READ IMPORT zi_p2p_po_mf001\_Items.
    parent_keys = VALUE #( FOR src IN new_items
      ( %is_draft = src-%is_draft PurchaseOrderUUID = src-PurchaseOrderUUID ) ).
    SORT parent_keys BY %is_draft PurchaseOrderUUID.
    DELETE ADJACENT DUPLICATES FROM parent_keys COMPARING %is_draft PurchaseOrderUUID.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder BY \_Items
        FIELDS ( PurchaseOrderUUID ItemNumber ) WITH parent_keys
      RESULT DATA(siblings).

    "Highest number per order; raised as numbers are handed out below.
    TYPES: BEGIN OF ty_highest,
             is_draft TYPE abp_behv_flag,
             po_uuid TYPE sysuuid_x16,
             item_number TYPE zp2p_poit_mf001-item_number,
           END OF ty_highest,
           BEGIN OF ty_item_number,
             is_draft TYPE abp_behv_flag,
             item_uuid TYPE sysuuid_x16,
             item_number TYPE zp2p_poit_mf001-item_number,
           END OF ty_item_number.
    DATA highest TYPE HASHED TABLE OF ty_highest WITH UNIQUE KEY is_draft po_uuid.
    DATA item_numbers TYPE STANDARD TABLE OF ty_item_number WITH EMPTY KEY.
    LOOP AT siblings INTO DATA(sibling).
      ASSIGN highest[ is_draft = sibling-%is_draft po_uuid = sibling-PurchaseOrderUUID ]
        TO FIELD-SYMBOL(<highest>).
      IF sy-subrc <> 0.
        INSERT VALUE #( is_draft = sibling-%is_draft po_uuid = sibling-PurchaseOrderUUID )
          INTO TABLE highest ASSIGNING <highest>.
      ENDIF.
      IF sibling-ItemNumber > <highest>-item_number.
        <highest>-item_number = sibling-ItemNumber.
      ENDIF.
    ENDLOOP.

    LOOP AT new_items INTO DATA(new_item).
      ASSIGN highest[ is_draft = new_item-%is_draft po_uuid = new_item-PurchaseOrderUUID ]
        TO <highest>.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      DATA(next_number) = lcl_p2p_rules=>next_item_number( <highest>-item_number ).
      IF next_number IS INITIAL.
        CONTINUE.
      ENDIF.
      <highest>-item_number = next_number.
      APPEND VALUE #( is_draft = new_item-%is_draft item_uuid = new_item-PurchaseOrderItemUUID
                      item_number = next_number ) TO item_numbers.
    ENDLOOP.
    CHECK item_numbers IS NOT INITIAL.

    MODIFY ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrderItem UPDATE FIELDS ( ItemNumber )
      WITH VALUE #( FOR item_number IN item_numbers
        ( %is_draft = item_number-is_draft PurchaseOrderItemUUID = item_number-item_uuid
          ItemNumber = item_number-item_number ) )
      REPORTED DATA(modify_reported).
    MOVE-CORRESPONDING modify_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
  ENDMETHOD.

  METHOD setItemDescription.
    "Choosing a product fills the description with the product name, like the
    "short text in SAP purchase orders. It can be overwritten afterwards.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrderItem
        FIELDS ( ProductID ItemDescription ) WITH CORRESPONDING #( keys )
      RESULT DATA(items)
      REPORTED DATA(read_reported).
    "EML and determination responses have different derived types.
    MOVE-CORRESPONDING read_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
    DELETE items WHERE ProductID IS INITIAL.
    CHECK items IS NOT INITIAL.

    "Own EA products only (table read, see validateHeader for why).
    DATA(owner) = cl_abap_context_info=>get_user_technical_name( ).
    SELECT FROM zp2p_prod_mf001
      FIELDS product_id AS ProductID, product_name AS ProductName
      FOR ALL ENTRIES IN @items
      WHERE owner_id = @owner AND product_id = @items-ProductID
        AND unit_code = @lcl_p2p_rules=>unit
      INTO TABLE @DATA(products).

    TYPES: BEGIN OF ty_description,
             is_draft TYPE abp_behv_flag,
             item_uuid TYPE sysuuid_x16,
             description TYPE zp2p_poit_mf001-description,
           END OF ty_description.
    DATA descriptions TYPE STANDARD TABLE OF ty_description WITH EMPTY KEY.
    LOOP AT items INTO DATA(item).
      READ TABLE products INTO DATA(product) WITH KEY ProductID = item-ProductID.
      IF sy-subrc = 0 AND product-ProductName <> item-ItemDescription.
        APPEND VALUE #( is_draft = item-%is_draft item_uuid = item-PurchaseOrderItemUUID
                        description = product-ProductName ) TO descriptions.
      ENDIF.
    ENDLOOP.
    CHECK descriptions IS NOT INITIAL.

    MODIFY ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrderItem UPDATE FIELDS ( ItemDescription )
      WITH VALUE #( FOR description IN descriptions
        ( %is_draft = description-is_draft PurchaseOrderItemUUID = description-item_uuid
          ItemDescription = description-description ) )
      REPORTED DATA(modify_reported).
    MOVE-CORRESPONDING modify_reported TO reported
      EXPANDING NESTED TABLES KEEPING TARGET LINES.
  ENDMETHOD.
ENDCLASS.
