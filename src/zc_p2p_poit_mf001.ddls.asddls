@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'P2P purchase order items'
@Metadata.allowExtensions: true
define view entity ZC_P2P_POIT_MF001
  as projection on ZI_P2P_POIT_MF001
{
  key PurchaseOrderItemUUID,
      PurchaseOrderUUID,
      ItemNumber,
      @Consumption.valueHelpDefinition: [{ entity: {
        name: 'ZI_P2P_PROD_MF001', element: 'ProductID' }, useForValidation: true }]
      ProductID,
      ItemDescription,
      UnitCode,
      CurrencyCode,
      @Semantics.quantity.unitOfMeasure: 'UnitCode'
      Quantity,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      UnitPrice,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      NetAmount,
      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,
      _PurchaseOrder : redirected to parent ZC_P2P_PO_MF001
}
