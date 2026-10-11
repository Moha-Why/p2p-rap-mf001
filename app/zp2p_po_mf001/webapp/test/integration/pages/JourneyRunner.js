sap.ui.define([
    "sap/fe/test/JourneyRunner",
	"zp2ppomf001/test/integration/pages/PurchaseOrdersList.gen",
	"zp2ppomf001/test/integration/pages/PurchaseOrdersObjectPage.gen",
	"zp2ppomf001/test/integration/pages/PurchaseOrderItemsObjectPage.gen"
], function (JourneyRunner, PurchaseOrdersListGenerated, PurchaseOrdersObjectPageGenerated, PurchaseOrderItemsObjectPageGenerated) {
    'use strict';

    const runner = new JourneyRunner({
        launchUrl: sap.ui.require.toUrl('zp2ppomf001') + '/test/flp.html#app-preview',
        pages: {
			onThePurchaseOrdersListGenerated: PurchaseOrdersListGenerated,
			onThePurchaseOrdersObjectPageGenerated: PurchaseOrdersObjectPageGenerated,
			onThePurchaseOrderItemsObjectPageGenerated: PurchaseOrderItemsObjectPageGenerated
        },
        async: true
    });

    return runner;
});

