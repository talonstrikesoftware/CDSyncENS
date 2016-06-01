//
//  CoreDataStack.swift
//  CDSync
//
//  Copyright (c) 2015 Talon Strike Software. All rights reserved.
//  Version 4/15/2015
//

import CoreData
import UIKit

let STORE_SWITCH_COMPLETED = "StoreSwitchCompleted"
let SYNC_ACTIVITY_DID_BEGIN = "SyncActivityDidBegin"
let SYNC_ACTIVITY_DID_END = "SyncActivityDidEnd"

// http://digitalleaves.com/blog/2014/08/i-give-up-with-icloud-coredata
@objc class CDEStack : NSObject, CDEPersistentStoreEnsembleDelegate {
    private var mainQueueMOC:NSManagedObjectContext?
    //    private var privateMOC:NSManagedObjectContext?
    private var psc:NSPersistentStoreCoordinator?
    private var model:NSManagedObjectModel?
    private var modelURL:NSURL?
    private let modelName:String

    private var store:NSPersistentStore?
    private var rebuildFromCloudStore = false
    private var ensemble:CDEPersistentStoreEnsemble?
    
    private var activeMergeCount:Int = 0

//    class var sharedInstance: CDEStack {
//        struct Singleton {
//            static let instance = CDEStack()
//        }
//        return Singleton.instance
//    }

    var context:NSManagedObjectContext {
        get {
            return mainQueueMOC!
        }
    }

