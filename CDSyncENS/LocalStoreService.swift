//
//  LocalStoreService.swift
//  CDSync
//
//  Copyright (c) 2015 Talon Strike Software. All rights reserved.
//

import UIKit

class LocalStoreService: NSObject {
    
    class var sharedInstance: LocalStoreService {
        struct Singleton {
            static let instance = LocalStoreService()
        }
        return Singleton.instance
    }
    
    let KEY_SYNC_TO_CLOUD = "keySyncToCloud"
    let KEY_LAST_COUNT = "keyLastCount"
    
    
    var syncToCloud: Bool {
        get {
            let defaults = NSUserDefaults.standardUserDefaults()
            return defaults.boolForKey(KEY_SYNC_TO_CLOUD)
        }
        set(shouldSync) {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setBool(shouldSync, forKey: KEY_SYNC_TO_CLOUD)
        }
    }
    
    var lastCount: Int? {
        get {
            let defaults = NSUserDefaults.standardUserDefaults()
            return defaults.integerForKey(KEY_LAST_COUNT)
        }
        set(lastCount) {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setInteger(lastCount!, forKey: KEY_LAST_COUNT)
        }
    }
}
