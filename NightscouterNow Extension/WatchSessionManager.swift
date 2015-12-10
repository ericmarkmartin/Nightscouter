//
//  WatchSessionManager.swift
//  WCApplicationContextDemo
//
//  Created by Natasha Murashev on 9/22/15.
//  Copyright © 2015 NatashaTheRobot. All rights reserved.
//

import WatchConnectivity
import ClockKit

@available(watchOS 2.0, *)
public protocol DataSourceChangedDelegate {
    func dataSourceDidUpdateAppContext(models: [WatchModel])
    func dataSourceDidUpdateSiteModel(model: WatchModel, atIndex index: Int)
    func dataSourceDidAddSiteModel(model: WatchModel, atIndex index: Int)
    func dataSourceDidDeleteSiteModel(model: WatchModel, atIndex index: Int)
}

public protocol ModelDataSourceChangedDelegate {
    func dataSourceDidChange(withAction action: WatchAction, forModel model: WatchModel, atIndex index: Int)
}

@available(watchOS 2.0, *)
public class WatchSessionManager: NSObject, WCSessionDelegate {
    
    public static let sharedManager = WatchSessionManager()
    private override init() {
        super.init()
        
        if let dictArray = NSUserDefaults.standardUserDefaults().objectForKey(WatchModel.PropertyKey.modelsKey) as? [[String: AnyObject]] {
            print("Loading models from default.")
            models = dictArray.map({ WatchModel(fromDictionary: $0)! })
        }
        
    }
    
    private var dataSourceChangedDelegates = [DataSourceChangedDelegate]()
    
    private let session: WCSession = WCSession.defaultSession()
    
    private var sites: [Site] = []
    private var models: [WatchModel] = [] {
        didSet {
            let dictArray = models.map({ $0.dictionary })
            NSUserDefaults.standardUserDefaults().setObject(dictArray, forKey: WatchModel.PropertyKey.modelsKey)
            // NSUserDefaults.standardUserDefaults().removeObjectForKey(WatchModel.PropertyKey.modelsKey)
            NSUserDefaults.standardUserDefaults().synchronize()
        }
    }
    
    
    public func startSession() {
        if WCSession.isSupported() {
            session.delegate = self
            session.activateSession()
        }
        
        /*
        let complicationServer = CLKComplicationServer.sharedInstance()
        for complication in complicationServer.activeComplications {
        complicationServer.reloadTimelineForComplication(complication)
        }
        */
        
    }
    
    public func addDataSourceChangedDelegate<T where T: DataSourceChangedDelegate, T: Equatable>(delegate: T) {
        dataSourceChangedDelegates.append(delegate)
    }
    
    public func removeDataSourceChangedDelegate<T where T: DataSourceChangedDelegate, T: Equatable>(delegate: T) {
        for (index, indexDelegate) in dataSourceChangedDelegates.enumerate() {
            if let indexDelegate = indexDelegate as? T where indexDelegate == delegate {
                dataSourceChangedDelegates.removeAtIndex(index)
                break
            }
        }
    }
}

// MARK: Application Context
// use when your app needs only the latest information
// if the data was not sent, it will be replaced
extension WatchSessionManager {
    public func session(session: WCSession, didReceiveFile file: WCSessionFile) {
        // print("didReceiveFile: \(file)")
        dispatch_async(dispatch_get_main_queue()) {
            // make sure to put on the main queue to update UI!
        }
    }
    
    public func session(session: WCSession, didReceiveUserInfo userInfo: [String : AnyObject]) {
        print("didReceiveUserInfo: \(userInfo)")
        processApplicationContext(userInfo)
    }
    
    // Receiver
    public func session(session: WCSession, didReceiveApplicationContext applicationContext: [String : AnyObject]) {
        print("didReceiveApplicationContext: \(applicationContext)")
        processApplicationContext(applicationContext)
    }
    
    public func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Void) {
        
        let success =   processApplicationContext(message)
        replyHandler(["response" : "The message was procssed correctly: \(success)"])
    }
    
}

extension WatchSessionManager {
    public func requestLatestAppContext() -> Bool {
        print("requestLatestAppContext")
        let applicationData = [WatchModel.PropertyKey.actionKey: WatchAction.AppContext.rawValue]
        
        var returnBool = false
        
        session.sendMessage(applicationData, replyHandler: {(context:[String : AnyObject]) -> Void in
            // handle reply from iPhone app here
            
            print("recievedMessageReply: \(context)")
            returnBool = self.processApplicationContext(context)
            
            }, errorHandler: {(error ) -> Void in
                // catch any errors here
                print("error: \(error)")
                
                returnBool = false
        })
        return returnBool
    }
    
    func processApplicationContext(context: [String : AnyObject]) -> Bool {
        print("processApplicationContext \(context)")
        
        guard let action = WatchAction(rawValue: (context[WatchModel.PropertyKey.actionKey] as? String)!) else {
            print("No action was found, didReceiveMessage: \(context)")
            return false
        }
        
        switch action {
            
        case .Update:
            print("update on watch framework")
            
            if let modelArray = context[WatchModel.PropertyKey.modelsKey] as? [[String: AnyObject]]{//, model = WatchModel(fromDictionary: modelDict) {
                for modelDict in modelArray {
                    
                    if let model = WatchModel(fromDictionary: modelDict) {
                        if let pos = models.indexOf(model){
                            models[pos] = model
                            dispatch_async(dispatch_get_main_queue()) { [weak self] in
                                self?.dataSourceChangedDelegates.forEach { $0.dataSourceDidUpdateSiteModel(model, atIndex: pos) }
                            }
                            
                        } else {
                            models.append(model)
                            dispatch_async(dispatch_get_main_queue()) { [weak self] in
                                self?.dataSourceChangedDelegates.forEach { $0.dataSourceDidAddSiteModel(model, atIndex: self!.models.count)}
                            }
                            
                        }
                    }
                }
            }
        case .Delete:
            if let modelArray = context[WatchModel.PropertyKey.modelsKey] as? [[String: AnyObject]]{//, model = WatchModel(fromDictionary: modelDict) {
                
                for modelDict in modelArray {
                    let model = WatchModel(fromDictionary: modelDict)!
                    
                    if let pos = models.indexOf(model){
                        models.removeAtIndex(pos)
                        dispatch_async(dispatch_get_main_queue()) { [weak self] in
                            self?.dataSourceChangedDelegates.forEach { $0.dataSourceDidDeleteSiteModel(model, atIndex: pos) }
                        }
                    }
                }
            }
        case .AppContext:
            if let modelArray = context[WatchModel.PropertyKey.modelsKey] as? [[String: AnyObject]] {
                models.removeAll()
                for modelDict in modelArray {
                    let model = WatchModel(fromDictionary: modelDict)!
                    models.append(model)
                }
                dispatch_async(dispatch_get_main_queue()) { [weak self] in
                    self?.dataSourceChangedDelegates.forEach { $0.dataSourceDidUpdateAppContext((self?.models)!) }
                }
            }
            
            
        default:
            break
        }
        
        return true
    }
    
}