//
//  ImageGallery.swift
//  Image Gallery
//
//  Created by Peter Wu on 7/30/18.
//  Copyright © 2018 Peter Wu. All rights reserved.
//

import Foundation
import UIKit

struct ImageGallery: Codable {
	
    struct ImageInfo: Codable {
        var url: URL?
        var aspectRatio: CGFloat
        var fileName: String?
    }
    
	var imageInfos: [ImageInfo]
    
    var jsonData: Data? {
        return try? JSONEncoder().encode(self)
    }
	
    init(imageInfos: [ImageInfo]) {
        self.imageInfos = imageInfos
    }
    
    init?(data: Data) {
        if let newValue = try? JSONDecoder().decode(ImageGallery.self, from: data) {
            self = newValue
        } else {
            return nil
        }
    }
		
}
