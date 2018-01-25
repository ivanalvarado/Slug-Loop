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
    var quadrant: Int
    var angle: Double = -1.0
    var direc: String = ""
    var exists: Bool
    var imageName: String = ""
    var innerETA = 0
    var outerETA = 0
    
    init(title: String, coordinate: CLLocationCoordinate2D, id: String, quadrant: Int, exists: Bool) {
        self.title = title
        self.coordinate = coordinate
        self.id = id
        self.quadrant = quadrant
        self.exists = exists
    }
}
