//
//  BarButtonView.swift
//  ImageGallery
//
//  Created by Peter Wu on 8/16/18.
//  Copyright © 2018 Peter Wu. All rights reserved.
//

import UIKit

class BarButtonView: UIView {
    
    var backgroundImage: UIImage? { didSet { setNeedsDisplay() } }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func draw(_ rect: CGRect) {
        // Drawing code
        if backgroundImage != nil {
            backgroundImage?.draw(in: rect)
        }
    }
    

}
