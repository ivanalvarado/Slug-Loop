//
//  BusStop.swift
//  SlugBus
//
//  Created by Ivan Alvarado on 1/22/18.
//  Copyright © 2018 UCSC Slugs. All rights reserved.
//

import MapKit
import UIKit

/*
 * Class for Bus Stop objects.
 */
class BusStop: NSObject, MKAnnotation {
    var title: String?
    var subtitle: String?
    var coordinate: CLLocationCoordinate2D
    var info: String
    var customImage: Bool = true
    var listIndex: Int
    var imageName: UIImage!
    var beforeStop: CLCircularRegion
    var afterStop: CLCircularRegion
    var etaToNextStop: Int

    init(title: String, subtitle: String, coordinate: CLLocationCoordinate2D, info: String, listIndex: Int, imageName: UIImage!, beforeStop: CLCircularRegion, afterStop: CLCircularRegion, etaToNextStop: Int) {
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.info = info
        self.listIndex = listIndex
        self.imageName = imageName
        self.beforeStop = beforeStop
        self.afterStop = afterStop
        self.etaToNextStop = etaToNextStop
    }
}