    // Computed properties
    private var storeOptions : [NSObject: AnyObject] {
        return [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        // TODO: May need to add NSPersistentStoreRemoveUbiquitousMetadataOption
    }
    
    private var storeDirectoryURL : NSURL {
        let fileManager = NSFileManager.defaultManager()
        let directoryURL: NSURL?
        do {
            directoryURL = try fileManager.URLForDirectory(.ApplicationSupportDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        } catch _ {
            directoryURL = nil
        }
        return directoryURL!
//        let urls = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask) as! [NSURL]
//        let documentsURL = urls[0]
//        return documentsURL
    }
    
    private var storeURL : NSURL {
        return storeDirectoryURL.URLByAppendingPathComponent("\(modelName).sqlite")
    }

    init(dbName:String, syncToCloud:Bool, completion: ((Void) -> Void)? ) {


        modelName = dbName

        super.init()
        
        CDESetCurrentLoggingLevel(CDELoggingLevel.Verbose.rawValue)

        // Setup Core Data Stack
        setupCoreData() {
            self.setupEnsemble(completion)
//            if let completion = completion {
//                completion()
//            }
        }

//        setupContext() {
//            self.setupEnsemble()
//            NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: self.privateMOC, queue: nil, usingBlock: {(NSNotification) in
//                self.synchronizeWithCompletion(nil)
//                })
//        }
    }

    private func setupCoreData(completion: ((Void) -> Void)?) {

        print("Setting up CD Stack")
        do {
            try NSFileManager.defaultManager().createDirectoryAtURL(storeDirectoryURL, withIntermediateDirectories:true, attributes:nil)
        } catch _ {
        }
        
        // Create the model
        modelURL = NSBundle.mainBundle().URLForResource(modelName, withExtension: "momd")!
        let _model = NSManagedObjectModel(contentsOfURL: modelURL!)
        assert(_model != nil, "Could not retrieve model at URL \(modelURL!)")
        model = _model

        // Build the persistent store coordinator
        psc = NSPersistentStoreCoordinator(managedObjectModel: model!)
        let storeURL = self.storeURL
        let options = self.storeOptions
        var error: NSError? = nil
        do {
            self.store = try self.psc!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: options)
        } catch let error1 as NSError {
            error = error1
            self.store = nil
        }
        assert(self.store != nil, "Could not add store URL \(storeURL)")
        
        // Set up the main MOC
        mainQueueMOC = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        mainQueueMOC?.persistentStoreCoordinator = psc
        mainQueueMOC?.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        print("Finished setting up CD Stack")
        if let completion = completion {
            completion()
        }

        // Create the private MOC, this is the parent context of the mainQueueMOC and it
        // owns the persistent store.
//        privateMOC = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
//        privateMOC!.persistentStoreCoordinator = psc
//        privateMOC!.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
//        
//        // Make the main MOC a child of the private MOC
//        mainQueueMOC!.parentContext = privateMOC
//        
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
//            
//            // Get the proper options dictionary and storeURL based on the state
//            // of our sync flag.
//            var storeURL = self.storeDirectoryURL.URLByAppendingPathComponent("\(self.modelName).sqlite")
//            var options = self.storeOptions
//            var error: NSError? = nil
//            self.store = self.psc!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: options, error: &error)
//            assert(self.store != nil, "Could not add store URL \(storeURL)")
//        
//            if let _completion = completion {
//                dispatch_async(dispatch_get_main_queue(),_completion)
//            }
//        }

    }

    func fetchEntities() -> [Entity]?{
        let fetchRequest = NSFetchRequest(entityName: "Entity")
        var error: NSError?
        let result = mainQueueMOC?.executeFetchRequest(fetchRequest) as! [Entity]?
        return result
    }
    
    func localSaveOccurred(notification:NSNotification) {
        synchronizeWithCompletion(nil)
    }

    func cloudDataDidDownload(notification:NSNotification) {
        synchronizeWithCompletion(nil)
    }
    
    func enableSyncManager(completion:((Void) -> Void)?) {
        LocalStoreService.sharedInstance.syncToCloud = true
        setupEnsemble() {
            if let completion = completion {
                completion()
            }
        }
    }
    
    func disableSyncManager(completion:((Void) -> Void)?) {
        disconnectFromSyncServiceWithCompletion() {
            LocalStoreService.sharedInstance.syncToCloud = false
            if let completion = completion {
                completion()
            }
        }
    }
    
    private func canSynchronize() -> Bool {
        //        NSString *cloudService = [[NSUserDefaults standardUserDefaults] stringForKey:IDMCloudServiceUserDefaultKey];
        //        return cloudService != nil;
        return LocalStoreService.sharedInstance.syncToCloud
    }
    
    func setupEnsemble(completion:((Void) -> Void)?) {
        print("Setting up sync stack")
        if (!canSynchronize()) {
            print("Cannot set up sync stack, disabled")
            return
        }
//        IDMSyncManager *syncManager = [IDMSyncManager sharedSyncManager];
//        syncManager.managedObjectContext = managedObjectContext;
//        syncManager.storePath = self.storeURL.path;
//        [syncManager setup];

        //        let cloudFileSystem = CDEICloudFileSystem(ubiquityContainerIdentifier: ubiquityContainerIdentifier)
        // TODO: see ine 32 of IDMSyncManager
        let cloudFileSystem = CDEICloudFileSystem(ubiquityContainerIdentifier: nil)
        assert(cloudFileSystem != nil, "Cloud file system could not be created")

        ensemble = CDEPersistentStoreEnsemble(ensembleIdentifier: modelName, persistentStoreURL: storeURL, managedObjectModelURL: modelURL, cloudFileSystem: cloudFileSystem)
        ensemble!.delegate = self
        
        // Listen for local saves, and trigger merges
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "localSaveOccurred:", name: CDEMonitoredManagedObjectContextDidSaveNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "cloudDataDidDownload:", name: CDEICloudFileSystemDidDownloadFilesNotification, object: nil)
        // At this point, completed through line 45 of IDMAppDelegate
        
        print("Finished setting up sync stack")
        synchronizeWithCompletion(completion)
    }
    
    private func synchronizeWithCompletion(completion:((Void) -> Void)?) {
        if (!canSynchronize()) {
            return
        }
        
        incrementMergeCount()
        if let ensemble = ensemble {
            if (!ensemble.leeched) {
                print("Leeching the ensemble")
                ensemble.leechPersistentStoreWithCompletion(){
                    (error:NSError?) in
                        print("Leeching complete")
                        self.decrementMergeCount()
                        if (error != nil) {
                            print("Could not leech to ensemble: \(error)")
                            if (!ensemble.leeched) {
                                self.disconnectFromSyncServiceWithCompletion(completion)
                                return
                            }
                        }
                        print("Leeching successful")
                        if let completion = completion {
                            completion()
                        }
                    }
            }
            else {
                print("Merging with the ensemble")
                // Initiate sync operations
                ensemble.mergeWithCompletion() {
                    error in
                    print("Merging complete")
                    self.decrementMergeCount()

                    if (error != nil) {
                        print("Could not merge ensemble: \(error)")
                    }
                    print("Merging successful")
                    if let completion = completion {
                        completion()
                    }
                }
            }
            
        }
    }
    

