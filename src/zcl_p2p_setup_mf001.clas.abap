CLASS zcl_p2p_setup_mf001 DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_p2p_setup_mf001 IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    "One-time setup of the purchase order number interval. Safe to run again:
    "an existing interval is reported and left unchanged.
    CONSTANTS object TYPE cl_numberrange_runtime=>nr_object VALUE 'ZP2P_MF001'.
    CONSTANTS interval TYPE cl_numberrange_runtime=>nr_interval VALUE '01'.
    "Interval limits have exactly the 7 digits of domain ZP2P_PONR_MF001.
    CONSTANTS from_number TYPE cl_numberrange_intervals=>nr_nriv_line-fromnumber VALUE '0000001'.
    CONSTANTS to_number TYPE cl_numberrange_intervals=>nr_nriv_line-tonumber VALUE '9999999'.

    TRY.
        cl_numberrange_intervals=>read(
          EXPORTING object    = object
                    subobject = VALUE #( )
          IMPORTING interval  = DATA(intervals) ).
        IF line_exists( intervals[ nrrangenr = interval ] ).
          out->write( |Order number interval { interval } already exists. Nothing changed.| ).
          RETURN.
        ENDIF.

        cl_numberrange_intervals=>create(
          EXPORTING interval  = VALUE #( ( nrrangenr  = interval
                                           fromnumber = from_number
                                           tonumber   = to_number
                                           procind    = 'I' ) )
                    object    = object
                    subobject = VALUE #( ) ).
        COMMIT WORK.

        "Confirm instead of assuming that the create call succeeded.
        cl_numberrange_intervals=>read(
          EXPORTING object    = object
                    subobject = VALUE #( )
          IMPORTING interval  = intervals ).
        IF line_exists( intervals[ nrrangenr = interval ] ).
          out->write( |Order number interval { interval } created: PO-{ from_number } to PO-{ to_number }.| ).
        ELSE.
          out->write( |Order number interval { interval } was not created. Check number range object { object }.| ).
        ENDIF.
      CATCH cx_number_ranges INTO DATA(error).
        ROLLBACK WORK.
        out->write( |Number range setup failed: { error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.
ENDCLASS.
