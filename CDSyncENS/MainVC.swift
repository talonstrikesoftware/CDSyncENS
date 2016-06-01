//
//  MainVC.swift
//  CDSync
//
//  Copyright (c) 2015 Talon Strike Software. All rights reserved.
//

import UIKit
import CoreData

@objc class MainVC: UITableViewController, NSFetchedResultsControllerDelegate {

//    @IBOutlet weak var storeSyncButton:UIBarButtonItem?
//    @IBOutlet weak var resetButton:UIBarButtonItem?
//    @IBOutlet weak var deleteRecordsButton:UIBarButtonItem?
//    @IBOutlet weak var deduplicateButton:UIBarButtonItem?

    @IBOutlet weak var storeSyncStatus:UIBarButtonItem?
    @IBOutlet weak var nextIDButton:UIBarButtonItem?
    @IBOutlet weak var actionSheetButton:UIBarButtonItem?

    private var _coreDataStack:CDEStack?
    
//    var coreDataStack:CoreDataStack? {
//        set {
//            _coreDataStack = newValue
//            setupFetchedResultsController()
//            _coreDataStack!.attachListenerForChangeEvents(observer:self, selector:"handleStoreChanged:")
//            refreshUI()
//        }
//        get {
//            return _coreDataStack
//        }
//        // need a set function here
//    }
    
    
    var fetchedResultsController:NSFetchedResultsController?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = 44 // Fixes bug where we get a warning in the output
//        storeSyncButton!.enabled = false
//        resetButton!.enabled = false
//        deleteRecordsButton!.enabled = false
//        deduplicateButton!.enabled = false
//        setupFetchedResultsController()
//        coreDataStack.attachListenerForChangeEvents(observer:self, selector:"handleStoreChanged:")

//        let fetchRequest = NSFetchRequest(entityName: "Entity")
//        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
//        fetchRequest.sortDescriptors = [sortDescriptor]
//        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: coreDataStack.context, sectionNameKeyPath: nil, cacheName: nil)
//        fetchedResultsController.delegate = self
//
//        var error:NSError? = nil
//        if (!fetchedResultsController.performFetch(&error)) {
//            println("Error: \(error?.localizedDescription)")
//
//        }
        refreshUI()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem()
    }

    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }

    func setCoreDataStack(coreDataStack:CDEStack) {
        _coreDataStack = coreDataStack
        setupFetchedResultsController()
        refreshUI()
    }

    func handleStoreChanged(notification:NSNotification) {
        print("Handling Store changed: \(notification)")
//        setupFetchedResultsController()
//        tableView.reloadData()
//        refreshUI()

//        self.tableView.reloadData()
//        refreshUI()
//        coreDataStack.deDuplicateEntities(entityName: "Entity",
//            uniquePropertyName: "name",
//            deDupAlgorithm: {(currentKeep:NSManagedObject, nextToCheck:NSManagedObject) -> (NSManagedObject, NSManagedObject) in
//                let first = currentKeep as Entity
//                let second = nextToCheck as Entity
//                return (first, second)
//            },
//            completion: {_ in
//                //                LocalStoreService.sharedInstance.syncToCloud = !syncToCloud
//                self.setupFetchedResultsController()
//                self.tableView.reloadData()
//                self.refreshUI()
//            }
//        )
//
    }

    func setupFetchedResultsController() {
        if (_coreDataStack == nil) {
            return
        }
        let fetchRequest = NSFetchRequest(entityName: "Entity")
        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: _coreDataStack!.context, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController!.delegate = self

        var error:NSError? = nil
        let success: Bool
        do {
            try fetchedResultsController!.performFetch()
            success = true
        } catch let error1 as NSError {
            error = error1
            success = false
        }
        if (!success) {
            print("Error: \(error?.localizedDescription)")
        }
        else {
            self.tableView.reloadData()
        }
    }

    func refreshUI() {
        storeSyncStatus?.title = LocalStoreService.sharedInstance.syncToCloud ? "Cloud On" : "Cloud Off"
        nextIDButton?.title = "Next ID: \(LocalStoreService.sharedInstance.lastCount!+1)"

        var entitiesCount = 0
        if let _frc = fetchedResultsController {
            let sectionInfo = _frc.sections![0] as NSFetchedResultsSectionInfo
            entitiesCount = sectionInfo.numberOfObjects
        }

        title = "Entities (\(entitiesCount))"

//        let syncToCloud = LocalStoreService.sharedInstance.syncToCloud
//        storeSyncButton?.title = syncToCloud ? "Sync Off" : "Sync On"
//        resetButton?.enabled = syncToCloud
//        // TODO: Enable buttons based on existence of coreDataStack
    }

    @IBAction func addEntity() {
        if let coreDataStack = _coreDataStack {
            let entityEntity = NSEntityDescription.entityForName("Entity", inManagedObjectContext: coreDataStack.context)
            let entity = Entity(entity:entityEntity!, insertIntoManagedObjectContext: coreDataStack.context)
            let newCount = LocalStoreService.sharedInstance.lastCount!+1
            entity.name = "\(newCount)"
            let deviceName = UIDevice.currentDevice().name
            entity.desctext = "\(deviceName): \(NSDate())"
            var error: NSError? = nil
            coreDataStack.save() {
                LocalStoreService.sharedInstance.lastCount = newCount
            }
        }
        else {
            print("Unable to add entity, there is no coreDataStack")
        }
    }