    // MARK: Ensemble Delegate Methods
    func persistentStoreEnsemble(ensemble: CDEPersistentStoreEnsemble!, didSaveMergeChangesWithNotification notification: NSNotification!) {
//        privateMOC!.performBlockAndWait() {
//            self.privateMOC!.mergeChangesFromContextDidSaveNotification(notification)
//        }
        if let mainQueueMOC = mainQueueMOC {
            // merge the changes in the notification into the main MOC
            mainQueueMOC.performBlockAndWait() {
                mainQueueMOC.mergeChangesFromContextDidSaveNotification(notification)
            }
        }
    }

    func persistentStoreEnsemble(ensemble: CDEPersistentStoreEnsemble!, globalIdentifiersForManagedObjects objects: [AnyObject]!) -> [AnyObject]! {
        let returnArray = NSMutableArray()
        for (idx, object) in objects.enumerate() {
            let value: AnyObject? = object.valueForKeyPath("uniqueIdentifier")
            returnArray.addObject(value!)
        }
        return returnArray as [AnyObject]
    }
    
    private func decrementMergeCount() {
        activeMergeCount--
        if (activeMergeCount == 0) {
            NSNotificationCenter.defaultCenter().postNotificationName(SYNC_ACTIVITY_DID_END, object: nil)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
        }
    }
    
    private func incrementMergeCount() {
        activeMergeCount++;
        if (activeMergeCount == 1) {
            NSNotificationCenter.defaultCenter().postNotificationName(SYNC_ACTIVITY_DID_BEGIN, object: nil)
            UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        }
    }
    
    func disconnectFromSyncServiceWithCompletion(completion:((Void) -> Void)?) {
        if let ensemble = ensemble {
            ensemble.deleechPersistentStoreWithCompletion() {
                error in
                if (error != nil) {
                    NSLog("Could not disconnect from sync service: \(error)")
                }
                else {
                    self.reset()
                    if let completion = completion {
                        completion()
                    }
                }
            }
        }
    }
    
    func reset() {
        if (ensemble != nil) {
            ensemble!.delegate = nil
            ensemble = nil
        }
    }
    
