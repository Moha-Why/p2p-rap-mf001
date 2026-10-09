@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'P2P purchase order interface'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_P2P_PO_MF001
  as select from zp2p_po_mf001
  composition [0..*] of ZI_P2P_POIT_MF001 as _Items
{
  key po_uuid           as PurchaseOrderUUID,
      po_number         as PurchaseOrderNumber,
      supplier_id       as SupplierID,
      order_date        as OrderDate,
      currency_code     as CurrencyCode,
      status            as Status,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_amount      as TotalAmount,
      @Semantics.user.createdBy: true
      created_by        as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at        as CreatedAt,
      @Semantics.user.lastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at as LastChangedAt,
      _Items
}
