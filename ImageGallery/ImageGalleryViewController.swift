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
            var imageInfos = [ImageGallery.ImageInfo]()
            if galleryImages != nil {
                for galleryImage in galleryImages! {
                    if let url = galleryImage.resource as? URL {
                        imageInfos.append(ImageGallery.ImageInfo(url: url, aspectRatio: galleryImage.aspectRatio, fileName: nil))
                    } else if let fileName = galleryImage.resource as? String {
                        imageInfos.append(ImageGallery.ImageInfo(url: nil, aspectRatio: galleryImage.aspectRatio, fileName: fileName))
                    }
                }
                return ImageGallery(imageInfos: imageInfos)
            } else {
                return nil
            }
        }
        set {
            // reset view from new value
            if let imageInfos = newValue?.imageInfos {
                galleryImages = [(resource: Resource, aspectRatio: CGFloat)]()
                for imageInfo in imageInfos {
                    if let url = imageInfo.url {
                        galleryImages?.append((url, imageInfo.aspectRatio))
                    } else if let fileName = imageInfo.fileName {
                        galleryImages?.append((fileName, imageInfo.aspectRatio))
                    }
                }
            }
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
        self.document?.close() { success in
            self.dismiss(animated: true)
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
            return session.canLoadObjects(ofClass: NSURL.self) || session.canLoadObjects(ofClass: NSString.self)
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
                let removedImage = galleryImages?.remove(at: sourceIndexPath.item)
                if let fileName = removedImage?.resource as? String {
                    removeLocalImage(fileName: fileName)
                }
                imageGalleryCollectionView.deleteItems(at: [sourceIndexPath])
            })
            dragItemIndexPath = nil
            documentChanged()
            
            
        }
        
    }
    
    private func removeLocalImage(fileName: String) {
        if let url = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(fileName) {
            do {
                try FileManager.default.removeItem(atPath: url.path)
            } catch let error {
                print("error \(error) removing file at \(url.path)")
            }
        }
    }
    
    // MARK: - COLLECTION VIEW
    
    private var galleryImages: [(resource: Resource, aspectRatio: CGFloat)]?
    
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
			guard let galleryImage = galleryImages?[indexPath.item] else { return cell }
            if let image = fetchImage(from: galleryImage.resource, at: indexPath.item) {
                imageCell.imageView.image = image
            } else {
                imageCell.imageView.image = UIImage(named: "FrownFace")
            }
            // spinner hides automatically when it stops animating
            imageCell.spinner.stopAnimating()

        }
        return cell
    }
	
    private let cache = URLCache.shared
    
    private  func fetchImage(from resource: Resource, at index: Int) -> UIImage? {
        if let url = resource as? URL {
            if let image = self.fetchImageFromUrl(url: url) {
                return image
            } else {
                if let localImage = tempGalleryImages?.first(where: { (temp) -> Bool in
                    temp.url == url
                }) {
                    if let imageFile: (image: UIImage, fileNme: String) = storeImageToFile(image: localImage.image) {
                        updateResource(resource: resource, at: index, with: imageFile.fileNme)
                        return fetchLocalImage(fileName: imageFile.fileNme)
                    }
                }
            }
        } else if let fileName = resource as? String {
            return fetchLocalImage(fileName: fileName)
        }
        return nil
	}
    
    private func updateResource(resource: Resource, at index: Int, with fileName: String) {
        galleryImages?[index].resource = fileName
        documentChanged()
    }
    
    private func storeImageToFile(image: UIImage) -> (UIImage, String)? {
        if let imageData = UIImageJPEGRepresentation(image, 1.0) {
            // locate file directory
            let date = Date().timeIntervalSince1970
            let dateInString = String(describing: date)
            if let fileurl = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent(dateInString) {
                // create file with local component
                if FileManager.default.createFile(atPath: fileurl.path, contents: imageData, attributes: nil) {
                    if let retrievedImage = fetchLocalImage(fileName: dateInString) {
                        return (retrievedImage, dateInString)
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
        guard let imageData = data else { return nil }
        return UIImage(data: imageData)
    }
    
    private func fetchLocalImage(fileName: String) -> UIImage? {
        if let url = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(fileName), let imageData = try? Data(contentsOf: url) {
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
            var provider: NSItemProvider?
            if let urlProvider = image.resource as? NSURL {
                provider = NSItemProvider(object: urlProvider)
            } else if let stringProvider = image.resource as? NSString {
                provider = NSItemProvider(object: stringProvider)
            }
            let dragItem = UIDragItem(itemProvider: provider!)
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
            canHandle = session.canLoadObjects(ofClass: NSURL.self) || session.canLoadObjects(ofClass: NSString.self)
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
                    let imageInfo = item.dragItem.localObject as? (Resource, CGFloat) {
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
                    let image: (Resource, CGFloat) = (url, aspectRatio)
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
