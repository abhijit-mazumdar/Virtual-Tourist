//
//  ImageDownloadOperation.swift
//  Virtual-Tourist
//
//  Created by Abhijit Mazumdar on 11/15/15.
//  Copyright © 2015 Abhijit Mazumdar. All rights reserved.
//

import Foundation

class ImageDownloadOperation: NSOperation{
    
    let url: String!
    let id: String!
    
    init(url: String, id: String) {
        self.url = url
        self.id = id
    }
    
    override func main() {
        if self.cancelled {
            print("operation canceled")
            return
        }
        
        let directoryPath = self.directoryPath()
        let pathArray = [directoryPath, "\(self.id)"]
        guard let imageDirectoryURL = NSURL.fileURLWithPathComponents(pathArray), imageDirectoryPath = imageDirectoryURL.path, webImageURL = NSURL(string:self.url) else {
            return
        }
        
        let fileManager = NSFileManager()
        if !fileManager.fileExistsAtPath(imageDirectoryPath) {
            if let downloadedImage = NSData(contentsOfURL:webImageURL){
                downloadedImage.writeToURL(imageDirectoryURL, atomically:true)
            }
        }
    }
    
    //MARK: - Helper Methods
    
    func directoryPath() -> String {
        let documentsDirectory =
        NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let dirPath = documentsDirectory[0]
        return dirPath
    }
    
}
