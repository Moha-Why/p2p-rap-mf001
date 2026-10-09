CLASS lhc_purchaseorder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR PurchaseOrder RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR PurchaseOrder RESULT result.
    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseOrder~setDefaults.
ENDCLASS.

CLASS lhc_purchaseorder IMPLEMENTATION.
  METHOD get_instance_authorizations.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( CreatedBy Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA(owner) = cl_abap_context_info=>get_user_technical_name( ).
    LOOP AT orders INTO DATA(order).
      "For a new draft the active-record creation user may not yet be populated.
      "RAP additionally enforces exclusive draft ownership through its admin data.
      DATA(own_order) = xsdbool(
        order-CreatedBy = owner OR
        ( order-CreatedBy IS INITIAL AND order-%is_draft = if_abap_behv=>mk-on ) ).
      DATA(editable) = xsdbool( own_order = abap_true AND
        ( order-Status = 'N' OR
          ( order-Status IS INITIAL AND order-%is_draft = if_abap_behv=>mk-on ) ) ).
      DATA(permission) = COND #( WHEN editable = abap_true
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
      RESULT DATA(orders).

    result = VALUE #( FOR order IN orders
      LET editable = COND #( WHEN order-Status = 'N' OR order-Status IS INITIAL
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
      RESULT DATA(orders).

    MODIFY ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrder UPDATE FIELDS ( Status CurrencyCode OrderDate )
      WITH VALUE #( FOR order IN orders
        ( %tky = order-%tky
          Status = COND #( WHEN order-Status IS INITIAL THEN 'N' ELSE order-Status )
          CurrencyCode = COND #( WHEN order-CurrencyCode IS INITIAL
                                 THEN 'EGP' ELSE order-CurrencyCode )
          OrderDate = COND #( WHEN order-OrderDate IS INITIAL
                              THEN cl_abap_context_info=>get_system_date( )
                              ELSE order-OrderDate ) ) )
      REPORTED DATA(modify_reported).
    reported = CORRESPONDING #( DEEP modify_reported ).
  ENDMETHOD.
ENDCLASS.

CLASS lhc_purchaseorderitem DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR PurchaseOrderItem RESULT result.
    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseOrderItem~setDefaults.
ENDCLASS.

CLASS lhc_purchaseorderitem IMPLEMENTATION.
  METHOD get_instance_features.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrderItem BY \_PurchaseOrder
        FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(orders) LINK DATA(item_links).

    LOOP AT keys INTO DATA(key).
      DATA(editable) = if_abap_behv=>fc-o-disabled.
      READ TABLE item_links INTO DATA(item_link) WITH KEY %source = key-%tky.
      IF sy-subrc = 0.
        READ TABLE orders INTO DATA(order) WITH KEY %tky = item_link-%target.
        IF sy-subrc = 0 AND ( order-Status = 'N' OR order-Status IS INITIAL ).
          editable = if_abap_behv=>fc-o-enabled.
        ENDIF.
      ENDIF.
      APPEND VALUE #( %tky = key-%tky %update = editable %delete = editable ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD setDefaults.
    READ ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrderItem
        FIELDS ( UnitCode CurrencyCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    MODIFY ENTITIES OF zi_p2p_po_mf001 IN LOCAL MODE
      ENTITY PurchaseOrderItem UPDATE FIELDS ( UnitCode CurrencyCode )
      WITH VALUE #( FOR item IN items
        ( %tky = item-%tky
          UnitCode = COND #( WHEN item-UnitCode IS INITIAL THEN 'EA' ELSE item-UnitCode )
          CurrencyCode = COND #( WHEN item-CurrencyCode IS INITIAL
                                 THEN 'EGP' ELSE item-CurrencyCode ) ) )
      REPORTED DATA(modify_reported).
    reported = CORRESPONDING #( DEEP modify_reported ).
  ENDMETHOD.
ENDCLASS.
