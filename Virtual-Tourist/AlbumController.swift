//
//  AlbumController.swift
//  Virtual-Tourist
//
//  Created by Abhijit Mazumdar on 11/15/15.
//  Copyright © 2015 Abhijit Mazumdar. All rights reserved.
//

import UIKit
import CoreData
import MapKit

protocol AlbumControllerDelegate {
    func performSave()
    func performDownload(coordinates: CLLocationCoordinate2D, page: String?)
}

class AlbumController: UIViewController, NSFetchedResultsControllerDelegate{
    
    var context: NSManagedObjectContext!
    var location: CLLocationCoordinate2D?
    var imageDownloadQueue: ImageDownloadQueue!
    var fetchedResultsController: NSFetchedResultsController?
    var delegate: AlbumControllerDelegate?
    typealias ClosureType = () -> ()
    var collectionUpdates: [ClosureType]!
    
    @IBOutlet weak var resultsIndicator: UIActivityIndicatorView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionBarButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        setFetchedResultsController()
        setUpViews()
    }
    
    override func viewWillAppear(animated: Bool) {
        imageDownloadQueue.downloadQueue.addObserver(self, forKeyPath: "operationCount", options: NSKeyValueObservingOptions.New, context: nil)
        if fetchedResultsController?.delegate == nil {
            fetchedResultsController!.delegate = self
        }
    }
    
    override func viewWillDisappear(animated: Bool) {
        imageDownloadQueue.downloadQueue.removeObserver(self, forKeyPath: "operationCount")
        imageDownloadQueue.downloadQueue.cancelAllOperations()
        fetchedResultsController!.delegate = nil
    }
    
    // MARK: Target Action
    
    @IBAction func collectionButtonPressed(sender: UIBarButtonItem) {
        if collectionBarButton.title == "Save Collection"{
            if let selectedPaths = collectionView.indexPathsForSelectedItems(){
                for indexPath in selectedPaths{
                    if let selectedPicture  = fetchedResultsController?.objectAtIndexPath(indexPath) as? Picture{
                        context.deleteObject(selectedPicture)
                    }
                }
                if selectedPaths.count > 0 {
                    delegate?.performSave()
                }
            }
            //Reset Button Name
            collectionBarButton.title = "New Collection"
        } else if collectionBarButton.title == "New Collection"{
            
            if let pictures = fetchedResultsController?.fetchedObjects as? [Picture]{
                for picture in pictures {
                    context.deleteObject(picture)
                }
                delegate?.performSave()
                //Get new photos
                if let location = location {
                    // Get Random Page Number From 2 - 4
                    let randomUInt = (arc4random() % 3)
                    switch randomUInt {
                    case UInt32(0):
                        delegate?.performDownload(location, page: "2")
                    case UInt32(1):
                        delegate?.performDownload(location, page: "3")
                    case UInt32(2):
                        delegate?.performDownload(location, page: "4")
                    default:
                        print("Error: Default case")
                    }
                }
            }
            
        }
    }
    
    //MARK: - Key Value Observing
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        dispatch_async(dispatch_get_main_queue()){
            self.configureCollectionButton()
        }
        guard (keyPath == "operationCount") else {
            return
        }
        guard let operationCount = change![NSKeyValueChangeNewKey] as? Int else{
            return
        }
        // Download pictures that where pending
        if operationCount == 0 {
            for operationDic in imageDownloadQueue.pendingOperations{
                let privateContext = getChildContext()
                let photoEntity =
                NSEntityDescription.entityForName("Picture", inManagedObjectContext: privateContext)
                let fetch = NSFetchRequest()
                fetch.entity = photoEntity
                let id = operationDic.0
                let predicate = NSPredicate(format: "id == %@", id)
                fetch.predicate = predicate
                
                privateContext.performBlock(){
                    do {
                        let fetchedObjects = try privateContext.executeFetchRequest(fetch)
                        if let photos = fetchedObjects as? [Picture]{
                            if let tempId = photos.first?.objectID{
                                self.backgroundFetch(tempId)
                            }
                        }
                    } catch let error as NSError {
                        print(error.localizedDescription)
                    }
                }
                
            }
        }
    }
    
    //MARK: - Helper Methods
    
    func configureCollectionButton(){
        let pictures =
        (fetchedResultsController?.fetchedObjects as? [Picture])
        var shouldEnabelButton: Bool = true
        if let pictures = pictures {
            for picture in pictures{
                if picture.saved == false {
                    shouldEnabelButton = false
                }
            }
            collectionBarButton.enabled = shouldEnabelButton
        }
    }
    
    func backgroundFetch(tempObjectId: NSManagedObjectID){
        
        let privateContext = getChildContext()
        privateContext.performBlock(){
            let picture = privateContext.objectWithID(tempObjectId) as? Picture
            if let picture = picture{
                let id = picture.id
                let url = picture.url
                let imageDownloadOperation = ImageDownloadOperation(url: url, id: id)
                
                imageDownloadOperation.completionBlock = { () -> Void in
                    privateContext.performBlock(){
                        if picture.pictureExistInDirectory(){
                            self.imageDownloadQueue.pendingOperations.removeValueForKey(id)
                            picture.saved = true
                            do {
                                try privateContext.save()
                            } catch let error as NSError {
                                print(error.localizedDescription)
                            }
                        } else {
                            picture.saved = false
                            do {
                                try privateContext.save()
                            } catch let error as NSError {
                                print(error.localizedDescription)
                            }
                        }
                    }
                }
                // Add to pending operation list, Add to downloadQueue
                self.imageDownloadQueue.pendingOperations[id] = imageDownloadOperation
                self.imageDownloadQueue.downloadQueue.addOperation(imageDownloadOperation)
            }
        }
        
    }
    
    func getChildContext() -> NSManagedObjectContext{
        let privateChild = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.PrivateQueueConcurrencyType)
        privateChild.parentContext = context
        return privateChild
    }
    
    func setFetchedResultsController(){
        let fetch = NSFetchRequest()
        let description =
        NSEntityDescription.entityForName("Picture", inManagedObjectContext: self.context)
        fetch.entity = description
        // Create Predicate for fetch
        let lat = (self.location!.latitude as Double).description
        let lon = (self.location!.longitude as Double).description
        let predicate = NSPredicate(format: "album.latitude == %@ && album.longitude == %@", lat,lon)
        fetch.predicate = predicate
        fetch.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]
        self.fetchedResultsController =
            NSFetchedResultsController(fetchRequest: fetch, managedObjectContext: self.context, sectionNameKeyPath: nil, cacheName: nil)
        self.fetchedResultsController!.delegate = self
        // Execute Fetch
        do{
            try self.fetchedResultsController!.performFetch()
        }catch let error as NSError{
            print("error: \(error.localizedDescription)")
        }
    }
    
    func setUpViews() {
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = true
        automaticallyAdjustsScrollViewInsets = false
        resultsIndicator.startAnimating()
        resultsIndicator.hidden = false
        
        if let location = location {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location
            mapView.addAnnotation(annotation)
            let cammera =
            MKMapCamera(lookingAtCenterCoordinate: location, fromEyeCoordinate: location, eyeAltitude: 100000)
            mapView.setCamera(cammera, animated: true)
        }
    }
    
    //MARK: - NSFetchedResultsController Delegate Methods
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        collectionUpdates = [ClosureType]()
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        collectionView.performBatchUpdates({ () -> Void in
            for updateBlock in self.collectionUpdates {
                updateBlock()
            }
            }, completion: nil)
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
        case .Insert:
            collectionUpdates.append({
                self.collectionView.insertItemsAtIndexPaths([newIndexPath!])
            })
            
        case .Delete:
            collectionUpdates.append({
                self.collectionView.deleteItemsAtIndexPaths([indexPath!])
            })
        case .Update:
            collectionUpdates.append( {
                self.collectionView.reloadItemsAtIndexPaths([indexPath!])
            })
        default:
            return
        }
    }
}