    deinit {
        print("Deallocating CoreDataStack")
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func handleCoreDataEvent(notification:NSNotification) {
        print("CoreData event received: \(notification)")
    }

//    func attachInternalListeners() {
//        NSNotificationCenter.defaultCenter().addObserver(self,
//            selector: "handleCoreDataEvent:",
//            name: NSPersistentStoreCoordinatorStoresDidChangeNotification,
//            object: psc)
//        NSNotificationCenter.defaultCenter().addObserver(self,
//            selector: "handleCoreDataEvent:",
//            name: NSPersistentStoreCoordinatorStoresWillChangeNotification,
//            object: psc)
//        NSNotificationCenter.defaultCenter().addObserver(self,
//            selector: "handleUbiquitousChanges:",
//            name: NSPersistentStoreDidImportUbiquitousContentChangesNotification,
//            object: psc)
//        NSNotificationCenter.defaultCenter().addObserver(self,
//            selector: "handleCoreDataEvent:",
//            name: NSPersistentStoreCoordinatorWillRemoveStoreNotification,
//            object: psc)
//        NSNotificationCenter.defaultCenter().addObserver(self,
//            selector: "handleCoreDataEvent:",
//            name: NSUbiquityIdentityDidChangeNotification,
//            object: nil)
//    }
//
//    func attachListenerForChangeEvents(#observer:AnyObject, selector:Selector) {
//        NSNotificationCenter.defaultCenter().addObserver(observer,
//            selector: selector,
//            name: NSPersistentStoreCoordinatorStoresDidChangeNotification,
//            object: psc)
//        NSNotificationCenter.defaultCenter().addObserver(observer,
//            selector: selector,
//            name: NSPersistentStoreCoordinatorStoresWillChangeNotification,
//            object: psc)
//        NSNotificationCenter.defaultCenter().addObserver(observer,
//            selector: selector,
//            name: NSPersistentStoreDidImportUbiquitousContentChangesNotification,
//            object: psc)
//        NSNotificationCenter.defaultCenter().addObserver(observer,
//            selector: selector,
//            name: NSPersistentStoreCoordinatorWillRemoveStoreNotification,
//            object: psc)
//        NSNotificationCenter.defaultCenter().addObserver(observer,
//            selector: selector,
//            name: NSUbiquityIdentityDidChangeNotification,
//            object: nil)
//    }

    func save(completion:((Void) -> Void)?) {
        if let mainMOC = self.mainQueueMOC {
            // If we have nothing to save just run the completion listener
           if (!mainMOC.hasChanges) {
                //        if (!mainQueueMOC!.hasChanges && !privateMOC!.hasChanges) {
                print("No changes to be saved")
                if let completion = completion {
                    completion()
                }
            }
           else {
                mainMOC.performBlockAndWait() {
                
                    // Save main MOC on the main queue
                    var error: NSError? = nil
                    print("Saving mainQueueMOC")
                    do {
                        try mainMOC.save()
                    } catch let error1 as NSError {
                        error = error1
                        print("Error saving main MOC: \(error?.localizedDescription), \(error?.userInfo)")
                    } catch {
                        fatalError()
                    }
                    if let completion = completion {
                        print("Running completion handler")
                        completion()
                        print("Finished completion handler")
                    }
                }
            
            }
        }
    }
    
//        mainQueueMOC!.performBlockAndWait() {
//            
//            // Save main MOC on the main queue
//            var error: NSError? = nil
//            println("Saving mainQueueMOC")
//            if let mainMOC = self.mainQueueMOC {
//                if !mainMOC.save(&error) {
//                    println("Error saving main MOC: \(error?.localizedDescription), \(error?.userInfo)")
//                }
//                if let completion = completion {
//                    println("Running completion handler")
//                    completion()
//                    println("Finished completion handler")
//                }
//                
//            }

            // Save the private MOC asynchronously on it's private queue which will save to the PersistentStore
//            println("Saving privateMOC")
//            self.privateMOC!.performBlock() {
//                var privateError: NSError? = nil
//                if !self.privateMOC!.save(&error) {
//                    println("Error saving private MOC: \(privateError?.localizedDescription), \(privateError?.userInfo)")
//                }
//                
//                // Run the completion block as all saves are complete here
//                if let _completion = completion {
//                    println("Running completion handler")
//                    dispatch_async(dispatch_get_main_queue()) {
//                        _completion()
//                        println("Finished completion handler")
//                   }
//                }
//                
//            }
    //        }
    //    }

//    func applicationDocumentsDirectory() -> NSURL {
//        let fileManager = NSFileManager.defaultManager()
//        let urls = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask) as [NSURL]
//        return urls[0]
//    }

//    private var localStoreURL : NSURL {
//        let fileManager = NSFileManager.defaultManager()
//        let urls = fileManager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask) as! [NSURL]
//        let documentsURL = urls[0]
//
//        //        let documentsURL = applicationDocumentsDirectory()
//        return documentsURL.URLByAppendingPathComponent("\(modelName).sqlite")
//
//    }
    
//    var cloudStoreURL : NSURL {
//        var storePaths = NSSearchPathForDirectoriesInDomains(.ApplicationSupportDirectory, .UserDomainMask, true)
//        let storePath = storePaths[0] as String
//        let fileManager = NSFileManager.defaultManager()
//
//        fileManager.createDirectoryAtPath(storePath, withIntermediateDirectories:
//            true, attributes: nil, error: nil)
//        return NSURL.fileURLWithPath(storePath.stringByAppendingPathComponent("CDSync.sqlite"))!
//    }

    private var ubiquityContainerIdentifier: String {
        let fileManager = NSFileManager.defaultManager()
        let teamId = "iCloud"
        let bundleID = NSBundle.mainBundle().bundleIdentifier
        let cloudRoot = "\(teamId).\(bundleID!)"
        return cloudRoot
    }
    
//    private var cloudStoreURL: NSURL? {
//        //        NSFileManager *fileManager=[NSFileManager defaultManager];
//        let fileManager = NSFileManager.defaultManager()
//        //        NSString *teamID=@"iCloud";
//        let teamId = "iCloud"
//        //    NSString *bundleID=[[NSBundle mainBundle]bundleIdentifier];
//        let bundleID = NSBundle.mainBundle().bundleIdentifier
//        //    NSString *cloudRoot=[NSString stringWithFormat:@"%@.%@",teamID,bundleID];
//        let cloudRoot = "\(teamId).\(bundleID!)"
//        //        NSURL *cloudRootURL=[fileManager URLForUbiquityContainerIdentifier:cloudRoot];
//        if let cloudRootURL = fileManager.URLForUbiquityContainerIdentifier(cloudRoot) {
//            println("cloudRootURL=\(cloudRootURL)")
//            let finalCloudURL = cloudRootURL.URLByAppendingPathComponent("\(modelName).sqlite")
//            return finalCloudURL
//        }
//        println("Cloud store not available")
//        return nil
//    }

//    private var cloudStoreOptions : [NSObject:AnyObject] {
//        return [NSPersistentStoreUbiquitousContentNameKey: "\(modelName)CloudStore",
//            NSMigratePersistentStoresAutomaticallyOption: true,
//            NSInferMappingModelAutomaticallyOption: true]
//    }

//    private var cloudStoreOptionsWithRebuild : [NSObject:AnyObject] {
//        return [NSPersistentStoreUbiquitousContentNameKey: "\(modelName)CloudStore",
//            NSMigratePersistentStoresAutomaticallyOption: true,
//            NSInferMappingModelAutomaticallyOption: true,
//            NSPersistentStoreRebuildFromUbiquitousContentOption: true
//        ]
//    }

//    private func resetContexts() {
//        mainQueueMOC.reset()
//        privateMOC.reset()
//    }

    //http://pinkstone.co.uk/tag/nspersistentstorecoordinator/
//    func switchToCloudStore(completion: ((Void) -> Void)?) {
//        let cloudOptions = cloudStoreOptions
//        let storeURL = cloudStoreURL
//        if (storeURL == nil) {
//            println("Could not switch to store because store URL not available")
//            return
//        }
//        var error: NSError?
//
//        let newStore = psc.migratePersistentStore(store!, toURL: storeURL!, options: cloudOptions, withType: NSSQLiteStoreType, error: &error)
//
//        if let _newStore = newStore {
//            println("Cloud store URL is: \(psc.URLForPersistentStore(_newStore))")
//            self.store = _newStore
//            resetContexts()
//            NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: STORE_SWITCH_COMPLETED, object: nil))
//            if let _completion = completion {
//                _completion()
//            }
//        }
//        else if let _error = error {
//            println("Error in migrating to cloud store: \(_error)")
//        }
//        else {
//            println("Returned newStore was nil when trying to migrate to cloud store")
//        }
//    }

//    func switchToLocalStore(completion: ((Void) -> Void)?) {
//        var localOptions = localStoreOptions
//        localOptions.updateValue(true, forKey: NSPersistentStoreRemoveUbiquitousMetadataOption)
//        // TODO: Need to blow away the local store otherwise when you come back you end up with duplicate records.
////        let localStoreURL = self.localStoreURL
////        let localStore = store!
//        //        let cloudStoreURL = self.cloudStoreURL
//        var error : NSErrorPointer = nil
//        if let _newStore = psc.migratePersistentStore(store!, toURL: localStoreURL, options: localOptions, withType: NSSQLiteStoreType, error: error) {
//            self.store = _newStore
//            resetContexts()
//            NSNotificationCenter.defaultCenter().postNotification(NSNotification(name: STORE_SWITCH_COMPLETED, object: nil))
//
//            if let _completion = completion {
//                _completion()
//            }
//        }
//    }

//    func resetStore(completion: ((Void) -> Void)?) {
//        let storeURL = cloudStoreURL
//        if (storeURL == nil) {
//            println("Could not reset store because store URL not available")
//            return
//        }
//
//        let options =  [NSPersistentStoreUbiquitousContentNameKey: "\(modelName)CloudStore"]
//
//        var error : NSErrorPointer = nil
//        let result = NSPersistentStoreCoordinator.removeUbiquitousContentAndPersistentStoreAtURL(storeURL!, options: options, error: error)
//        if (result) {
//            if let _completion = completion {
//                _completion()
//            }
//        }
//    }

    func rebuildLocalStoreFromCloudStore(completion:((Void) -> Void)?) {

        // Not implemented because I'm not sure when this would be called.
    }

    //http://stackoverflow.com/questions/25466472/nsfunctionexpression-propertytype-unrecognized-selector-sent-to-instance
    /**
    Common method to deduplicate NSManagedObjects in the database after switching stores.  This should be called for each table.
    The idea is to start with your most primary objects and work down to lower level objects assuming cascade deletes are enabled
    for relationships.

    - parameter entityName:         The name of the object to be deduplicated
    - parameter uniquePropertyName: The propery on the entity's class that is used as the group by parameter
    - parameter deDupAlgorithm:     The function to determine which of two objects to keep.  The other will be deleted.  This function
                               takes two managed objects.  The first one is the best candidate object to keep, the second is the
                               next object to be copmpared against it.  It returns an optional tuple of two objects.  The first is
                               the one that is now the best one to keep.  The second is the one to delete.  If nil is returned then
                               the two managed objects are not equal in thier grouping property so they both should be kept.

    - parameter completion:         A function to run after the deduplication is complete
    */
    func deDuplicateEntities(entityName entityName:String,
        uniquePropertyName:String,
        deDupAlgorithm: (currentKeep: NSManagedObject, nextToCheck: NSManagedObject) -> (keep:NSManagedObject, discard:NSManagedObject)?,
        completion:((Void) -> Void)?) {


        // Build the expression for the property to be retrieved
        let entityDescription:NSEntityDescription = NSEntityDescription.entityForName(entityName, inManagedObjectContext: mainQueueMOC!)!
        let uniqueAttributeDescription = entityDescription.attributesByName[uniquePropertyName] as! NSAttributeDescription

        // Build the expression to count the number of occurances of the uniqueProperty
        let keyPathExpression = NSExpression(forKeyPath: uniquePropertyName)
        let countExpression = NSExpression(forFunction: "count:", arguments: [keyPathExpression])

        // Build the description object to retrieve the grouped counts
        let countExpressionDescription = NSExpressionDescription()
        countExpressionDescription.name = "count" // Setting this stopped an exception from occurring
        countExpressionDescription.expression = countExpression
        countExpressionDescription.expressionResultType = NSAttributeType.Integer32AttributeType

        // Build the fetch request to retrieve the unique counts
        let fetchRequest = NSFetchRequest(entityName: entityName)
        fetchRequest.propertiesToFetch = [uniqueAttributeDescription, countExpressionDescription]
        fetchRequest.propertiesToGroupBy = [uniqueAttributeDescription]
        fetchRequest.resultType = NSFetchRequestResultType.DictionaryResultType

        // execute the fetch request and get back a dictionary of unique attributes as the key and count as the value
        var error:NSError?
        let fetchedDictionaries: [AnyObject]?
        do {
            fetchedDictionaries = try mainQueueMOC!.executeFetchRequest(fetchRequest)
        } catch var error1 as NSError {
            error = error1
            fetchedDictionaries = nil
        }
        if (error != nil) {
            print("Error fetching unique attribute during deduplication: \(error)")
            return
        }

        // Walk the dictionaries and accumulate a list of the attributes with a count higher than one
        let valuesWithDupes = NSMutableArray()
        if let _fetchedDictionaries = fetchedDictionaries {
            for dictionary in _fetchedDictionaries {
                var count = dictionary["count"] as! NSNumber
                if (count.integerValue > 1) {
                    valuesWithDupes.addObject(dictionary[uniquePropertyName]!!)
                }
            }
        }

        // Build the fetch request to retrieve ALL the objects that need to be deduplicated
        let sortDescriptor = NSSortDescriptor(key: uniquePropertyName, ascending: true)
        let dupeFetchRequest = NSFetchRequest(entityName: entityName)
        dupeFetchRequest.includesPendingChanges = false
        dupeFetchRequest.sortDescriptors = [sortDescriptor] // Apple solution didn't have a sort descriptor (which is needed)
        let predicate = NSPredicate(format: "\(uniquePropertyName) IN (%@)", valuesWithDupes)
        dupeFetchRequest.predicate = predicate

        // Execute the fetch request
        let dupes: [AnyObject]?
        do {
            dupes = try mainQueueMOC!.executeFetchRequest(dupeFetchRequest)
        } catch var error1 as NSError {
            error = error1
            dupes = nil
        }
        if (error != nil) {
            print("Error fetching duplicate records during deduplication: \(error)")
            return
        }

        // Walk the list of duplicates
        if let _dupes = dupes {
            var keepObject:NSManagedObject?
            for duplicate in _dupes {
                let objectToCheck = (duplicate as! NSManagedObject)
                print("Duplicate name: \(objectToCheck.valueForKey(uniquePropertyName)!)")
                // If the current object to keep has been set then we run the checking algorithm
                if let _keepObject = keepObject {
                    let result = deDupAlgorithm(currentKeep: _keepObject, nextToCheck: objectToCheck)

                    // If we got a result one of the two objects needs to be deleted
                    if let _result = result {
                        mainQueueMOC!.deleteObject(_result.discard)
                        keepObject = _result.keep
                    }
                    else {
                        // Didn't get a result so the objectToCheck is the begining of a new group to check
                        keepObject = objectToCheck
                    }
                }
                else {
                    keepObject = objectToCheck
                }
            }
            do {
                try self.mainQueueMOC!.save()
            } catch var error1 as NSError {
                error = error1
                print("Error saving main MOC: \(error?.localizedDescription), \(error?.userInfo)")
            }
            if let completion = completion {
                completion()
            }
            // Save our context
            //            save(completion)
        }
    }
}
