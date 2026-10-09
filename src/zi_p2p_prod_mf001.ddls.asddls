@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'P2P product selection'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_P2P_PROD_MF001
  as select from zp2p_prod_mf001
{
      @UI.hidden: true
  key owner_id as OwnerID,
      @Search.defaultSearchElement: true
      @ObjectModel.text.element: ['ProductName']
  key product_id as ProductID,
      @Search.defaultSearchElement: true
      product_name as ProductName,
      unit_code as UnitCode
}
