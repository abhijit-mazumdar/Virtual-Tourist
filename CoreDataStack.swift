//
//  CoreDataStack.swift
//  Virtual-Tourist
//
//  Created by Abhijit Mazumdar on 11/15/15.
//  Copyright © 2015 Abhijit Mazumdar. All rights reserved.
//

import Foundation
import CoreData

public class CoreDataStack {
    
    private let modelName = "VirtualTourist"
    
    lazy var privateContext:NSManagedObjectContext = {
        var privateContext =
        NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
        privateContext.persistentStoreCoordinator = self.psc
        return privateContext
    }()
    
    lazy var context: NSManagedObjectContext = {
        var managedObjectContext =
        NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.parentContext = self.privateContext
        return managedObjectContext
    }()
    
    private lazy var psc: NSPersistentStoreCoordinator = {
        let coordinator =
        NSPersistentStoreCoordinator(managedObjectModel:self.managedObjectModel)
        let url =
        self.applicationDocumentsDirectory.URLByAppendingPathComponent(self.modelName)
        do {
            let options =
            [NSMigratePersistentStoresAutomaticallyOption:true]
            try coordinator.addPersistentStoreWithType(
                NSSQLiteStoreType, configuration:nil, URL:url,
                options:options)
        } catch  {
            print("Error adding persistent store.")
        }
        return coordinator
    }()
    
    private lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL =
        NSBundle.mainBundle().URLForResource(self.modelName, withExtension:"momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()
    
    //MARK: - Save Context
    
    func saveContext() {
        // Save child/main context
        context.performBlockAndWait { () -> Void in
            if self.context.hasChanges {
                do {
                    try self.context.save()
                } catch let error as NSError {
                    print("Could not save: \(error.localizedDescription)")
                    abort()
                }
            }
        }
        // Save parent/private context
        privateContext.performBlock(){ () -> Void in
            if self.privateContext.hasChanges {
                do {
                    try self.privateContext.save()
                } catch let error as NSError {
                    print("Could not save: \(error.localizedDescription)")
                    abort()
                }
            }
        }
    }
    
    // MARK: - Helper 
    
    private lazy var applicationDocumentsDirectory: NSURL = {
        let urls = NSFileManager.defaultManager().URLsForDirectory(
            .DocumentDirectory, inDomains: .UserDomainMask)
        print(urls[urls.count-1])
        return urls[urls.count-1]
    }()
    
}
