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
      @ObjectModel.text.element: ['SupplierName']
      @Consumption.valueHelpDefinition: [{ entity: {
        name: 'ZI_P2P_SUPP_MF001', element: 'SupplierID' }, useForValidation: true }]
      SupplierID,
      _Supplier.SupplierName as SupplierName,
      OrderDate,
      CurrencyCode,
      @ObjectModel.text.element: ['StatusText']
      @Consumption.valueHelpDefinition: [{ entity: {
        name: 'ZI_P2P_POSTAT_MF001', element: 'Status' } }]
      Status,
      _StatusInfo.StatusText as StatusText,
      _StatusInfo.Criticality as StatusCriticality,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      TotalAmount,
      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,
      _Items : redirected to composition child ZC_P2P_POIT_MF001
}
