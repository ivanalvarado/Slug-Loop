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
import SwiftyJSON

class ViewController: UIViewController, CLLocationManagerDelegate {
    
    let UCSC_CAMPUS_LOCATION: CLLocationCoordinate2D = CLLocationCoordinate2DMake(36.9900, -122.0605)
    let DISTANCE_SPAN: MKCoordinateSpan = MKCoordinateSpanMake(0.03, 0.03)
    let url = NSURL(string: "http://bts.ucsc.edu:8081/location/get")

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var toggleBusStopsButton: UIButton!
    @IBOutlet weak var recenterButton: UIButton!
    @IBOutlet weak var closestBusStopView: UIView!
    
    var locationManager: CLLocationManager!
    var cwBusStopList  = [BusStop]()  // Clockwise Bus Stops
    var ccwBusStopList = [BusStop]()  // Counter Clockwise Bus Stops
    var oldMainBusList = [String: Bus]()
    var newMainBusList = [String: Bus]()
    var areBusStopsShowing = true
    
    var timer = Timer()
    
    // Bus Stops
    var ccwBusStop0, ccwBusStop1, ccwBusStop2, ccwBusStop3, ccwBusStop4, ccwBusStop5, ccwBusStop6, ccwBusStop7, ccwBusStop8, ccwBusStop9, ccwBusStop10, ccwBusStop11, ccwBusStop12, ccwBusStop13, ccwBusStop14, ccwBusStop15, cwBusStop0, cwBusStop1, cwBusStop2, cwBusStop3, cwBusStop4, cwBusStop5, cwBusStop6, cwBusStop7, cwBusStop8, cwBusStop9, cwBusStop10, cwBusStop11, cwBusStop12: BusStop!
    
