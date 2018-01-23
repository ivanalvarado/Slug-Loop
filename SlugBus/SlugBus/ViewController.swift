//
//  ViewController.swift
//  SlugBus
//
//  Created by Ivan Alvarado on 1/22/18.
//  Copyright © 2018 UCSC Slugs. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    var locationManager: CLLocationManager!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Center map on UCSC campus
        let ucscCampusLocation: CLLocationCoordinate2D = CLLocationCoordinate2DMake(36.9900, -122.0605)
        let distanceSpan: MKCoordinateSpan = MKCoordinateSpanMake(0.03, 0.03)
        mapView.setRegion(MKCoordinateRegionMake(ucscCampusLocation, distanceSpan), animated: true)
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // If we don't have access to the user's current location, request it
        if (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse) {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    /*
     Called whenever the user's location is updated.
     */
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .denied:
            print("Denied")
            break
        case .notDetermined:
            print("Not Determined")
            locationManager.requestWhenInUseAuthorization()
            break
        case .authorizedWhenInUse:
            print("Authorized When In Use")
            mapView.showsUserLocation = true
            locationManager.startUpdatingLocation()
            break
        default:
            break
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

