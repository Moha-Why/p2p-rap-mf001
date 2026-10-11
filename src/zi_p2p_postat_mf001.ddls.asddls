@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'P2P purchase order status'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_P2P_POSTAT_MF001
  as select from zp2p_stat_mf001
{
      @ObjectModel.text.element: ['StatusText']
      @UI.textArrangement: #TEXT_ONLY
  key status      as Status,
      @Semantics.text: true
      status_text as StatusText,
      //Fiori criticality: 2 = critical (orange), 3 = positive (green)
      @UI.hidden: true
      case status
        when 'R' then 3
        when 'N' then 2
        else 0
      end         as Criticality
}