//    @IBAction func removeAllRecords() {
//        if (_coreDataStack == nil) {
//            return
//        }
//        let fetchRequest = NSFetchRequest(entityName: "Entity")
//        let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)
//        fetchRequest.sortDescriptors = [sortDescriptor]
//        var error:NSError?
//        let results = _coreDataStack!.context.executeFetchRequest(fetchRequest, error: &error) as? [Entity]
//        if let _results = results {
//            for entity in _results {
//                _coreDataStack!.context.deleteObject(entity)
//            }
//            _coreDataStack!.save() {
//                self.tableView.reloadData()
//            }
//        }
//    }
//
//    @IBAction func deDuplicateRecords() {
//        self._coreDataStack!.deDuplicateEntities(entityName: "Entity",
//            uniquePropertyName: "name",
//            deDupAlgorithm: self.deDupRecords,
//            completion: {
//               var error:NSError? = nil
//               let success = self.fetchedResultsController!.performFetch(&error)
//               if (!success) {
//                   println("Error: \(error?.localizedDescription)")
//               }
//               else {
//                   self.tableView.reloadData()
//               }
//            }
//        )
//        
//    }
    
    @IBAction func showActionSheet(sender: AnyObject) {
        
        let optionMenu = UIAlertController(title: nil, message: "Choose Option", preferredStyle: .ActionSheet)
        
        let cloudActionTitle = LocalStoreService.sharedInstance.syncToCloud ? "Disable Cloud" : "Enable Cloud"
        let cloudAction = UIAlertAction(title: cloudActionTitle, style: .Default, handler: {
            (alert: UIAlertAction) -> Void in
            print("toggling cloud access")
        
            if let coreDataStack = self._coreDataStack {
                // Whatever the sync flag was before invert it so we call the right method.
                let syncToCloud = !LocalStoreService.sharedInstance.syncToCloud
                if (syncToCloud) {
                    print("enabling sync manager")
                    coreDataStack.enableSyncManager() {
                        self.tableView.reloadData()
                        self.refreshUI()
                    }
                }
                else {
                    print("disabling sync manager")
                    coreDataStack.disableSyncManager() {
                        self.tableView.reloadData()
                        self.refreshUI()
                    }
                }
            }
        })
        
        let clearAction = UIAlertAction(title: "Delete Local & Remote", style: .Default, handler: {
            (alert: UIAlertAction) -> Void in
            self.deleteAllLocalEntities()
        })
        
        //
        let resyncAction = UIAlertAction(title: "Delete Local & Resync", style: .Default, handler: {
            (alert: UIAlertAction) -> Void in
            print("Resyncing entities")
            if let coreDataStack = self._coreDataStack {
                let syncToCloud = LocalStoreService.sharedInstance.syncToCloud
                if (syncToCloud) {
                    coreDataStack.disableSyncManager() {
                        self.deleteAllLocalEntities()
                        coreDataStack.enableSyncManager() {
                            self.tableView.reloadData()
                            self.refreshUI()
                        }
                    }
                }
                else {
                    self.deleteAllLocalEntities()
                    coreDataStack.enableSyncManager() {
                        self.tableView.reloadData()
                        self.refreshUI()
                    }
                }
            }

            // Turn off cloud
            // delete everything
            // Turn on cloud
            //            LocalDataService.sharedInstance.resyncEntities()
        })
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: {
            (alert: UIAlertAction) -> Void in
            print("Cancelled")
        })
        
        
        // 4
        optionMenu.addAction(cloudAction)
        optionMenu.addAction(clearAction)
        optionMenu.addAction(resyncAction)
        optionMenu.addAction(cancelAction)
        
        // Required for iPad presentation
        optionMenu.popoverPresentationController?.barButtonItem = actionSheetButton
        
        // 5
        self.presentViewController(optionMenu, animated: true, completion: nil)
    }

    private func deleteAllLocalEntities() {
        print("Deleting all local entities")
        // TODO: Loop through all entities and delete them all
        if let coreDataStack = self._coreDataStack {
            let fetchRequest = NSFetchRequest(entityName: "Entity")
            var error: NSError?
            do {
                let entities = try coreDataStack.context.executeFetchRequest(fetchRequest) as! [Entity]?
                if let entities = entities {
                    for (idx, entity) in entities.enumerate() {
                        coreDataStack.context.deleteObject(entity)
                    }
                    coreDataStack.save() {
                        self.tableView.reloadData()
                        self.refreshUI()
                    }
                }
            }
            catch {
                print("Got an error")
            }
        }
    }
