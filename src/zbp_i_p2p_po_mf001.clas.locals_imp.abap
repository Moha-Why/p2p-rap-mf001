CLASS lcl_p2p_rules IMPLEMENTATION.
  METHOD check_header.
    IF header-po_number IS INITIAL.
      APPEND VALUE #( field_name = 'PURCHASEORDERNUMBER'
                      text = 'Enter an order reference.' ) TO issues.
    ELSEIF number_taken = abap_true.
      APPEND VALUE #( field_name = 'PURCHASEORDERNUMBER'
                      text = 'Another of your orders already uses this order reference.' ) TO issues.
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
    IF CONV decfloat34( item-quantity ) * CONV decfloat34( item-unit_price ) > CONV decfloat34( '9999999999999.99' ).
      APPEND VALUE #( field_name = 'UNITPRICE'
                      text = 'Quantity times price exceeds the supported amount size.' ) TO issues.
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

    result = VALUE #( FOR order IN orders
      LET editable = COND #( WHEN order-Status = lcl_p2p_rules=>pending
                             THEN if_abap_behv=>fc-o-enabled
                             ELSE if_abap_behv=>fc-o-disabled )
      IN ( %tky = order-%tky
           %update = editable
           %delete = editable
           %action-Edit = editable
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

    "The CDS access roles restrict both selects to the current user's own rows.
    DATA suppliers TYPE SORTED TABLE OF zp2p_supp_mf001-supplier_id
      WITH UNIQUE KEY table_line.
    SELECT FROM zi_p2p_supp_mf001
      FIELDS SupplierID
      FOR ALL ENTRIES IN @orders
      WHERE SupplierID = @orders-SupplierID
      INTO TABLE @suppliers.

    "Order references must be unique among the user's active orders. Editing an
    "existing order keeps its UUID, so the order never clashes with itself.
    SELECT FROM zi_p2p_po_mf001
      FIELDS PurchaseOrderUUID, PurchaseOrderNumber
      FOR ALL ENTRIES IN @orders
      WHERE PurchaseOrderNumber = @orders-PurchaseOrderNumber
        AND PurchaseOrderUUID <> @orders-PurchaseOrderUUID
      INTO TABLE @DATA(clashes).

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
        number_taken = number_taken ).
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
        ENDCASE.
      ENDLOOP.
    ENDLOOP.
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

    "The CDS view admits only EA products; its access role admits only own rows.
    DATA products TYPE SORTED TABLE OF zp2p_prod_mf001-product_id
      WITH UNIQUE KEY table_line.
    SELECT FROM zi_p2p_prod_mf001
      FIELDS ProductID
      FOR ALL ENTRIES IN @items
      WHERE ProductID = @items-ProductID
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
ENDCLASS.

