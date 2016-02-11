//
//  SitesTableInterfaceController.swift
//  Nightscouter
//
//  Created by Peter Ina on 10/4/15.
//  Copyright © 2015 Peter Ina. All rights reserved.
//

import WatchKit
import NightscouterWatchOSKit

class SitesTableInterfaceController: WKInterfaceController, DataSourceChangedDelegate, SiteDetailViewDidUpdateItemDelegate {
    
    @IBOutlet var sitesTable: WKInterfaceTable!
    
    var models: [WatchModel] = WatchSessionManager.sharedManager.models
    
    var nsApi: [NightscoutAPIClient]?
    
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        print(">>> Entering \(__FUNCTION__) <<<")
        
        WatchSessionManager.sharedManager.addDataSourceChangedDelegate(self)
    }
    
    override func willActivate() {
        super.willActivate()
        print(">>> Entering \(__FUNCTION__) <<<")
        
        setupNotifications()
        updateTableData()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        print(">>> Entering \(__FUNCTION__) <<<")
        super.didDeactivate()
        
        WatchSessionManager.sharedManager.removeDataSourceChangedDelegate(self)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    func setupNotifications() {
        // Listen for global update timer.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("dataStaleUpdate:"), name: NightscoutAPIClientNotification.DataIsStaleUpdateNow, object: nil)
    }
    
    override func table(table: WKInterfaceTable, didSelectRowAtIndex rowIndex: Int) {
        // create object.
        // push controller...
        print(">>> Entering \(__FUNCTION__) <<<")
        let model = models[rowIndex]
        
        pushControllerWithName("SiteDetail", context: [WatchModel.PropertyKey.delegateKey: self, WatchModel.PropertyKey.modelKey: model.dictionary])
    }
    
    private func updateTableData() {
        NSOperationQueue.mainQueue().addOperationWithBlock { () -> Void in
            print(">>> Entering \(__FUNCTION__) <<<")
            
            let rowSiteTypeIdentifier: String = "SiteRowController"
            let rowEmptyTypeIdentifier: String = "SiteEmptyRowController"
            
            if self.models.isEmpty {
                self.sitesTable.setNumberOfRows(1, withRowType: rowEmptyTypeIdentifier)
                let row = self.sitesTable.rowControllerAtIndex(0) as? SiteEmptyRowController
                if let row = row {
                    row.messageLabel.setText("No sites availble.")
                }
                
            } else {
                self.sitesTable.setNumberOfRows(self.models.count, withRowType: rowSiteTypeIdentifier)
                for (index, model) in self.models.enumerate() {
                    if let row = self.sitesTable.rowControllerAtIndex(index) as? SiteRowController {
                        row.model = model
                    }
                }
            }
        }
    }
    
    func dataSourceDidUpdateAppContext(models: [WatchModel]) {
        updateTableData()
    }
    
    func didUpdateItem(model: WatchModel) {
        print(">>> Entering \(__FUNCTION__) <<<")
        WatchSessionManager.sharedManager.updateModel(model)
    }
    
    func dataStaleUpdate(notif: NSNotification) {
        updateData(forceRefresh: false)
    }
    
    func updateData(forceRefresh refresh: Bool) {
        print(">>> Entering \(__FUNCTION__) <<<")
        
        var sessionReachable :Bool = false
        
        if #available(iOSApplicationExtension 9.0, *) {
            sessionReachable = WatchSessionManager.sharedManager.requestLatestAppContext(watchAction: .AppContext)
        }
        
        if !sessionReachable {
            for (index, model) in models.enumerate() {
                if (model.lastReadingDate.timeIntervalSinceNow < Constants.NotableTime.StandardRefreshTime.inThePast) || refresh {
                    fetchSiteData(forSite: model.generateSite(), index: index, forceRefresh: refresh, handler: { (reloaded, returnedSite, returnedIndex, returnedError) -> Void in
                        
                        NSOperationQueue.mainQueue().addOperationWithBlock({ () -> Void in
                            let updatedModel = returnedSite.viewModel
                            WatchSessionManager.sharedManager.updateModel(updatedModel)
                        })
                    })
                }
            }
        }
    }
    
    @IBAction func updateButton() {
        updateData(forceRefresh: true)
    }
    
    override func handleUserActivity(userInfo: [NSObject : AnyObject]?) {
        print(">>> Entering \(__FUNCTION__) <<<")
        
        guard let dict = userInfo?[WatchModel.PropertyKey.modelKey] as? [String : AnyObject], incomingModel = WatchModel (fromDictionary: dict) else {
            return
        }
        
        NSOperationQueue.mainQueue().addOperationWithBlock {
            self.dismissController()
            self.pushControllerWithName("SiteDetail", context: [WatchModel.PropertyKey.delegateKey: self, WatchModel.PropertyKey.modelKey: incomingModel.dictionary])
        }
    }
}

