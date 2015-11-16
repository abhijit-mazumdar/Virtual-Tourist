//
//  Picture.swift
//  Virtual-Tourist
//
//  Created by Abhijit Mazumdar on 11/15/15.
//  Copyright © 2015 Abhijit Mazumdar. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class Picture: NSManagedObject {
    
    @NSManaged var url: String
    @NSManaged var text: String
    @NSManaged var id: String
    @NSManaged var album: Album
    @NSManaged var saved: NSNumber
    
    //MARK: Helper Methods
    
    func photo() -> UIImage? {
        let path = directoryPath()
        let pathArray = [path, "\(id)"]
        let filePath = NSURL.fileURLWithPathComponents(pathArray)
        let fileManager = NSFileManager()
        
        if fileManager.fileExistsAtPath(filePath!.path!) == false {
            return UIImage(named: "photoTemplate")
        } else {
            return UIImage(data: NSData(contentsOfURL: filePath!)!)
        }
    }
    
    func pictureExistInDirectory() -> Bool{
        let path = directoryPath()
        let pathArray = [path, "\(id)"]
        let filePath = NSURL.fileURLWithPathComponents(pathArray)
        let fileManager = NSFileManager()
        if (fileManager.fileExistsAtPath(filePath!.path!) == false) {
            return false
        } else {
            return true
        }
    }
    
    func directoryPath() ->String {
        let documentsDirectory =
        NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let dirPath = documentsDirectory[0]
        return dirPath
    }
    
    //MARK : Deletion
    
    override func prepareForDeletion() {
        let fileManager = NSFileManager.defaultManager()
        let dirPath = directoryPath()
        _ = try? fileManager.removeItemAtPath("\(dirPath)/\(id)")
    }
    
}
