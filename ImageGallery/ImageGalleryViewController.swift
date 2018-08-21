//
//  ImageGalleryViewController.swift
//  Image Gallery
//
//  Created by Peter Wu on 7/22/18.
//  Copyright © 2018 Peter Wu. All rights reserved.
//

import UIKit

class ImageGalleryViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UICollectionViewDropDelegate, UICollectionViewDragDelegate, UIDropInteractionDelegate {
    
    // MARK: - Model
    var imageGallery: ImageGallery? {
        get {
            // retrieve data from the view, then instantiate imagegallery data
            if let imageInfos = galleryImages?.map({ ImageGallery.ImageInfo(url: $0.url, aspectRatio: $0.aspectRatio, localUrlPathComponent: $0.localUrlPathComponent) }) {
                return ImageGallery(imageInfos: imageInfos)
            } else {
                return nil
            }
        }
        set {
            // reset view from new value
            galleryImages = newValue?.imageInfos.map { ($0.url, $0.aspectRatio, $0.localUrlPathComponent) }
            imageGalleryCollectionView.reloadData()
        }
    }
	
    var document: ImageGalleryDocument?
    
    // MARK: - Navigation item configuration
    
    @IBOutlet weak var trashBarButton: UIBarButtonItem! {
        didSet {
            trashBarButton.customView = createDropInteractionView()
        }
    }
    
    
//    @IBAction func save(_ sender: UIBarButtonItem? = nil) {
    private func documentChanged() {
        document?.imageGallery = imageGallery
        if document?.imageGallery != nil {
            document?.updateChangeCount(.done)
        }
    }
	
    @IBAction func close(_ sender: UIBarButtonItem) {
//        save()
        if let firstCell = imageGalleryCollectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? ImageCollectionViewCell {
            if document?.imageGallery != nil {
                document?.thumbnail = firstCell.imageView.snapshot
            }
        }
        dismiss(animated: true) {
            self.document?.close()
        }
    }
    
