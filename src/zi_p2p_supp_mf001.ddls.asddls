@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'P2P supplier selection'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_P2P_SUPP_MF001
  as select from zp2p_supp_mf001
{
      @UI.hidden: true
  key owner_id as OwnerID,
      @Search.defaultSearchElement: true
      @ObjectModel.text.element: ['SupplierName']
  key supplier_id as SupplierID,
      @Search.defaultSearchElement: true
      supplier_name as SupplierName
}
