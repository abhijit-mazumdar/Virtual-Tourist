//
//  MapController.swift
//  Virtual-Tourist
//
//  Created by Abhijit Mazumdar on 11/15/15.
//  Copyright © 2015 Abhijit Mazumdar. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapController: UIViewController, MKMapViewDelegate, AlbumControllerDelegate {
    
    var coreDataStack: CoreDataStack!
    var imageDownloadQueue: ImageDownloadQueue!
    
    enum acessory: Int {
        case delete
        case album
    }
    
    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        setMapPosition()
        loadPins()
        imageDownloadQueue = ImageDownloadQueue()
    }
    
    //MARK: - Target Action
    
    @IBAction func didPressAndHoldMap(gesture: UILongPressGestureRecognizer) {
        if gesture.state == UIGestureRecognizerState.Began {
            let touchPosition = gesture.locationInView(mapView)
            let mapCoordinate = mapView.convertPoint(touchPosition, toCoordinateFromView: mapView)
            addAnnotation(mapCoordinate)
            downloadImages(mapCoordinate, page: "1")
        }
    }
    
    //MARK: - Segue
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowAlbum" {
            let albumController = segue.destinationViewController as! AlbumController
            albumController.context =  coreDataStack.context
            albumController.location = (sender as? MKAnnotation)?.coordinate
            albumController.imageDownloadQueue = imageDownloadQueue
            albumController.delegate = self
        }
    }
    
    //MARK: - Download Methods
    
    func downloadImages(coordinates : CLLocationCoordinate2D, page: String?) {
        let client = FlickrClient.sharedInstance
        client.getImagesWith(coordinates.latitude, longitude: coordinates.longitude, page: page){ (data, error) in
            if let errorMessage = error {
                print("Error: \(errorMessage)")
            } else {
                self.saveImages(coordinates, data: data, error: error)
            }
        }
    }
    
    func backgroundImageDownload(tempObjectId: NSManagedObjectID){
        let privateContext = getChildContext()
        privateContext.performBlock(){
            guard let picture =
                privateContext.objectWithID(tempObjectId) as? Picture else {
                    return
            }
            let id = picture.id
            let url = picture.url
            
            let imageDownloadOperation = ImageDownloadOperation(url: url, id: id)
            imageDownloadOperation.completionBlock = { () -> Void in
                privateContext.performBlock(){
                    if picture.pictureExistInDirectory(){
                        self.imageDownloadQueue.pendingOperations.removeValueForKey(id)
                        privateContext.performBlock(){
                            picture.saved = true
                            do {
                                try privateContext.save()
                                self.coreDataStack.saveContext()
                            } catch let error as NSError {
                                print("\(error.localizedDescription)")
                            }
                        }
                    } else {
                        privateContext.performBlock(){
                            picture.saved = false
                            do {
                                try privateContext.save()
                                self.coreDataStack.saveContext()
                            } catch let error as NSError {
                                print(error.description)
                            }
                        }
                    }
                }
            }
            
            // add operation to pending array and to operation queue
            self.imageDownloadQueue.pendingOperations[id] = imageDownloadOperation
            self.imageDownloadQueue.downloadQueue.addOperation(imageDownloadOperation)
        }
        
    }
    
    func loadPins(){
        let fetch = NSFetchRequest()
        let entityDescription = NSEntityDescription.entityForName("Album", inManagedObjectContext: coreDataStack.context)
        fetch.entity = entityDescription
        
        let fetchedObjects: [AnyObject]?
        fetchedObjects = try? coreDataStack.context.executeFetchRequest(fetch)
        let albums = fetchedObjects as? [Album]
        
        if let albums = albums {
            if albums.count > 0 {
                let currentAnnotions = mapView.annotations
                mapView.removeAnnotations(currentAnnotions)
                for pin in albums {
                    let lat = (pin.latitude as NSString).doubleValue
                    let lon = (pin.longitude as NSString).doubleValue
                    addAnnotation(CLLocationCoordinate2D(latitude: lat, longitude: lon))
                }
            }
        }
    }
    
    //MARK: - Instance Methods
    
    func privateContext() -> NSManagedObjectContext! {
        let privateContext = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        privateContext.parentContext = coreDataStack.context
        return privateContext
    }
    
    func addAnnotation(coordinates: CLLocationCoordinate2D) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinates
        annotation.title = "Visited"
        mapView.addAnnotation(annotation)
    }
    
    func saveImages(coordinates : CLLocationCoordinate2D, data: NSArray?, error: NSString? ) {
        guard let data = data else {
            print("data is nil")
            return
        }
        let childPrivateContext = privateContext()
        childPrivateContext.performBlock(){
            let albumEntity =
            NSEntityDescription.entityForName("Album", inManagedObjectContext: childPrivateContext)
            let album =
            Album(entity: albumEntity!, insertIntoManagedObjectContext: childPrivateContext)
            album.latitude = "\(coordinates.latitude)"
            album.longitude = "\(coordinates.longitude)"
            album.date = NSDate()
            let pictures = album.pictures.mutableCopy() as! NSMutableSet
            let pictureEntity = NSEntityDescription.entityForName("Picture", inManagedObjectContext: childPrivateContext)
            
            for pic in data {
                let picture = Picture(entity: pictureEntity!, insertIntoManagedObjectContext: childPrivateContext)
                picture.url = pic["url_m"] as! String
                picture.id = pic["id"] as! String
                picture.album = album
                picture.saved = false
                pictures.addObject(picture)
                do {
                    try childPrivateContext.save()
                    self.backgroundImageDownload(picture.objectID)
                } catch let error as NSError {
                    print("Error Saving Child Context: \(error.localizedDescription)")
                }
            }; self.coreDataStack.saveContext()
        }
    }
    
    func enabelAnnotationViewButton(coordinates: CLLocationCoordinate2D) {
        for annotation in (self.mapView.annotations ){
            if annotation.coordinate.longitude == coordinates.longitude && annotation.coordinate.latitude == coordinates.latitude{
                if let annotationView = self.mapView.viewForAnnotation(annotation){
                    (annotationView.leftCalloutAccessoryView as! UIButton).enabled = true
                }
            }
        }
    }
    
    func setMapPosition(){
        if let mapPositon = NSUserDefaults.standardUserDefaults().objectForKey("mapPosition") as? [String: AnyObject]{
            let lat = mapPositon["latitude"] as! CLLocationDegrees
            let lon = mapPositon["longitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let lonDelta = mapPositon["latitudeDelta"] as! CLLocationDegrees
            let latDelta = mapPositon["longitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            let mapRegion = MKCoordinateRegion(center: center, span: span)
            mapView.setRegion(mapRegion, animated: true)
        }
    }
    
    //MARK: - Helper Methods
    
    func getChildContext() -> NSManagedObjectContext{
        let privateChild = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        privateChild.parentContext = coreDataStack.context
        return privateChild
    }
    
    /// Returns a fetch for an Album object
    func albumFetchRequest(lat lat: String, lon: String) -> NSFetchRequest {
        let fetch = NSFetchRequest()
        let entityDescription = NSEntityDescription.entityForName("Album", inManagedObjectContext: coreDataStack.context)
        fetch.entity = entityDescription
        let predicate = NSPredicate(format: "latitude == %@ && longitude == %@",lat, lon)
        fetch.predicate = predicate
        return fetch
    }
    
    func directoryPath() -> String {
        let documentsDirectory =
        NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let dirPath = documentsDirectory[0]
        return dirPath
    }
    
    //MARK: - MKMapViewDelegate Methods
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        
        if let pinView = mapView.dequeueReusableAnnotationViewWithIdentifier("annotation") as? MKPinAnnotationView {
            pinView.annotation = annotation
            return pinView
        } else {
            // Album Button
            let albumButton = UIButton(type: UIButtonType.System)
            albumButton.setImage(UIImage(named: "album"), forState: UIControlState.Normal)
            albumButton.sizeToFit()
            albumButton.tag = acessory.album.rawValue
            // Delete Button
            let deleteButton = UIButton(type: UIButtonType.System)
            deleteButton.setImage(UIImage(named: "delete"), forState: UIControlState.Normal)
            deleteButton.sizeToFit()
            deleteButton.tag = acessory.delete.rawValue
            // Create Annotion with buttons
            let pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "annotation")
            pinView.draggable = true
            pinView.animatesDrop = true
            pinView.canShowCallout = true
            pinView.leftCalloutAccessoryView = deleteButton
            pinView.rightCalloutAccessoryView = albumButton
            return pinView
        }
    }
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if let button = control as? UIButton{
            switch (button.tag) {
            case acessory.delete.rawValue:
                deleteAccessoryTapped(button, view: view)
            case acessory.album.rawValue:
                performSegueWithIdentifier("ShowAlbum", sender: view.annotation)
            default:
                print("Unknow button pressed")
            }
        }
    }
    
    func deleteAccessoryTapped(button: UIButton, view: MKAnnotationView) {
        button.enabled = false
        do {
            let fetch = albumFetchRequest(lat: view.annotation!.coordinate.latitude.description, lon: view.annotation!.coordinate.longitude.description)
            let fetchedObjects = try coreDataStack.context.executeFetchRequest(fetch)
            let albums = fetchedObjects as? [Album]
            var allowedToDelete = true
            if let albums = albums {
                for selectedAlbum in albums{
                    
                    for pic in selectedAlbum.pictures{
                        if let picture = pic as? Picture{
                            if picture.saved == false {
                                allowedToDelete = false
                            }
                        }
                    }
                    
                    if allowedToDelete{
                        coreDataStack.context.deleteObject(selectedAlbum)
                        if let annotation = view.annotation{
                            mapView.removeAnnotation(annotation)
                        }
                    } else {
                        print("Pin is unable to delete at this moment")
                    }
                    
                }; coreDataStack.saveContext()
            }
        }catch let error as NSError {
            print(error.localizedDescription)
        }
        button.enabled = true
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        //Save map position
        let mapPosition: [String: AnyObject] = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]
        NSUserDefaults.standardUserDefaults().setObject(mapPosition, forKey: "mapPosition")
    }
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        switch newState {
        case MKAnnotationViewDragState.Starting:
            movePin(view)
        case MKAnnotationViewDragState.Ending:
            //Download data from flickr, to new Location
            downloadImages(view.annotation!.coordinate, page: "1")
        default:
            return
        }
    }
    
    /// Deletes the AnnotationView and associated data
    func movePin(view: MKAnnotationView) {
        let childPrivateContext = privateContext()
        do {
            let fetch = albumFetchRequest(lat: view.annotation!.coordinate.latitude.description, lon: view.annotation!.coordinate.longitude.description)
            let fetchedObjects:[AnyObject]? = try childPrivateContext.executeFetchRequest(fetch)
            let albums = fetchedObjects as? [Album]
            var allowedToDelete = true
            if let selectedAlbum = albums?.first{
                
                for pic in selectedAlbum.pictures{
                    if let picture = pic as? Picture{
                        if picture.saved == false {
                            allowedToDelete = false
                        }
                    }
                }
                
                if allowedToDelete{
                    childPrivateContext.performBlock(){
                        childPrivateContext.deleteObject(selectedAlbum)
                        do {
                            try childPrivateContext.save()
                            self.coreDataStack.saveContext()
                        } catch let error as NSError {
                            print(error.localizedDescription)
                        }
                    }
                }
                
            }
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
    
    //MARK: - AlbumControllerDelegate
    
    func performSave(){
        coreDataStack.saveContext()
    }
    
    func performDownload(coordinates: CLLocationCoordinate2D, page: String?) {
        downloadImages(coordinates, page: page)
    }
    
}
