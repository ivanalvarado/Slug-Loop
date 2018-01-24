//
//  Bus.swift
//  SlugBus
//
//  Created by Ivan Alvarado on 1/24/18.
//  Copyright © 2018 UCSC Slugs. All rights reserved.
//

import MapKit
import UIKit

class Bus: NSObject, MKAnnotation {
    var title: String?
    var subtitle: String?
    dynamic var coordinate: CLLocationCoordinate2D
    var closestInnerStop = -1
    var closestOuterStop = -1
    var id: String
    var direc: String
    var exists: Bool
    var imageName: String!
    var innerETA = 0
    var outerETA = 0
    
    init(title: String, coordinate: CLLocationCoordinate2D, id: String, direc: String, exists: Bool, imageName: String!) {
        self.title = title
        self.coordinate = coordinate
        self.id = id
        self.direc = direc
        self.exists = exists
        self.imageName = imageName
    }
}