extension AlbumController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    // MARK: - UICollection DataSource Methods
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("CollectionCell", forIndexPath: indexPath) as! PhotoCollectionView
        let picture =
        self.fetchedResultsController!.fetchedObjects![indexPath.row] as! Picture
        
        if picture.pictureExistInDirectory() == true {
            cell.activityIndicator.stopAnimating()
        } else {
            // Add to download queue if necessary
            cell.activityIndicator.startAnimating()
            collectionBarButton.enabled = false
            if (imageDownloadQueue.pendingOperations[picture.id] == nil){
                let objectId = picture.objectID
                backgroundFetch(objectId)
            }
        }
        
        cell.imageView.image = picture.photo()!
        
        // Cell is reused so deleteLabel must always configured.
        cell.deleteLabel.hidden = true
        cell.imageView.alpha = 1
        if let indexPaths = collectionView.indexPathsForSelectedItems(){
            if indexPaths.indexOf(indexPath) != nil{
                cell.deleteLabel.hidden = false
                cell.imageView.alpha = 0.5
            }
        }
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if fetchedResultsController?.fetchedObjects?.count == nil {
            return 0
        }
        let objectsCount = fetchedResultsController!.fetchedObjects!.count
        if objectsCount > 0 {
            resultsIndicator.stopAnimating()
        }
        return objectsCount
    }
    
    // MARK: - UICollection Delegate Methods
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        if let cell = collectionView.cellForItemAtIndexPath(indexPath){
            if let collectionCell = cell as? PhotoCollectionView{
                collectionCell.deleteLabel.hidden = false
                collectionCell.imageView.alpha = 0.5
                collectionBarButton.title = "Save Collection"
            }
        }
    }
    
    func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        if let cell = collectionView.cellForItemAtIndexPath(indexPath){
            if let collectionCell = cell as? PhotoCollectionView{
                collectionCell.deleteLabel.hidden = true
                collectionCell.imageView.alpha = 1
                if collectionView.indexPathsForSelectedItems()!.count == 0{
                    collectionBarButton.title = "New Collection"
                }
            }
        }
    }
    
}