//    @IBAction func switchStore() {
//        if (_coreDataStack == nil) {
//            return
//        }
//        fetchedResultsController?.delegate = nil
//        fetchedResultsController = nil
//        self.tableView.reloadData()
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleStoreSwitched:", name: STORE_SWITCH_COMPLETED, object: nil)
//        let syncToCloud = LocalStoreService.sharedInstance.syncToCloud
//        if (syncToCloud) {
//            _coreDataStack!.switchToLocalStore() {
//                NSLog("Finished switching to local store")
//                LocalStoreService.sharedInstance.syncToCloud = !syncToCloud
//                self._coreDataStack!.deDuplicateEntities(entityName: "Entity",
//                    uniquePropertyName: "name",
//                    deDupAlgorithm: self.deDupRecords,
//                    //                    completion: nil
//                    completion: self.switchStoreCompletionHandler
//                )
//            }
//        }
//        else {
//            _coreDataStack!.switchToCloudStore() {
//                NSLog("Finished switching to cloud store")
//                LocalStoreService.sharedInstance.syncToCloud = !syncToCloud
//                self._coreDataStack!.deDuplicateEntities(entityName: "Entity",
//                    uniquePropertyName: "name",
//                    deDupAlgorithm: self.deDupRecords,
//                                    //                    completion: nil
//                    completion: self.switchStoreCompletionHandler
//                )
//
//            }
//        }
//    }

//    @IBAction func resetStore() {
//        if (_coreDataStack == nil) {
//            return
//        }
//        let syncToCloud = LocalStoreService.sharedInstance.syncToCloud
//        if (syncToCloud) {
//            _coreDataStack!.switchToLocalStore() {
//                LocalStoreService.sharedInstance.syncToCloud = false
//                self._coreDataStack!.resetStore() {
//                    self.setupFetchedResultsController()
//                    self.tableView.reloadData()
//                    self.refreshUI()
//                }
//            }
//        }
//    }

    func genericDeviceName() -> String {
        let deviceName = UIDevice.currentDevice().name
        
        if (deviceName == "Redwolf 6") {
            return "Device 3"
        }
        else if (deviceName == "Mini Redwolf") {
            return "Device 2"
        }
        return deviceName
    }
    
    // MARK: - Table view data source
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if let _frc = fetchedResultsController {
            return _frc.sections!.count
        }
        return 1;
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let _frc = fetchedResultsController {
            let sectionInfo = _frc.sections![section] as NSFetchedResultsSectionInfo
            return sectionInfo.numberOfObjects
        }
        return 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("MainTVCell", forIndexPath: indexPath) as! MainTVCell
        if let _frc = fetchedResultsController {
            let entity = _frc.objectAtIndexPath(indexPath) as! Entity
            cell.configureCell(entity)
        }
        return cell
    }

    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == .Delete) {
            if let frc = fetchedResultsController, coreDataStack = _coreDataStack {
                let entity = frc.objectAtIndexPath(indexPath) as! Entity
                coreDataStack.context.deleteObject(entity)

                coreDataStack.save(nil)
            }
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let frc = fetchedResultsController, coreDataStack = _coreDataStack {
            let entity = frc.objectAtIndexPath(indexPath) as! Entity
            // TODO: Here is where we do a model migration
            // entity.dateUpdated = NSDate()
            entity.desctext = "\(genericDeviceName()): \(NSDate())"
            coreDataStack.save(nil)
        }
    }


    // MARK: NSFetchedResultsControllerDelegate methods
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.reloadData()
        refreshUI()
    }
}
