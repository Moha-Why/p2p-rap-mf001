CLASS zcl_p2p_start_mf001 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_p2p_start_mf001 IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    out->write( 'P2P milestone 1: OK' ).
    out->write( 'Custom SAP BTP ABAP application' ).
    out->write( 'Next milestone: purchase-order data model' ).
  ENDMETHOD.
ENDCLASS.
