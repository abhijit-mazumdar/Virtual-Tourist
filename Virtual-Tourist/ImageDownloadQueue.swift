//
//  ImageDownloadQueue.swift
//  Virtual-Tourist
//
//  Created by Abhijit Mazumdar on 11/15/15.
//  Copyright © 2015 Abhijit Mazumdar. All rights reserved.
//

import Foundation

//Keeps track of the downloads or operations in execution
class ImageDownloadQueue{
    
    lazy var pendingOperations = [NSString:NSOperation]()
    
    lazy var downloadQueue: NSOperationQueue = {
        var queue = NSOperationQueue()
        queue.name = "ImageDownloadQueue"
        return queue
    }()
    
}
