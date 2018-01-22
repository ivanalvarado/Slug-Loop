//
//  ViewController.swift
//  SlugBus
//
//  Created by Ivan Alvarado on 1/22/18.
//  Copyright © 2018 UCSC Slugs. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Center map on UCSC campus
        let ucscCampusLocation: CLLocationCoordinate2D = CLLocationCoordinate2DMake(36.9900, -122.0605)
        let distanceSpan: MKCoordinateSpan = MKCoordinateSpanMake(0.03, 0.03)
        mapView.setRegion(MKCoordinateRegionMake(ucscCampusLocation, distanceSpan), animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