    /*
     * Fires at the start of the app.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        updateButtonUi()
        
        // Center map on UCSC campus
        mapView.setRegion(MKCoordinateRegionMake(UCSC_CAMPUS_LOCATION, DISTANCE_SPAN), animated: true)
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // If we don't have access to the user's current location, request it
        if (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse) {
            locationManager.requestWhenInUseAuthorization()
        }
        
        buildBusStopLists()
        displayBusStops()
        
        timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(fetchBusData), userInfo: nil, repeats: true)
//        fetchBusData()
    }
    
    /*
     * Makes a URL request in order to retrieve JSON bus data.
     */
    @objc func fetchBusData() {
        let url = URL(string: "http://bts.ucsc.edu:8081/location/get")
        if let usableUrl = url {
            let request = URLRequest(url: usableUrl)
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                if let data = data {
                    if let stringData = String(data: data, encoding: String.Encoding.utf8) {
                        print(stringData)
                        do {
                            let jsonData = try JSON(data: data)
                            print(jsonData.count)
                            
                            if jsonData.count == 0 {
                                // Todo: Alert the user no buses are active.
                            }
                            
                            if self.oldMainBusList.isEmpty {
                                // We're fetching bus data for the first time, thus we don't know bus directions.
                                // Todo: Display progress dialog while we determine bus directions.
                                
                                self.buildGlobalBusList(readableJson: jsonData, isOld: true)
                            } else {
                                
                                if self.newMainBusList.isEmpty {
                                    self.buildGlobalBusList(readableJson: jsonData, isOld: false)
                                    self.determineBusDirections()
                                    self.addBusesToMapView()
                                } else {
                                    self.oldMainBusList = self.newMainBusList
                                    self.updateNewMainBusList(readableJson: jsonData)
                                }
                            }
                            
                        } catch {
                            // Todo: Fail gracefully.
                            print("Error")
                        }
                        
                    }
                }
            })
            task.resume()
        }
    }
    
    func updateNewMainBusList(readableJson: JSON) {
        
        DispatchQueue.main.async {
            for bus in readableJson {
                let busId = bus.1["id"].string!
                
                if self.newMainBusList[busId] != nil {
                    let newLat = Double(bus.1["lat"].double!)
                    let newLon = Double(bus.1["lon"].double!)
                    let newCoord = CLLocationCoordinate2D(latitude: newLat, longitude: newLon)
                    self.newMainBusList[busId]?.coordinate = newCoord
                } else {
                    let newMarker = MKPointAnnotation()
                    let lat = Double(bus.1["lat"].double!)
                    let lon = Double(bus.1["lon"].double!)
                    newMarker.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let quadrant = self.determineMapQuadrant(lat: lat, lon: lon)
                    let busAngle = self.determineBusAngle(lat: lat, lon: lon, quadrant: quadrant)
                    
                    self.newMainBusList[bus.1["id"].string!] = (Bus(title: bus.1["type"].string!, coordinate: newMarker.coordinate, id: bus.1["id"].string!, quadrant: quadrant, angle: busAngle, exists: true))
                }
            }
        }
        
    }
    
    /*
     * Adds an annotation for each active bus onto the MapView.
     */
    func addBusesToMapView() {
        DispatchQueue.main.async {
            for busId in self.newMainBusList.keys {
                self.mapView.addAnnotation(self.newMainBusList[busId]!)
            }
        }
    }
    
    /*
     * Builds global bus list structure by extracting data from publicly available JSON.
     */
    func buildGlobalBusList(readableJson: JSON, isOld: Bool) {
        
        for bus in readableJson {
            print("bus = \(bus.1)")
            let newMarker = MKPointAnnotation()
            let lat = Double(bus.1["lat"].double!)
            let lon = Double(bus.1["lon"].double!)
            newMarker.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let quadrant = determineMapQuadrant(lat: lat, lon: lon)
            let busAngle = determineBusAngle(lat: lat, lon: lon, quadrant: quadrant)
            
            if isOld { // Old data.
                oldMainBusList[bus.1["id"].string!] = (Bus(title: bus.1["type"].string!, coordinate: newMarker.coordinate, id: bus.1["id"].string!, quadrant: quadrant, angle: busAngle, exists: true))
            } else {
                newMainBusList[bus.1["id"].string!] = (Bus(title: bus.1["type"].string!, coordinate: newMarker.coordinate, id: bus.1["id"].string!, quadrant: quadrant, angle: busAngle, exists: true))
            }
        }
    }
    
    /*
     * Determin which quadrant on the map the current bus lies in.
     */
    func determineMapQuadrant(lat: Double, lon: Double) -> Int {
        if lat > 36.9900 {
            return lon > -122.0605 ? 1 : 2
        } else {
            return lon > -122.0605 ? 4 : 3
        }
    }
    
    /*
     * Determine angle of current position.
     */
    func determineBusAngle(lat: Double, lon: Double, quadrant: Int) -> Double {
        let p2: CLLocation
        let angleAggregrate: Double
        switch quadrant {
        case 1:
            p2 = CLLocation(latitude: UCSC_CAMPUS_LOCATION.latitude, longitude: -122.0471)
            angleAggregrate = 0.0
            break
        case 2:
            p2 = CLLocation(latitude: 37.0030, longitude: UCSC_CAMPUS_LOCATION.longitude)
            angleAggregrate = 90.0
            break
        case 3:
            p2 = CLLocation(latitude: UCSC_CAMPUS_LOCATION.latitude, longitude: -122.0740)
            angleAggregrate = 180.0
            break
        case 4:
            p2 = CLLocation(latitude: 36.9732, longitude: UCSC_CAMPUS_LOCATION.longitude)
            angleAggregrate = 270.0
            break
        default:
            p2 = CLLocation(latitude: UCSC_CAMPUS_LOCATION.latitude, longitude: UCSC_CAMPUS_LOCATION.longitude)
            angleAggregrate = 0.0
            break
        }
        
        let p1 = CLLocation(latitude: UCSC_CAMPUS_LOCATION.latitude, longitude: UCSC_CAMPUS_LOCATION.longitude)
        let p3 = CLLocation(latitude: lat, longitude: lon)
        
        let p_12 = p1.distance(from: p2)
        let p_13 = p1.distance(from: p3)
        let p_23 = p2.distance(from: p3)
        
        let rad = ((p_12*p_12) + (p_13*p_13) - (p_23*p_23))/(2 * p_12 * p_13)
        
        return (acos(rad)*180.0)/Double.pi + angleAggregrate
    }
    
    /*
     * Determine whether bus is Inner/Outer Loop.
     */
    func determineBusDirections() {
        for busId in newMainBusList.keys {
            let newBusData = newMainBusList[busId]
            if let oldBusData = oldMainBusList[busId] {
                if (newBusData?.angle)! > oldBusData.angle {
                    newMainBusList[busId]?.direc = "Outer"
                } else {
                    newMainBusList[busId]?.direc = "Inner"
                }
            } else {
                // New bus, don't do anything because it's already been added to the new list.
            }
        }
    }
    
    /*
     * Add styling to the UIButtons that hover above MapView.
     */
    func updateButtonUi() {
        toggleBusStopsButton.layer.cornerRadius = 4
        toggleBusStopsButton.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.25).cgColor
        toggleBusStopsButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        toggleBusStopsButton.layer.shadowOpacity = 1.0
        toggleBusStopsButton.layer.shadowRadius = 4
        toggleBusStopsButton.layer.masksToBounds = false
        
        recenterButton.layer.cornerRadius = 4
        recenterButton.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.25).cgColor
        recenterButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        recenterButton.layer.shadowOpacity = 1.0
        recenterButton.layer.shadowRadius = 4
        recenterButton.layer.masksToBounds = false
        
        closestBusStopView.layer.cornerRadius = 4
        closestBusStopView.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.25).cgColor
        closestBusStopView.layer.shadowOffset = CGSize(width: 0, height: 3)
        closestBusStopView.layer.shadowOpacity = 1.0
        closestBusStopView.layer.shadowRadius = 4
        closestBusStopView.layer.masksToBounds = false
    }
    
    /*
     * Called whenever the user's location is updated.
     */
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Might want to update the user's closest bus stop here.
    }
    
    /*
     * Called whenever location permissions change.
     */
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .denied:
            print("Denied")
            // Todo: Ask user to select a bus stop.
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
    
    /*
     * Displays or removes bus stops depending on current state.
     */
    @IBAction func showHideBusStops() {
        if areBusStopsShowing {
            hideBusStops()
            toggleBusStopsButton.setTitle("Show", for: .normal)
        } else {
            displayBusStops()
            toggleBusStopsButton.setTitle("Hide", for: .normal)
        }
        areBusStopsShowing = !areBusStopsShowing
    }
    
    /*
     * Recenters the MapView on UCSC campus.
     */
    @IBAction func recenterMapView() {
        mapView.setRegion(MKCoordinateRegionMake(UCSC_CAMPUS_LOCATION, DISTANCE_SPAN), animated: true)
    }
    
    /*
     * Builds a BusStop List data structure of all the bus stops.
     */
    func buildBusStopLists() {
        
        // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        // OUTER BUS STOPS
        // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        
        // Outer bus stop coordinates.
        let ccwLocation0 = CLLocationCoordinate2D(latitude: 36.977654, longitude: -122.053599)
        let ccwLocation1 = CLLocationCoordinate2D(latitude: 36.981430, longitude: -122.051962)
        let ccwLocation2 = CLLocationCoordinate2D(latitude: 36.985851, longitude: -122.053511)
        let ccwLocation3 = CLLocationCoordinate2D(latitude: 36.991276, longitude: -122.054696)
        let ccwLocation4 = CLLocationCoordinate2D(latitude: 36.994220, longitude: -122.055522)
        let ccwLocation5 = CLLocationCoordinate2D(latitude: 36.997455, longitude: -122.055066)
        let ccwLocation6 = CLLocationCoordinate2D(latitude: 36.999009, longitude: -122.055230)
        let ccwLocation7 = CLLocationCoordinate2D(latitude: 36.999901, longitude: -122.058372)
        let ccwLocation8 = CLLocationCoordinate2D(latitude: 36.999913, longitude: -122.062371)
        let ccwLocation9 = CLLocationCoordinate2D(latitude: 36.999225, longitude:  -122.064522)
        let ccwLocation10 = CLLocationCoordinate2D(latitude: 36.993011, longitude: -122.065332)
        let ccwLocation11 = CLLocationCoordinate2D(latitude: 36.991710, longitude: -122.066808)
        let ccwLocation12 = CLLocationCoordinate2D(latitude: 36.989923, longitude: -122.067298)
        let ccwLocation13 = CLLocationCoordinate2D(latitude: 36.983681, longitude: -122.065073)
        let ccwLocation14 = CLLocationCoordinate2D(latitude: 36.979882, longitude: -122.059269)
        let ccwLocation15 = CLLocationCoordinate2D(latitude: 36.978658, longitude: -122.057826)
        
        // Zones between bus stops that indicate whether a bus is before or after a bus stop.
        let betweenCCW15n0 = CLCircularRegion(center: findMidpoint(point1: ccwLocation15, point2: ccwLocation0), radius: radiusOfMidpoint(point1: ccwLocation15, point2: ccwLocation0), identifier: "15 <-> 0")
        let betweenCCW0n1 = CLCircularRegion(center: findMidpoint(point1: ccwLocation0, point2: ccwLocation1), radius: radiusOfMidpoint(point1: ccwLocation0, point2: ccwLocation1), identifier: "0 <-> 1")
        let betweenCCW1n2 = CLCircularRegion(center: findMidpoint(point1: ccwLocation1, point2: ccwLocation2), radius: radiusOfMidpoint(point1: ccwLocation1, point2: ccwLocation2), identifier: "1 <-> 2")
        let betweenCCW2n3 = CLCircularRegion(center: findMidpoint(point1: ccwLocation2, point2: ccwLocation3), radius: radiusOfMidpoint(point1: ccwLocation2, point2: ccwLocation3), identifier: "2 <-> 3")
        let betweenCCW3n4 = CLCircularRegion(center: findMidpoint(point1: ccwLocation3, point2: ccwLocation4), radius: radiusOfMidpoint(point1: ccwLocation3, point2: ccwLocation4), identifier: "3 <-> 4")
        let betweenCCW4n5 = CLCircularRegion(center: findMidpoint(point1: ccwLocation4, point2: ccwLocation5), radius: radiusOfMidpoint(point1: ccwLocation4, point2: ccwLocation5), identifier: "4 <-> 5")
        let betweenCCW5n6 = CLCircularRegion(center: findMidpoint(point1: ccwLocation5, point2: ccwLocation6), radius: radiusOfMidpoint(point1: ccwLocation5, point2: ccwLocation6), identifier: "5 <-> 6")
        let betweenCCW6n7 = CLCircularRegion(center: findMidpoint(point1: ccwLocation6, point2: ccwLocation7), radius: radiusOfMidpoint(point1: ccwLocation6, point2: ccwLocation7), identifier: "6 <-> 7")
        let betweenCCW7n8 = CLCircularRegion(center: findMidpoint(point1: ccwLocation7, point2: ccwLocation8), radius: radiusOfMidpoint(point1: ccwLocation7, point2: ccwLocation8), identifier: "7 <-> 8")
        let betweenCCW8n9 = CLCircularRegion(center: findMidpoint(point1: ccwLocation8, point2: ccwLocation9), radius: radiusOfMidpoint(point1: ccwLocation8, point2: ccwLocation9), identifier: "8 <-> 9")
        let betweenCCW9n10 = CLCircularRegion(center: findMidpoint(point1: ccwLocation9, point2: ccwLocation10), radius: radiusOfMidpoint(point1: ccwLocation9, point2: ccwLocation10), identifier: "9 <-> 10")
        let betweenCCW10n11 = CLCircularRegion(center: findMidpoint(point1: ccwLocation10, point2: ccwLocation11), radius: radiusOfMidpoint(point1: ccwLocation10, point2: ccwLocation11), identifier: "10 <-> 11")
        let betweenCCW11n12 = CLCircularRegion(center: findMidpoint(point1: ccwLocation11, point2: ccwLocation12), radius: radiusOfMidpoint(point1: ccwLocation11, point2: ccwLocation12), identifier: "11 <-> 12")
        let betweenCCW12n13 = CLCircularRegion(center: findMidpoint(point1: ccwLocation12, point2: ccwLocation13), radius: radiusOfMidpoint(point1: ccwLocation12, point2: ccwLocation13), identifier: "12 <-> 13")
        let betweenCCW13n14 = CLCircularRegion(center: findMidpoint(point1: ccwLocation13, point2: ccwLocation14), radius: radiusOfMidpoint(point1: ccwLocation13, point2: ccwLocation14), identifier: "13 <-> 14")
        let betweenCCW14n15 = CLCircularRegion(center: findMidpoint(point1: ccwLocation14, point2: ccwLocation15), radius: radiusOfMidpoint(point1: ccwLocation14, point2: ccwLocation15), identifier: "14 <-> 15")
        
        // Build BusStop objects.
        ccwBusStop0 = BusStop(title: "Main Entrance (Outer)", subtitle: "0", coordinate: ccwLocation0, info: "CounterClockwise", listIndex: 0, imageName: "bustopouter.png", beforeStop: betweenCCW15n0, afterStop: betweenCCW0n1, etaToNextStop: 74)
        ccwBusStop1 = BusStop(title: "Lower Campus (Outer)", subtitle: "1", coordinate: ccwLocation1, info: "CounterClockwise", listIndex: 1, imageName: "bustopouter.png", beforeStop: betweenCCW0n1, afterStop: betweenCCW1n2, etaToNextStop: 78)
        ccwBusStop2 = BusStop(title: "Lower Quarry Rd. (Outer)", subtitle: "2", coordinate: ccwLocation2, info: "CounterClockwise", listIndex: 2, imageName: "bustopouter.png", beforeStop: betweenCCW1n2, afterStop: betweenCCW2n3, etaToNextStop: 67)
        ccwBusStop3 = BusStop(title: "East Remote Parking Lot (Outer)", subtitle: "3", coordinate: ccwLocation3, info: "CounterClockwise", listIndex: 3, imageName: "bustopouter.png", beforeStop: betweenCCW2n3, afterStop: betweenCCW3n4, etaToNextStop: 40)
        ccwBusStop4 = BusStop(title: "East Field House (Outer)", subtitle: "4", coordinate: ccwLocation4, info: "CounterClockwise", listIndex: 4, imageName: "bustopouter.png", beforeStop: betweenCCW3n4, afterStop: betweenCCW4n5, etaToNextStop: 87)
        ccwBusStop5 = BusStop(title: "Bookstore (Outer)", subtitle: "5", coordinate: ccwLocation5, info: "CounterClockwise", listIndex: 5, imageName: "bustopouter.png", beforeStop: betweenCCW4n5, afterStop: betweenCCW5n6, etaToNextStop: 97)
        ccwBusStop6 = BusStop(title: "Crown College (Outer)", subtitle: "6", coordinate: ccwLocation6, info: "CounterClockwise", listIndex: 6, imageName: "bustopouter.png", beforeStop: betweenCCW5n6, afterStop: betweenCCW6n7, etaToNextStop: 84)
        ccwBusStop7 = BusStop(title: "College 9/10 (Outer)", subtitle: "7", coordinate: ccwLocation7, info: "CounterClockwise", listIndex: 7, imageName: "bustopouter.png", beforeStop: betweenCCW6n7, afterStop: betweenCCW7n8, etaToNextStop: 92)
        ccwBusStop8 = BusStop(title: "Science Hill (Outer)", subtitle: "8", coordinate: ccwLocation8, info: "CounterClockwise", listIndex: 8, imageName: "bustopouter.png", beforeStop: betweenCCW7n8, afterStop: betweenCCW8n9, etaToNextStop: 57)
        ccwBusStop9 = BusStop(title: "Kresge College (Outer)", subtitle: "9", coordinate: ccwLocation9, info: "CounterClockwise", listIndex: 9, imageName: "bustopouter.png", beforeStop: betweenCCW8n9, afterStop: betweenCCW9n10, etaToNextStop: 161)
        ccwBusStop10 = BusStop(title: "College 8/Porter (Outer)", subtitle: "10", coordinate: ccwLocation10, info: "CounterClockwise", listIndex: 10, imageName: "bustopouter.png", beforeStop: betweenCCW9n10, afterStop: betweenCCW10n11, etaToNextStop: 34)
        ccwBusStop11 = BusStop(title: "Family Student Housing (Outer)", subtitle: "11", coordinate: ccwLocation11, info: "CounterClockwise", listIndex: 11, imageName: "bustopouter.png", beforeStop: betweenCCW10n11, afterStop: betweenCCW11n12, etaToNextStop: 48)
        ccwBusStop12 = BusStop(title: "Oakes College (Outer)", subtitle: "12", coordinate: ccwLocation12, info: "CounterClockwise", listIndex: 12, imageName: "bustopouter.png", beforeStop: betweenCCW11n12, afterStop: betweenCCW12n13, etaToNextStop: 86)
        ccwBusStop13 = BusStop(title: "Arboretum (Outer)", subtitle: "13", coordinate: ccwLocation13, info: "CounterClockwise", listIndex: 13, imageName: "bustopouter.png", beforeStop: betweenCCW12n13, afterStop: betweenCCW13n14, etaToNextStop: 41)
        ccwBusStop14 = BusStop(title: "Tosca Terrace (Outer)", subtitle: "14", coordinate: ccwLocation14, info: "CounterClockwise", listIndex: 14, imageName: "bustopouter.png", beforeStop: betweenCCW13n14, afterStop: betweenCCW14n15, etaToNextStop: 14)
        ccwBusStop15 = BusStop(title: "Western Dr. (Outer)", subtitle: "15", coordinate: ccwLocation15, info: "CounterClockwise", listIndex: 15, imageName: "bustopouter.png", beforeStop: betweenCCW14n15, afterStop: betweenCCW15n0, etaToNextStop: 75)
        
        ccwBusStopList.append(ccwBusStop0)
        ccwBusStopList.append(ccwBusStop1)
        ccwBusStopList.append(ccwBusStop2)
        ccwBusStopList.append(ccwBusStop3)
        ccwBusStopList.append(ccwBusStop4)
        ccwBusStopList.append(ccwBusStop5)
        ccwBusStopList.append(ccwBusStop6)
        ccwBusStopList.append(ccwBusStop7)
        ccwBusStopList.append(ccwBusStop8)
        ccwBusStopList.append(ccwBusStop9)
        ccwBusStopList.append(ccwBusStop10)
        ccwBusStopList.append(ccwBusStop11)
        ccwBusStopList.append(ccwBusStop12)
        ccwBusStopList.append(ccwBusStop13)
        ccwBusStopList.append(ccwBusStop14)
        ccwBusStopList.append(ccwBusStop15)
        
        // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        // INNER BUS STOPS
        // =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
        
        // Inner bus stop coordinates.
        let cwLocation0 = CLLocationCoordinate2D(latitude: 36.977317, longitude: -122.054255)
        let cwLocation1 = CLLocationCoordinate2D(latitude: 36.978753, longitude: -122.057694)
        let cwLocation2 = CLLocationCoordinate2D(latitude: 36.982729, longitude: -122.062573)
        let cwLocation3 = CLLocationCoordinate2D(latitude: 36.990675, longitude: -122.066070)
        let cwLocation4 = CLLocationCoordinate2D(latitude: 36.992781, longitude: -122.064729)
        let cwLocation5 = CLLocationCoordinate2D(latitude: 36.996736, longitude: -122.063586)
        let cwLocation6 = CLLocationCoordinate2D(latitude: 36.999198,longitude: -122.064371)
        let cwLocation7 = CLLocationCoordinate2D(latitude: 36.999809, longitude: -122.062068)
        let cwLocation8 = CLLocationCoordinate2D(latitude: 36.999719, longitude: -122.058393)
        let cwLocation9 = CLLocationCoordinate2D(latitude: 36.996636, longitude: -122.055431)
        let cwLocation10 = CLLocationCoordinate2D(latitude: 36.991263, longitude: -122.054873)
        let cwLocation11 = CLLocationCoordinate2D(latitude: 36.985438, longitude: -122.053505)
        let cwLocation12 = CLLocationCoordinate2D(latitude: 36.981535, longitude: -122.052068)
        
        // Zones between bus stops that indicate whether a bus is before or after a bus stop.
        let betweenCW12n0 = CLCircularRegion(center: findMidpoint(point1: cwLocation12, point2: cwLocation0), radius: radiusOfMidpoint(point1: cwLocation12, point2: cwLocation0), identifier: "12 <-> 0")
        let betweenCW0n1 = CLCircularRegion(center: findMidpoint(point1: cwLocation0, point2: cwLocation1), radius: radiusOfMidpoint(point1: cwLocation0, point2: cwLocation1), identifier: "0 <-> 1")
        let betweenCW1n2 = CLCircularRegion(center: findMidpoint(point1: cwLocation1, point2: cwLocation2), radius: radiusOfMidpoint(point1: cwLocation1, point2: cwLocation2), identifier: "1 <-> 2")
        let betweenCW2n3 = CLCircularRegion(center: findMidpoint(point1: cwLocation2, point2: cwLocation3), radius: radiusOfMidpoint(point1: cwLocation2, point2: cwLocation3), identifier: "2 <-> 3")
        let betweenCW3n4 = CLCircularRegion(center: findMidpoint(point1: ccwLocation3, point2: ccwLocation4), radius: radiusOfMidpoint(point1: cwLocation3, point2: cwLocation4), identifier: "3 <-> 4")
        let betweenCW4n5 = CLCircularRegion(center: findMidpoint(point1: cwLocation4, point2: cwLocation5), radius: radiusOfMidpoint(point1: cwLocation4, point2: cwLocation5), identifier: "4 <-> 5")
        let betweenCW5n6 = CLCircularRegion(center: findMidpoint(point1: cwLocation5, point2: cwLocation6), radius: radiusOfMidpoint(point1: cwLocation5, point2: cwLocation6), identifier: "5 <-> 6")
        let betweenCW6n7 = CLCircularRegion(center: findMidpoint(point1: cwLocation6, point2: cwLocation7), radius: radiusOfMidpoint(point1: cwLocation6, point2: cwLocation7), identifier: "6 <-> 7")
        let betweenCW7n8 = CLCircularRegion(center: findMidpoint(point1: cwLocation7, point2: cwLocation8), radius: radiusOfMidpoint(point1: cwLocation7, point2: cwLocation8), identifier: "7 <-> 8")
        let betweenCW8n9 = CLCircularRegion(center: findMidpoint(point1: cwLocation8, point2: cwLocation9), radius: radiusOfMidpoint(point1: cwLocation8, point2: cwLocation9), identifier: "8 <-> 9")
        let betweenCW9n10 = CLCircularRegion(center: findMidpoint(point1: cwLocation9, point2: cwLocation10), radius: radiusOfMidpoint(point1: cwLocation9, point2: cwLocation10), identifier: "9 <-> 10")
        let betweenCW10n11 = CLCircularRegion(center: findMidpoint(point1: cwLocation10, point2: cwLocation11), radius: radiusOfMidpoint(point1: cwLocation10, point2: cwLocation11), identifier: "10 <-> 11")
        let betweenCW11n12 = CLCircularRegion(center: findMidpoint(point1: cwLocation11, point2: cwLocation12), radius: radiusOfMidpoint(point1: cwLocation11, point2: cwLocation12), identifier: "11 <-> 12")
        
        // Build inner BusStop objects.
        cwBusStop0 = BusStop(title: "Barn Theater (Inner)", subtitle: "0", coordinate: cwLocation0, info: "Clockwise", listIndex: 0, imageName: "bustopinner.png", beforeStop: betweenCW12n0, afterStop: betweenCW0n1, etaToNextStop: 42)
        cwBusStop1 = BusStop(title: "Western Dr. (Inner)", subtitle: "1", coordinate: cwLocation1, info: "Clockwise", listIndex: 1, imageName: "bustopinner.png", beforeStop: betweenCW0n1, afterStop: betweenCW1n2, etaToNextStop: 53)
        cwBusStop2 = BusStop(title: "Arboretum (Inner)", subtitle: "2", coordinate: cwLocation2, info: "Clockwise", listIndex: 2, imageName: "bustopinner.png", beforeStop: betweenCW1n2, afterStop: betweenCW2n3, etaToNextStop: 150)
        cwBusStop3 = BusStop(title: "Oakes College (Inner)", subtitle: "3", coordinate: cwLocation3, info: "Clockwise", listIndex: 3, imageName: "bustopinner.png", beforeStop: betweenCW2n3, afterStop: betweenCW3n4, etaToNextStop: 74)
        cwBusStop4 = BusStop(title: "College 8/Porter (Inner)", subtitle: "4", coordinate: cwLocation4, info: "Clockwise", listIndex: 4, imageName: "bustopinner.png", beforeStop: betweenCW3n4, afterStop: betweenCW4n5, etaToNextStop: 98)
        cwBusStop5 = BusStop(title: "Kerr Hall (Inner)", subtitle: "5", coordinate: cwLocation5, info: "Clockwise", listIndex: 5, imageName: "bustopinner.png", beforeStop: betweenCW4n5, afterStop: betweenCW5n6, etaToNextStop: 52)
        cwBusStop6 = BusStop(title: "Kresge College (Inner)", subtitle: "6", coordinate: cwLocation6, info: "Clockwise", listIndex: 6, imageName: "bustopinner.png", beforeStop: betweenCW5n6, afterStop: betweenCW6n7, etaToNextStop: 63)
        cwBusStop7 = BusStop(title: "Science Hill (Inner)", subtitle: "7", coordinate: cwLocation7, info: "Clockwise", listIndex: 7, imageName: "bustopinner.png", beforeStop: betweenCW6n7, afterStop: betweenCW7n8, etaToNextStop: 83)
        cwBusStop8 = BusStop(title: "College 9/10 (Inner)", subtitle: "8", coordinate: cwLocation8, info: "Clockwise", listIndex: 8, imageName: "bustopinner.png", beforeStop: betweenCW7n8, afterStop: betweenCW8n9, etaToNextStop: 155)
        cwBusStop9 = BusStop(title: "Bookstore (Inner)", subtitle: "9", coordinate: cwLocation9, info: "Clockwise", listIndex: 9, imageName: "bustopinner.png", beforeStop: betweenCW8n9, afterStop: betweenCW9n10, etaToNextStop: 81)
        cwBusStop10 = BusStop(title: "East Remote Parking Lot (Inner)", subtitle: "10", coordinate: cwLocation10, info: "Clockwise", listIndex: 10, imageName: "bustopinner.png", beforeStop: betweenCW9n10, afterStop: betweenCW10n11, etaToNextStop: 69)
        cwBusStop11 = BusStop(title: "Lower Quarry Rd. (Inner)", subtitle: "11", coordinate: cwLocation11, info: "Clockwise", listIndex: 11, imageName: "bustopinner.png", beforeStop: betweenCW10n11, afterStop: betweenCW11n12, etaToNextStop: 81)
        cwBusStop12 = BusStop(title: "Lower Campus (Inner)", subtitle: "12", coordinate: cwLocation12, info: "Clockwise", listIndex: 12, imageName: "bustopinner.png", beforeStop: betweenCW11n12, afterStop: betweenCW12n0, etaToNextStop: 103)
        
        cwBusStopList.append(cwBusStop0)
        cwBusStopList.append(cwBusStop1)
        cwBusStopList.append(cwBusStop2)
        cwBusStopList.append(cwBusStop3)
        cwBusStopList.append(cwBusStop4)
        cwBusStopList.append(cwBusStop5)
        cwBusStopList.append(cwBusStop6)
        cwBusStopList.append(cwBusStop7)
        cwBusStopList.append(cwBusStop8)
        cwBusStopList.append(cwBusStop9)
        cwBusStopList.append(cwBusStop10)
        cwBusStopList.append(cwBusStop11)
        cwBusStopList.append(cwBusStop12)
    }
    
    /*
     * Adds an annotation on the MapView of every bus stop on the UCSC campus.
     */
    func displayBusStops() {
        mapView.addAnnotation(ccwBusStop0)
        mapView.addAnnotation(ccwBusStop1)
        mapView.addAnnotation(ccwBusStop2)
        mapView.addAnnotation(ccwBusStop3)
        mapView.addAnnotation(ccwBusStop4)
        mapView.addAnnotation(ccwBusStop5)
        mapView.addAnnotation(ccwBusStop6)
        mapView.addAnnotation(ccwBusStop7)
        mapView.addAnnotation(ccwBusStop8)
        mapView.addAnnotation(ccwBusStop9)
        mapView.addAnnotation(ccwBusStop10)
        mapView.addAnnotation(ccwBusStop11)
        mapView.addAnnotation(ccwBusStop12)
        mapView.addAnnotation(ccwBusStop13)
        mapView.addAnnotation(ccwBusStop14)
        mapView.addAnnotation(ccwBusStop15)
        mapView.addAnnotation(cwBusStop0)
        mapView.addAnnotation(cwBusStop1)
        mapView.addAnnotation(cwBusStop2)
        mapView.addAnnotation(cwBusStop3)
        mapView.addAnnotation(cwBusStop4)
        mapView.addAnnotation(cwBusStop5)
        mapView.addAnnotation(cwBusStop6)
        mapView.addAnnotation(cwBusStop7)
        mapView.addAnnotation(cwBusStop8)
        mapView.addAnnotation(cwBusStop9)
        mapView.addAnnotation(cwBusStop10)
        mapView.addAnnotation(cwBusStop11)
        mapView.addAnnotation(cwBusStop12)
    }
    
    /*
     * Removes each bus stop annotation on the MapView.
     */
    func hideBusStops() {
        mapView.removeAnnotation(ccwBusStop0)
        mapView.removeAnnotation(ccwBusStop1)
        mapView.removeAnnotation(ccwBusStop2)
        mapView.removeAnnotation(ccwBusStop3)
        mapView.removeAnnotation(ccwBusStop4)
        mapView.removeAnnotation(ccwBusStop5)
        mapView.removeAnnotation(ccwBusStop6)
        mapView.removeAnnotation(ccwBusStop7)
        mapView.removeAnnotation(ccwBusStop8)
        mapView.removeAnnotation(ccwBusStop9)
        mapView.removeAnnotation(ccwBusStop10)
        mapView.removeAnnotation(ccwBusStop11)
        mapView.removeAnnotation(ccwBusStop12)
        mapView.removeAnnotation(ccwBusStop13)
        mapView.removeAnnotation(ccwBusStop14)
        mapView.removeAnnotation(ccwBusStop15)
        mapView.removeAnnotation(cwBusStop0)
        mapView.removeAnnotation(cwBusStop1)
        mapView.removeAnnotation(cwBusStop2)
        mapView.removeAnnotation(cwBusStop3)
        mapView.removeAnnotation(cwBusStop4)
        mapView.removeAnnotation(cwBusStop5)
        mapView.removeAnnotation(cwBusStop6)
        mapView.removeAnnotation(cwBusStop7)
        mapView.removeAnnotation(cwBusStop8)
        mapView.removeAnnotation(cwBusStop9)
        mapView.removeAnnotation(cwBusStop10)
        mapView.removeAnnotation(cwBusStop11)
        mapView.removeAnnotation(cwBusStop12)
    }
    
    /*
     * Calculate the midpoint between point1 and point2.
     */
    func findMidpoint(point1: CLLocationCoordinate2D, point2: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        
        let lat1: Double = (point1.latitude * M_2_PI) / 180.0
        let lat2: Double = (point2.latitude * M_2_PI) / 180.0
        let lng1: Double = (point1.longitude * M_2_PI) / 180.0
        let lng2: Double = (point2.longitude * M_2_PI) / 180.0
        
        let dLng: Double = lng2 - lng1
        
        let x: Double = cos(lat2) * cos(dLng)
        let y: Double = cos(lat2) * sin(dLng)
        
        let lat3: Double = atan2( sin(lat1) + sin(lat2), sqrt((cos(lat1) + x) * (cos(lat1) + x) + y*y))
        let lng3: Double = lng1 + atan2(y, cos(lat1) + x)
        
        let midpoint = CLLocationCoordinate2D(latitude: ((lat3 * 180.0) / M_2_PI), longitude: ((lng3 * 180.0) / M_2_PI))
        
        return midpoint
    }
    
    /*
     * Calculate the radius.
     */
    func radiusOfMidpoint(point1: CLLocationCoordinate2D, point2: CLLocationCoordinate2D) -> Double {
        let marker1 = CLLocation(latitude: point1.latitude, longitude: point1.longitude)
        let marker2 = CLLocation(latitude: point2.latitude, longitude: point2.longitude)
        
        let radius: Double = (marker1.distance(from: marker2)) / 2.0
        return radius
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

