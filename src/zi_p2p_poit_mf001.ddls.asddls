@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'P2P purchase order item interface'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_P2P_POIT_MF001
  as select from zp2p_poit_mf001
  association to parent ZI_P2P_PO_MF001 as _PurchaseOrder
    on $projection.PurchaseOrderUUID = _PurchaseOrder.PurchaseOrderUUID
  association [0..1] to ZI_P2P_PROD_MF001 as _Product
    on  $projection.ProductID = _Product.ProductID
    and $projection.CreatedBy = _Product.OwnerID
{
  key item_uuid         as PurchaseOrderItemUUID,
      po_uuid           as PurchaseOrderUUID,
      item_number       as ItemNumber,
      product_id        as ProductID,
      description       as ItemDescription,
      unit_code         as UnitCode,
      currency_code     as CurrencyCode,
      @Semantics.quantity.unitOfMeasure: 'UnitCode'
      quantity          as Quantity,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      unit_price        as UnitPrice,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      net_amount        as NetAmount,
      @Semantics.user.createdBy: true
      created_by        as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at        as CreatedAt,
      @Semantics.user.lastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at   as LastChangedAt,
      _PurchaseOrder,
      _Product
}
