//
//  ImageViewController.swift
//  Image Gallery
//
//  Created by Peter Wu on 8/3/18.
//  Copyright © 2018 Peter Wu. All rights reserved.
//

import UIKit

class ImageViewController: UIViewController, UIScrollViewDelegate {

	// MARK: View
	@IBOutlet weak var spinner: UIActivityIndicatorView!
	
	@IBOutlet weak var scrollViewHeight: NSLayoutConstraint!
	@IBOutlet weak var scrollViewWidth: NSLayoutConstraint!
	
	var imageView = UIImageView()
	
	@IBOutlet weak var scrollView: UIScrollView! {
		didSet {
			scrollView.delegate = self
			scrollView.minimumZoomScale = 0.2
			scrollView.maximumZoomScale = 5.0
			scrollView.addSubview(imageView)
		}
	}
	
	
	var image: UIImage? {
		get {
			return imageView.image
		}
		set {
			scrollView?.zoomScale = 1.0
			// after image is loaded, set image view and resize the image view, and scroll view content size
			imageView.image = newValue
			let size = newValue?.size ?? CGSize(width: 0, height: 0)
			imageView.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: size)
			imageView.setNeedsDisplay()
			scrollView?.contentSize = size
			scrollViewHeight?.constant = size.height
			scrollViewWidth?.constant = size.width
			// reset zoom factor to display picture to the bounds of either height or width
			let widthScaleFactor = view.bounds.size.width / size.width
			let heightScaleFactor = view.bounds.size.height / size.height
			scrollView?.zoomScale = max(widthScaleFactor, heightScaleFactor)
			spinner?.stopAnimating()
		}
	}
	

	
	// MARK: Zooming
	func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return imageView
	}
	
	func scrollViewDidZoom(_ scrollView: UIScrollView) {
		scrollViewHeight.constant = scrollView.contentSize.height
		scrollViewWidth.constant = scrollView.contentSize.width
	}
	
}
