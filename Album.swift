//
//  Album.swift
//  Virtual-Tourist
//
//  Created by Abhijit Mazumdar on 11/15/15.
//  Copyright © 2015 Abhijit Mazumdar. All rights reserved.
//

import Foundation
import CoreData

class Album: NSManagedObject {
    
    @NSManaged var latitude: String
    @NSManaged var longitude: String
    @NSManaged var pictures: NSMutableSet
    @NSManaged var date: NSDate
    
}