    private func createDropInteractionView() -> UIView {
        let frame = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 50))
        let button = UIButton(type: UIButtonType.system)
        button.frame = frame
        button.setImage(UIImage(named: "trashcan2"), for: .normal)
        button.addInteraction(UIDropInteraction(delegate: self))
        return button
    }
  
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        document?.open { success in
            if success {
                self.title = self.document?.localizedName
                self.imageGallery = self.document?.imageGallery
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        document?.close()
    }
    
    // MARK: - Navigation Bar Button - drop to delete
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        if (session.localDragSession?.localContext as? UICollectionView) == imageGalleryCollectionView {
            return session.canLoadObjects(ofClass: NSURL.self)
        } else {
            return false
        }
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        return UIDropProposal(operation: .move)
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidEnter session: UIDropSession) {
        
        for item in session.items {
            let dropPreview = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
            dropPreview.backgroundColor = UIColor.red
            dropPreview.alpha = 0.5
            item.previewProvider = {
                return UIDragPreview(view: dropPreview)
            }
        }
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, sessionDidExit session: UIDropSession) {
        for item in session.items {
            item.previewProvider = nil
        }
    }
    
    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        
        if let sourceIndexPath = dragItemIndexPath {
            imageGalleryCollectionView.performBatchUpdates({
                galleryImages?.remove(at: sourceIndexPath.item)
                imageGalleryCollectionView.deleteItems(at: [sourceIndexPath])
            })
            dragItemIndexPath = nil
            documentChanged()
            
            
        }
        
    }
    
    // MARK: - COLLECTION VIEW
    
    private var galleryImages: [(url: URL, aspectRatio: CGFloat, localUrlPathComponent: String?)]?
    
    private var tempGalleryImages: [(url: URL, image: UIImage)]?
    
    // MARK: Outlet
    @IBOutlet weak var imageGalleryCollectionView: UICollectionView! {
        didSet {
            imageGalleryCollectionView.dropDelegate = self
            imageGalleryCollectionView.dragDelegate = self
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(zoom(_:)))
            imageGalleryCollectionView.addGestureRecognizer(pinch)
            imageGalleryCollectionView.dragInteractionEnabled = true
        }
    }
    
    // MARK: View
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return galleryImages?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath)
        if let imageCell = cell as? ImageCollectionViewCell {
            imageCell.spinner.isHidden = false
			guard let galleryImageInfo = galleryImages?[indexPath.item] else { return cell }
			fetchImage(imageInfo: (galleryImageInfo.url, galleryImageInfo.localUrlPathComponent)) { [weak self] (image, localUrlPathComponent) in
                self?.galleryImages?[indexPath.item].localUrlPathComponent = localUrlPathComponent
                self?.documentChanged()
                if let image = image {
                    imageCell.imageView.image = image
                } else {
                    // If there's no image loaded, show image with frown face
                    print("invalid URL: \(galleryImageInfo.url)")
                    imageCell.imageView.image = UIImage(named: "FrownFace")
                }
                // spinner hides automatically when it stops animating
                imageCell.spinner.stopAnimating()
            }
        }
        return cell
    }
	
    private let cache = URLCache.shared
    
    private  func fetchImage(imageInfo: (url: URL, localUrlPathComponent: String?) ,completion: @escaping (UIImage?, String?) -> Void) {
        var image: UIImage?
        var localUrlPathComponent: String?
		DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let localUrlPathComponent = imageInfo.localUrlPathComponent {
                image = self?.fetchLocalImage(localUrlPathComponent: localUrlPathComponent)
            } else {
                if let fetchedImage = self?.fetchImageFromUrl(url: imageInfo.url){
                    image = fetchedImage
                } else {
                    if let imageInfo = self?.storeLocalImage(url: imageInfo.url) {
                        let localImage = imageInfo.0; let pathComponent = imageInfo.1
                        image = localImage
                        localUrlPathComponent = pathComponent
                    }
                }
            }
            DispatchQueue.main.async {
                completion(image, localUrlPathComponent)
            }
        }
	}
    
    private func storeLocalImage(url: URL) -> (UIImage?, String)? {
        if tempGalleryImages != nil {
            //grab image from temp image array where the UIImage was dropped
            var tempImage: UIImage?
            for tempGalleryImage in tempGalleryImages! {
                if tempGalleryImage.url == url {
                    tempImage = tempGalleryImage.image
                }
            }
            // create local file storage for the local image
            if let localImage = tempImage, let imageData = UIImageJPEGRepresentation(localImage, 1.0) {
                
                // locate file directory
                let date = Date().timeIntervalSince1970
                let dateInString = String(describing: date)
                if let fileurl = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(dateInString) {
                    // create file with local component
                    if FileManager.default.createFile(atPath: fileurl.path, contents: imageData, attributes: nil) {
                        if let retrievedImage = fetchLocalImage(localUrlPathComponent: dateInString) {
                            return (retrievedImage, dateInString)
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private func fetchImageFromUrl(url: URL) -> UIImage? {
        // cache response from url
        var data: Data?
        if let cachedResponse = cache.cachedResponse(for: URLRequest(url: url.imageURL)) {
            data = cachedResponse.data
        } else {
            data = try? Data(contentsOf: url.imageURL)
        }
        guard let imageData = data else { return nil}
        return UIImage(data: imageData)
    }
    
    private func fetchLocalImage(localUrlPathComponent: String) -> UIImage? {
        if let url = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(localUrlPathComponent), let imageData = try? Data(contentsOf: url) {
            return UIImage(data: imageData)
        }
        return nil
    }
    // MARK: Layout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellWidth = view.frame.width.zoomedBy(zoomFactor)
        let aspectRatio = galleryImages?[indexPath.item].aspectRatio ?? 1.0
        let cellHeight = cellWidth / aspectRatio
        return CGSize(width: cellWidth, height: cellHeight)
    }
    
    private var zoomFactor: CGFloat = 0.2 {
        didSet {
            // collectionView to layout cells again when zoom factor changes (which changes cell width)
            imageGalleryCollectionView.collectionViewLayout.invalidateLayout()
        }
    }
    
    private struct AspectRatio {
        static let widthToViewRatio: CGFloat = 0.2
        static func calcAspectRatio(size: CGSize) -> CGFloat {
            let width = size.width
            let height = size.height
            let aspectRatio = width / height
            return aspectRatio
        }
    }
    
    // MARK: Drag
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        // Provide local context to drag session, so that it'll be easy to distinguish in-app vs external drag
        session.localContext = collectionView
        return dragItems(at: indexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        return dragItems(at: indexPath)
    }
    
    var dragItemIndexPath: IndexPath?
    
    private func dragItems(at indexPath: IndexPath) -> [UIDragItem] {
        // The drag item is created from URL only, but it carries the whole imageTask in localObject which will allow rearranging items within the drag and drop view
        if let image = galleryImages?[indexPath.item] {
            let urlProvider = image.url as NSURL
            let urlItemProvider = NSItemProvider(object: urlProvider)
            let dragItem = UIDragItem(itemProvider: urlItemProvider)
            dragItem.localObject = image
            dragItemIndexPath = indexPath
            return [dragItem]
        } else {
            return []
        }
    }
	
    // MARK: Drop
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        // The drop accepts NSURL only if it's within collection view (saved by local context).  External data from outside of the app must have both URL and image to be accepted.
        var canHandle: Bool
        if (session.localDragSession?.localContext as? UICollectionView) == collectionView {
            canHandle = session.canLoadObjects(ofClass: NSURL.self)
        } else {
            canHandle = session.canLoadObjects(ofClass: NSURL.self) && session.canLoadObjects(ofClass: UIImage.self)
        }
        return canHandle
    }
	
	
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        // Could be called many, many times.  Return quickly!
        let isSelf = (session.localDragSession?.localContext as? UICollectionView) == collectionView
        return UICollectionViewDropProposal(operation: isSelf ? .move : .copy, intent: .insertAtDestinationIndexPath)
    }
    
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        for item in coordinator.items {
            
            if item.isLocal {
                
                if let sourceIndexPath = item.sourceIndexPath,
                    let destinationIndexPath = coordinator.destinationIndexPath,
                    let imageInfo = item.dragItem.localObject as? (URL, CGFloat, String?) {
                    imageGalleryCollectionView.performBatchUpdates({
                        galleryImages?.remove(at: sourceIndexPath.item)
                        galleryImages?.insert(imageInfo, at: destinationIndexPath.item)
                        imageGalleryCollectionView.deleteItems(at: [sourceIndexPath])
                        imageGalleryCollectionView.insertItems(at: [destinationIndexPath])
                    })
                    coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
                    documentChanged()
                }
                
            } else {
                
                guard item.dragItem.itemProvider.canLoadObject(ofClass: NSURL.self) && item.dragItem.itemProvider.canLoadObject(ofClass: UIImage.self) else { return }
                let destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(item: 0, section: 0)
                
                // Use placeholder cell while waiting for image and url to load.  The image task handler will replace placeholder cell with final content when both image and url are loaded.
                let placeHolder = UICollectionViewDropPlaceholder(insertionIndexPath: destinationIndexPath, reuseIdentifier: "DropPlaceholderCell")
                let placeholderContext = coordinator.drop(item.dragItem, to: placeHolder)
				let taskHandler = TaskHandler { (url, aspectRatio, image) in
                    if self.tempGalleryImages != nil {
                        self.tempGalleryImages!.append((url, image))
                    } else {
                        self.tempGalleryImages = [(url, image)]
                    }
                    let localurl: String? = nil
                    let image = (url, aspectRatio, localurl)
					// weak reference to view controller because user may switch to a different document before image is loaded
					placeholderContext.commitInsertion(dataSourceUpdates: { [weak self] indexPath in
                        if self?.galleryImages != nil {
                            self?.galleryImages?.insert((image), at: indexPath.item)
                        } else {
                            self?.galleryImages = [image]
                        }
                        self?.documentChanged()
					})
				}
                // load URL and image asynchronously, then process handler
                item.dragItem.itemProvider.loadObject(ofClass: NSURL.self) { (provider, error) in
                    // receive imageURL data, and update data source while remove placeholder in main thread
                    DispatchQueue.main.async {
                        if let imageURL = provider as? URL {
                            taskHandler.url = imageURL
                            taskHandler.process()
                        }
                    }
                }
                item.dragItem.itemProvider.loadObject(ofClass: UIImage.self) { (provider, error) in
                    DispatchQueue.main.async {
                        if let loadedImage = provider as? UIImage {
                            let aspectRatio = AspectRatio.calcAspectRatio(size: loadedImage.size)
                            taskHandler.image = loadedImage
                            taskHandler.aspectRatio = aspectRatio
                            taskHandler.process()
                        }
                    }
                }
                
            }
        }
    }
    
    // MARK: - Gesture
    @objc func zoom(_ pinchGestureRecognizer: UIPinchGestureRecognizer) {
        switch pinchGestureRecognizer.state {
        case .changed: // changes the zoom factor by the scale
            zoomFactor *= pinchGestureRecognizer.scale
            pinchGestureRecognizer.scale = 1.0 // reset scale so that it's not cumulative
            documentChanged()
        default: return
        }
        
    }
    
    // MARK: - Navigation

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if segue.identifier == "ShowImage" {
			if let imageVC = segue.destination as? ImageViewController {
				if let imageCell = sender as? ImageCollectionViewCell {
					imageVC.image = imageCell.imageView.image
				}
			}
		}
	}

}
