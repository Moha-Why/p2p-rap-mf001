@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'P2P purchase orders'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_P2P_PO_MF001
  provider contract transactional_query
  as projection on ZI_P2P_PO_MF001
{
  key PurchaseOrderUUID,
      @Search.defaultSearchElement: true
      PurchaseOrderNumber,
      @Consumption.valueHelpDefinition: [{ entity: {
        name: 'ZI_P2P_SUPP_MF001', element: 'SupplierID' }, useForValidation: true }]
      SupplierID,
      OrderDate,
      CurrencyCode,
      Status,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      TotalAmount,
      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,
      _Items : redirected to composition child ZC_P2P_POIT_MF001
}
