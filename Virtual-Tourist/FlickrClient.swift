//
//  FlickrClient.swift
//  Virtual-Tourist
//
//  Created by Abhijit Mazumdar on 11/15/15.
//  Copyright © 2015 Abhijit Mazumdar. All rights reserved.
//

import Foundation

class FlickrClient{
    
    static let sharedInstance = FlickrClient()
    let BASE_URL = "https://api.flickr.com/services/rest/"
    let METHOD_NAME = "flickr.photos.search"
    let API_KEY = "c381e5e8698cd13c82da8b8e19223a6a"
    let EXTRAS = "url_m"
    let SAFE_SEARCH = "1"
    let DATA_FORMAT = "json"
    let NO_JSON_CALLBACK = "1"
    let PAGE = "1"
    let MAX_PER_PAGE = "24"
    
    func getImagesWith(latitude: Double?, longitude: Double?,page: String?, completionHandler: (result: NSArray?, errorMessage: NSString?) -> Void) {
        
        guard let lat = latitude, lon = longitude else {
            completionHandler(result: nil, errorMessage: "Invalid location values")
            return
        }
        let methodArguments = [
            "method": METHOD_NAME,
            "api_key": API_KEY,
            "safe_search": SAFE_SEARCH,
            "extras": EXTRAS,
            "format": DATA_FORMAT,
            "nojsoncallback": NO_JSON_CALLBACK,
            "lat" : "\(lat)",
            "lon": "\(lon)",
            "per_page": MAX_PER_PAGE,
            "page": (page == nil) ? PAGE : page!//PAGE
        ]
        let session = NSURLSession.sharedSession()
        let urlString = BASE_URL + escapedParameters(methodArguments)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) {
            (data, response, downloadError) in
            if let downloadError = downloadError {
                completionHandler(result: nil, errorMessage: downloadError.localizedDescription)
                return
            }
            
            do{
                if let parsedData =
                    try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments) as? [String: AnyObject]{
                        
                        if let failureMessage = parsedData["message"] as? String{
                            completionHandler(result: nil, errorMessage: failureMessage)
                            return
                        }
                        guard let photos = parsedData["photos"] as? NSDictionary, photo = photos["photo"] as? NSArray else {
                            return
                        }
                        completionHandler(result: photo, errorMessage: nil)
                }
            } catch let error as NSError{
                print(error.localizedDescription)
            }
        }; task.resume()
        
    }
    
    /* Helper function: Given a dictionary of parameters, convert to a string for a url */
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        var urlVars = [String]()
        for (key, value) in parameters {
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            /* FIX: Replace spaces with '+' */
            let replaceSpaceValue = escapedValue!.stringByReplacingOccurrencesOfString(" ", withString: "+", options: NSStringCompareOptions.LiteralSearch, range: nil)
            /* Append it */
            urlVars += [key + "=" + "\(replaceSpaceValue)"]
        }
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
}
