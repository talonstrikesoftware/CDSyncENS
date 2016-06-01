//
//  Entity.swift
//  CDSync
//
//  Copyright (c) 2015 Talon Strike Software. All rights reserved.
//

import Foundation
import CoreData

class Entity: NSManagedObject {

    @NSManaged var name: String
    @NSManaged var desctext: String
    @NSManaged var uniqueIdentifier: String?
    @NSManaged var creationDate: NSDate?

    override func awakeFromInsert() {
        super.awakeFromInsert()
        if let uniqueIdentifier = uniqueIdentifier {
            
        }
        else {
            self.uniqueIdentifier = NSProcessInfo.processInfo().globallyUniqueString
            self.creationDate = NSDate()
        }
    }
}
