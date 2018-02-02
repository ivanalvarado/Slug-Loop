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

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    let UCSC_CAMPUS_LOCATION: CLLocationCoordinate2D = CLLocationCoordinate2DMake(36.9900, -122.0605)
    let DISTANCE_SPAN: MKCoordinateSpan = MKCoordinateSpanMake(0.03, 0.03)
    let MAIN_ENTRANCE_OUTER = 0; let BARN_THEATER_INNER = 0
    let LOWER_CAMPUS_OUTER = 1; let WESTERN_DR_INNER = 1
    let LOWER_QUARRY_RD_OUTER = 2; let ARBORETUM_INNER = 2
    let EAST_REMOTE_OUTER = 3; let OAKES_COLLEGE_INNER = 3
    let EAST_FIELD_OUTER = 4; let COLLEGE_8_PORTER_INNER = 4
    let BOOKSTORE_OUTER = 5; let KERR_HALL_INNER = 5
    let CROWN_COLLEGE_OUTER = 6; let KRESGE_COLLEGE_INNER = 6
    let COLLEGE_9_10_OUTER = 7; let SCIENCE_HILL_INNER = 7
    let SCIENCE_HILL_OUTER = 8; let COLLEGE_9_10_INNER = 8
    let KRESGE_COLLEGE_OUTER = 9; let BOOKSTORE_INNER = 9
    let COLLEGE_8_PORTER_OUTER = 10; let EAST_REMOTE_INNER = 10
    let FAMILY_STUDENT_HOUSING_OUTER = 11; let LOWER_QUARRY_RD_INNER = 11
    let OAKES_COLLEGE_OUTER = 12; let LOWER_CAMPUS_INNER = 12
    let ARBORETUM_OUTER = 13
    let TOSCA_TERRACE_OUTER = 14
    let WESTERN_DR_OUTER = 15
    
    let url = NSURL(string: "http://bts.ucsc.edu:8081/location/get")

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var toggleBusStopsButton: UIButton!
    @IBOutlet weak var recenterButton: UIButton!
    @IBOutlet weak var closestBusStopView: UIView!
    @IBOutlet weak var closestBusStopLabel: UILabel!
    @IBOutlet weak var mapInfoButton: UIButton!
    
    var locationManager: CLLocationManager!
    var userLocation: CLLocation!
    var cwBusStopList  = [BusStop]()  // Clockwise Bus Stops
    var ccwBusStopList = [BusStop]()  // Counter Clockwise Bus Stops
    var oldMainBusList = [String: Bus]()
    var newMainBusList = [String: Bus]()
    var closestInnerBusStopToUser, closestOuterBusStopToUser, closestBusStopToUser: BusStop!
    var areBusStopsShowing = true
    var busStopAlert: UIAlertController!
    
    var timer: Timer?
    
    // Bus Stops
    var ccwBusStop0, ccwBusStop1, ccwBusStop2, ccwBusStop3, ccwBusStop4, ccwBusStop5, ccwBusStop6, ccwBusStop7, ccwBusStop8, ccwBusStop9, ccwBusStop10, ccwBusStop11, ccwBusStop12, ccwBusStop13, ccwBusStop14, ccwBusStop15, cwBusStop0, cwBusStop1, cwBusStop2, cwBusStop3, cwBusStop4, cwBusStop5, cwBusStop6, cwBusStop7, cwBusStop8, cwBusStop9, cwBusStop10, cwBusStop11, cwBusStop12: BusStop!
    
    /*
     * Fires at the start of the app.
     */
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        mapView.delegate = self
        
        updateButtonUi()
        
        // Add a gesture recognizer to the Bus Stop UIView in case user wants to change closest bus stop.
        let closestBusStopTap = UITapGestureRecognizer(target: self, action: #selector(ViewController.displayBusStopList))
        closestBusStopView.isUserInteractionEnabled = true
        closestBusStopView.addGestureRecognizer(closestBusStopTap)
        
        // Center map on UCSC campus
        mapView.setRegion(MKCoordinateRegionMake(UCSC_CAMPUS_LOCATION, DISTANCE_SPAN), animated: true)
        
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        buildBusStopLists()
        displayBusStops()
    }
    
    /*
     * Start executing bus code here because the view has now loaded.
     */
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        buildBusStopAlert()

        // If we don't have access to the user's current location, request it
        if (CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse) {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    /*
     * Kicks off timer that executes fetchBusData() every three seconds.
     */
    func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 3.0, target: self, selector: #selector(fetchBusData), userInfo: nil, repeats: true)
    }
    
    /*
     * Called whenever location permissions change.
     */
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .denied:
            print("Denied")
            // Ask user to select a bus stop.
            self.present(busStopAlert, animated: true, completion: nil)
            break
        case .notDetermined:
            print("Not Determined")
            locationManager.requestWhenInUseAuthorization()
            break
        case .authorizedWhenInUse:
            print("Authorized When In Use")
            mapView.showsUserLocation = true
            locationManager.startUpdatingLocation()
            userLocation = CLLocation(latitude: (locationManager.location?.coordinate.latitude)!, longitude: (locationManager.location?.coordinate.longitude)!)
            getClosestBusStopsToUser()
            startTimer()
            print("Closest Bus Stop: \(String(describing: closestBusStopToUser.title))")
            break
        default:
            break
        }
    }
    
    /*
     * Displays Bus Stop Alert list.
     */
    @objc func displayBusStopList() {
        self.present(busStopAlert, animated: true, completion: nil)
    }
    
    /*
     * Makes a URL request in order to retrieve JSON bus data.
     */
    @objc func fetchBusData() {
        if let usableUrl = url {
            let request = URLRequest(url: usableUrl as URL)
            let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                if let data = data {
                    if let stringData = String(data: data, encoding: String.Encoding.utf8) {
                        print(stringData)
                        do {
                            let jsonData = try JSON(data: data)
                            print(jsonData.count)
                            
                            if jsonData.count == 0 {
                                // Todo: Alert the user no buses are active.
                                return
                            }
                            
                            if self.oldMainBusList.isEmpty {
                                // We're fetching bus data for the first time, thus we don't know bus directions.
                                // Todo: Display progress dialog while we determine bus directions.
                                
                                self.buildGlobalBusList(readableJson: jsonData, isOld: true)
                            } else {
                                
                                if self.newMainBusList.isEmpty {
                                    self.buildGlobalBusList(readableJson: jsonData, isOld: false)
                                    self.addBusesToMapView()
                                } else {
                                    self.copyNewToOldMainBusList()
                                    self.updateNewMainBusList(readableJson: jsonData)
                                }
                                
                                self.determineBusDirections()
                                self.getClosestBusStopToBuses()
                                self.calculateEtaOfBuses()
                                self.convertEtaToMinutes()
                                self.printBusInfo()
                                self.updateAnnotationViews()
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
    
    /*
     * Debug.
     */
    func printBusInfo() {
        for bus in newMainBusList.keys {
            print("ID: \(String(describing: newMainBusList[bus]?.id))")
            print("DIREC: \(String(describing: newMainBusList[bus]?.direc))")
            if newMainBusList[bus]?.direc == "Inner" {
                print("CLOSEST STOP: \(String(describing: cwBusStopList[(newMainBusList[bus]?.closestInnerStop)!].title))")
                print("ETA: \(String(describing: newMainBusList[bus]?.innerETA))")
            } else if newMainBusList[bus]?.direc == "Outer" {
                print("CLOSEST STOP: \(String(describing: ccwBusStopList[(newMainBusList[bus]?.closestOuterStop)!].title))")
                print("ETA: \(String(describing: newMainBusList[bus]?.outerETA))")
            }
            print(" ")
        }
    }
    
    /*
     * Copy over old bus data to Old Main Bus List so that we have a reference to old bus data.
     * Need to copy each Bus object individually because assignment simply copies a reference to the object.
     */
    func copyNewToOldMainBusList() {
        oldMainBusList.removeAll()
        for bus in newMainBusList.keys {
            oldMainBusList[bus] = Bus(title: (newMainBusList[bus]?.title)!, coordinate: (newMainBusList[bus]?.coordinate)!, id: (newMainBusList[bus]?.id)!, quadrant: (newMainBusList[bus]?.quadrant)!, angle: (newMainBusList[bus]?.angle)!, exists: (newMainBusList[bus]?.exists)!)
        }
    }
    
    /*
     * Updates the New Main Bus List with newly received bus data.
     */
    func updateNewMainBusList(readableJson: JSON) {
        
        DispatchQueue.main.async {
            for bus in readableJson {
                let busId = bus.1["id"].string!
                
                if self.newMainBusList[busId] != nil {
                    let newLat = Double(bus.1["lat"].double!)
                    let newLon = Double(bus.1["lon"].double!)
                    let newCoord = CLLocationCoordinate2D(latitude: newLat, longitude: newLon)
                    let quadrant = self.determineMapQuadrant(lat: newLat, lon: newLon)
                    let busAngle = self.determineBusAngle(lat: newLat, lon: newLon, quadrant: quadrant)
                    
                    self.newMainBusList[busId]?.quadrant = quadrant
                    self.newMainBusList[busId]?.angle = busAngle
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
     * Updates the Bus annotation views' info: Direction, Next Stop, ETA.
     */
    func updateAnnotationViews() {
        DispatchQueue.main.async {
            for bus in self.newMainBusList.keys {
                if self.mapView.view(for: self.newMainBusList[bus]!) != nil {
                    let busAnnotationView: BusMKAnnotationView = self.mapView.view(for: self.newMainBusList[bus]!)! as! BusMKAnnotationView
                    busAnnotationView.reloadData()
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
                oldMainBusList[bus.1["id"].string!] = (Bus(title: bus.1["type"].string! + " " + bus.1["id"].string!, coordinate: newMarker.coordinate, id: bus.1["id"].string!, quadrant: quadrant, angle: busAngle, exists: true))
            } else {
                newMainBusList[bus.1["id"].string!] = (Bus(title: bus.1["type"].string! + " " + bus.1["id"].string!, coordinate: newMarker.coordinate, id: bus.1["id"].string!, quadrant: quadrant, angle: busAngle, exists: true))
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
                print("Old Bus Angle \(oldBusData.angle)")
                print("New Bus Angle \(String(describing: newBusData?.angle))")
                if (newBusData?.angle)! > oldBusData.angle {
                    newMainBusList[busId]?.direc = "Outer"
                } else if (newBusData?.angle)! < oldBusData.angle {
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
        toggleBusStopsButton.backgroundColor = UIColor.clear
        toggleBusStopsButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        toggleBusStopsButton.layer.shadowOpacity = 1.0
        toggleBusStopsButton.layer.shadowRadius = 4
        toggleBusStopsButton.layer.masksToBounds = false
        
        recenterButton.layer.cornerRadius = 4
        recenterButton.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.25).cgColor
        recenterButton.backgroundColor = UIColor.clear
        recenterButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        recenterButton.layer.shadowOpacity = 1.0
        recenterButton.layer.shadowRadius = 4
        recenterButton.layer.masksToBounds = false
        
        mapInfoButton.layer.cornerRadius = 4
        mapInfoButton.layer.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.25).cgColor
        mapInfoButton.backgroundColor = UIColor.clear
        mapInfoButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        mapInfoButton.layer.shadowOpacity = 1.0
        mapInfoButton.layer.shadowRadius = 4
        mapInfoButton.layer.masksToBounds = false
        
        closestBusStopView.layer.cornerRadius = 10
        closestBusStopView.layer.borderWidth = 3.0
        closestBusStopView.layer.borderColor = UIColor.white.cgColor
        closestBusStopView.clipsToBounds = true
        closestBusStopView.layer.masksToBounds = true
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
    
    func aggregateEta() {
        for bus in newMainBusList.keys {
            
            newMainBusList[bus]?.innerETA = 0
            if newMainBusList[bus]?.direc == "Inner" {
                if newMainBusList[bus]?.closestInnerStop != closestInnerBusStopToUser.listIndex {
                    var index = newMainBusList[bus]?.closestInnerStop
                    while index != closestInnerBusStopToUser.listIndex {
                        if index! >= cwBusStopList.count {
                            if closestInnerBusStopToUser.listIndex == 0 {
                                break
                            }
                            index = 0
                        }
                        newMainBusList[bus]?.innerETA += cwBusStopList[index!].etaToNextStop
                        index = index! + 1
                    }
                }
            }
            
            newMainBusList[bus]?.outerETA = 0
            if newMainBusList[bus]?.direc == "Outer" {
                if newMainBusList[bus]?.closestOuterStop != closestOuterBusStopToUser.listIndex {
                    var index = newMainBusList[bus]?.closestOuterStop
                    while index != closestOuterBusStopToUser.listIndex {
                        if index! >= ccwBusStopList.count {
                            if closestOuterBusStopToUser.listIndex == 0 {
                                break
                            }
                            index = 0
                        }
                        newMainBusList[bus]?.outerETA += ccwBusStopList[index!].etaToNextStop
                        index = index! + 1
                    }
                }
            }
        }
    }
    
    func calculateEtaOfBusToClosestStop(source: Bus, destination: BusStop, result: @escaping (_ eta: Int) -> Void) {
        var eta = 0
        
        let request = MKDirectionsRequest()
        let sourceItem = MKMapItem(placemark: MKPlacemark(coordinate: source.coordinate, addressDictionary: nil))
        request.source = sourceItem
        request.transportType = .automobile
        let destinationCoordinates = CLLocationCoordinate2D(latitude: destination.coordinate.latitude, longitude: destination.coordinate.longitude)
        let destinationItem = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinates, addressDictionary: nil))
        request.destination = destinationItem
        request.requestsAlternateRoutes = false
        let directions = MKDirections(request: request)
        
        directions.calculateETA { (etaResponse, error) -> Void in
            if let error = error {
                print("Error while requesting ETA : \(error.localizedDescription)")
                result(0)
            } else {
                eta = Int((etaResponse?.expectedTravelTime)!)
                result(eta)
            }
        }
    }
    
    func calculateEtaOfBuses() {
        
        aggregateEta()
        
        for bus in newMainBusList.keys {
            if newMainBusList[bus]?.direc == "Inner" {
                calculateEtaOfBusToClosestStop(source: newMainBusList[bus]!, destination: cwBusStopList[(newMainBusList[bus]?.closestInnerStop)!]) { (eta: Int) -> Void in
                    self.newMainBusList[bus]?.innerETA += eta
                }
            }
            
            if newMainBusList[bus]?.direc == "Outer" {
                calculateEtaOfBusToClosestStop(source: newMainBusList[bus]!, destination: ccwBusStopList[(newMainBusList[bus]?.closestOuterStop)!]) { (eta: Int) -> Void in
                    self.newMainBusList[bus]?.outerETA += eta
                }
            }
        }
    }
    
    func convertEtaToMinutes () {
        for bus in newMainBusList.keys {
            if newMainBusList[bus]?.direc == "Inner" {
                let etaAsWhole = newMainBusList[bus]?.innerETA
                let etaInMinutes = etaAsWhole! / 60
                let etaInSeconds = etaAsWhole! % 60
                
                newMainBusList[bus]?.actualETA = String(etaInMinutes) + " Minutes, " + String(etaInSeconds) + " Seconds"
            }
            
            if newMainBusList[bus]?.direc == "Outer" {
                let etaAsWhole = newMainBusList[bus]?.outerETA
                let etaInMinutes = etaAsWhole! / 60
                let etaInSeconds = etaAsWhole! % 60
                
                newMainBusList[bus]?.actualETA = String(etaInMinutes) + " Minutes, " + String(etaInSeconds) + " Seconds"
            }
        }
    }
    
    /*
     * Displays or removes bus stops depending on current state.
     */
    @IBAction func showHideBusStops() {
        if areBusStopsShowing {
            hideBusStops()
            toggleBusStopsButton.setImage(UIImage(named: "ToggleStopDark-1"), for: .normal)
        } else {
            displayBusStops()
            toggleBusStopsButton.setImage(UIImage(named: "ToggleStopLight-1"), for: .normal)
        }
        areBusStopsShowing = !areBusStopsShowing
    }
    
    /*
     * Recenters the MapView on UCSC campus.
     */
    @IBAction func recenterMapView() {
        mapView.setRegion(MKCoordinateRegionMake(UCSC_CAMPUS_LOCATION, DISTANCE_SPAN), animated: true)
    }
    
    @IBAction func showMapInfo() {
        print("MapInfo!!!")
        let popOverVc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "infoPopUpId") as! InfoPopUpViewController
        self.addChildViewController(popOverVc)
        popOverVc.view.frame = self.view.frame
        self.view.addSubview(popOverVc.view)
        popOverVc.didMove(toParentViewController: self)
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
        ccwBusStop0 = BusStop(title: "Main Entrance (Outer)", subtitle: "Outer", coordinate: ccwLocation0, info: "CounterClockwise", listIndex: 0, imageName: UIImage(named: "MainEntrance.jpg"), beforeStop: betweenCCW15n0, afterStop: betweenCCW0n1, etaToNextStop: 74)
        ccwBusStop1 = BusStop(title: "Lower Campus (Outer)", subtitle: "Outer", coordinate: ccwLocation1, info: "CounterClockwise", listIndex: 1, imageName: UIImage(named: "LowerCampusOuter.jpg"), beforeStop: betweenCCW0n1, afterStop: betweenCCW1n2, etaToNextStop: 78)
        ccwBusStop2 = BusStop(title: "Lower Quarry Rd. (Outer)", subtitle: "Outer", coordinate: ccwLocation2, info: "CounterClockwise", listIndex: 2, imageName: UIImage(named: "LowerQuarryRdOuter.jpg"), beforeStop: betweenCCW1n2, afterStop: betweenCCW2n3, etaToNextStop: 67)
        ccwBusStop3 = BusStop(title: "East Remote Parking Lot (Outer)", subtitle: "Outer", coordinate: ccwLocation3, info: "CounterClockwise", listIndex: 3, imageName: UIImage(named: "EastRemoteOuter.jpg"), beforeStop: betweenCCW2n3, afterStop: betweenCCW3n4, etaToNextStop: 40)
        ccwBusStop4 = BusStop(title: "East Field House (Outer)", subtitle: "Outer", coordinate: ccwLocation4, info: "CounterClockwise", listIndex: 4, imageName: UIImage(named: "EastFieldHouseOuter.jpg"), beforeStop: betweenCCW3n4, afterStop: betweenCCW4n5, etaToNextStop: 87)
        ccwBusStop5 = BusStop(title: "Bookstore (Outer)", subtitle: "Outer", coordinate: ccwLocation5, info: "CounterClockwise", listIndex: 5, imageName: UIImage(named: "BookstoreOuter.jpg"), beforeStop: betweenCCW4n5, afterStop: betweenCCW5n6, etaToNextStop: 97)
        ccwBusStop6 = BusStop(title: "Crown College (Outer)", subtitle: "Outer", coordinate: ccwLocation6, info: "CounterClockwise", listIndex: 6, imageName: UIImage(named: "CrownCollegeOuter.jpg"), beforeStop: betweenCCW5n6, afterStop: betweenCCW6n7, etaToNextStop: 84)
        ccwBusStop7 = BusStop(title: "College 9/10 (Outer)", subtitle: "Outer", coordinate: ccwLocation7, info: "CounterClockwise", listIndex: 7, imageName: UIImage(named: "College9And10Outer.jpg"), beforeStop: betweenCCW6n7, afterStop: betweenCCW7n8, etaToNextStop: 92)
        ccwBusStop8 = BusStop(title: "Science Hill (Outer)", subtitle: "Outer", coordinate: ccwLocation8, info: "CounterClockwise", listIndex: 8, imageName: UIImage(named: "ScienceHillOuter.jpg"), beforeStop: betweenCCW7n8, afterStop: betweenCCW8n9, etaToNextStop: 57)
        ccwBusStop9 = BusStop(title: "Kresge College (Outer)", subtitle: "Outer", coordinate: ccwLocation9, info: "CounterClockwise", listIndex: 9, imageName: UIImage(named: "KresgeCollegeOuter.jpg"), beforeStop: betweenCCW8n9, afterStop: betweenCCW9n10, etaToNextStop: 161)
        ccwBusStop10 = BusStop(title: "College 8/Porter (Outer)", subtitle: "Outer", coordinate: ccwLocation10, info: "CounterClockwise", listIndex: 10, imageName: UIImage(named: "College8PorterOuter.jpg"), beforeStop: betweenCCW9n10, afterStop: betweenCCW10n11, etaToNextStop: 34)
        ccwBusStop11 = BusStop(title: "Family Student Housing (Outer)", subtitle: "Outer", coordinate: ccwLocation11, info: "CounterClockwise", listIndex: 11, imageName: UIImage(named: "FamilyStudentHousingOuter.jpg"), beforeStop: betweenCCW10n11, afterStop: betweenCCW11n12, etaToNextStop: 48)
        ccwBusStop12 = BusStop(title: "Oakes College (Outer)", subtitle: "Outer", coordinate: ccwLocation12, info: "CounterClockwise", listIndex: 12, imageName: UIImage(named: "OakesCollegeOuter.jpg"), beforeStop: betweenCCW11n12, afterStop: betweenCCW12n13, etaToNextStop: 86)
        ccwBusStop13 = BusStop(title: "Arboretum (Outer)", subtitle: "Outer", coordinate: ccwLocation13, info: "CounterClockwise", listIndex: 13, imageName: UIImage(named: "ArboretumOuter.jpg"), beforeStop: betweenCCW12n13, afterStop: betweenCCW13n14, etaToNextStop: 41)
        ccwBusStop14 = BusStop(title: "Tosca Terrace (Outer)", subtitle: "Outer", coordinate: ccwLocation14, info: "CounterClockwise", listIndex: 14, imageName: UIImage(named: "ToscaTerraceOuter.jpg"), beforeStop: betweenCCW13n14, afterStop: betweenCCW14n15, etaToNextStop: 14)
        ccwBusStop15 = BusStop(title: "Western Dr. (Outer)", subtitle: "Outer", coordinate: ccwLocation15, info: "CounterClockwise", listIndex: 15, imageName: UIImage(named: "WesternDrOuter.jpg"), beforeStop: betweenCCW14n15, afterStop: betweenCCW15n0, etaToNextStop: 75)
        
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
        cwBusStop0 = BusStop(title: "Barn Theater (Inner)", subtitle: "Inner", coordinate: cwLocation0, info: "Clockwise", listIndex: 0, imageName: UIImage(named: "BarnTheaterInner.jpg"), beforeStop: betweenCW12n0, afterStop: betweenCW0n1, etaToNextStop: 42)
        cwBusStop1 = BusStop(title: "Western Dr. (Inner)", subtitle: "Inner", coordinate: cwLocation1, info: "Clockwise", listIndex: 1, imageName: UIImage(named: "WesternDrInner.jpg"), beforeStop: betweenCW0n1, afterStop: betweenCW1n2, etaToNextStop: 53)
        cwBusStop2 = BusStop(title: "Arboretum (Inner)", subtitle: "Inner", coordinate: cwLocation2, info: "Clockwise", listIndex: 2, imageName: UIImage(named: "ArboretumInner.jpg"), beforeStop: betweenCW1n2, afterStop: betweenCW2n3, etaToNextStop: 150)
        cwBusStop3 = BusStop(title: "Oakes College (Inner)", subtitle: "Inner", coordinate: cwLocation3, info: "Clockwise", listIndex: 3, imageName: UIImage(named: "OakesCollegeInner.jpg"), beforeStop: betweenCW2n3, afterStop: betweenCW3n4, etaToNextStop: 74)
        cwBusStop4 = BusStop(title: "College 8/Porter (Inner)", subtitle: "Inner", coordinate: cwLocation4, info: "Clockwise", listIndex: 4, imageName: UIImage(named: "College8PorterInner.jpg"), beforeStop: betweenCW3n4, afterStop: betweenCW4n5, etaToNextStop: 98)
        cwBusStop5 = BusStop(title: "Kerr Hall (Inner)", subtitle: "Inner", coordinate: cwLocation5, info: "Clockwise", listIndex: 5, imageName: UIImage(named: "KerrHallInner.jpg"), beforeStop: betweenCW4n5, afterStop: betweenCW5n6, etaToNextStop: 52)
        cwBusStop6 = BusStop(title: "Kresge College (Inner)", subtitle: "Inner", coordinate: cwLocation6, info: "Clockwise", listIndex: 6, imageName: UIImage(named: "KresgeCollegeInner.jpg"), beforeStop: betweenCW5n6, afterStop: betweenCW6n7, etaToNextStop: 63)
        cwBusStop7 = BusStop(title: "Science Hill (Inner)", subtitle: "Inner", coordinate: cwLocation7, info: "Clockwise", listIndex: 7, imageName: UIImage(named: "ScienceHillInner.jpg"), beforeStop: betweenCW6n7, afterStop: betweenCW7n8, etaToNextStop: 83)
        cwBusStop8 = BusStop(title: "College 9/10 (Inner)", subtitle: "Inner", coordinate: cwLocation8, info: "Clockwise", listIndex: 8, imageName: UIImage(named: "College9And10Inner.jpg"), beforeStop: betweenCW7n8, afterStop: betweenCW8n9, etaToNextStop: 155)
        cwBusStop9 = BusStop(title: "Bookstore (Inner)", subtitle: "Inner", coordinate: cwLocation9, info: "Clockwise", listIndex: 9, imageName: UIImage(named: "BookstoreInner.jpg"), beforeStop: betweenCW8n9, afterStop: betweenCW9n10, etaToNextStop: 81)
        cwBusStop10 = BusStop(title: "East Remote Parking Lot (Inner)", subtitle: "Inner", coordinate: cwLocation10, info: "Clockwise", listIndex: 10, imageName: UIImage(named: "EastRemoteInner.jpg"), beforeStop: betweenCW9n10, afterStop: betweenCW10n11, etaToNextStop: 69)
        cwBusStop11 = BusStop(title: "Lower Quarry Rd. (Inner)", subtitle: "Inner", coordinate: cwLocation11, info: "Clockwise", listIndex: 11, imageName: UIImage(named: "LowerQuarryRdInner.jpg"), beforeStop: betweenCW10n11, afterStop: betweenCW11n12, etaToNextStop: 81)
        cwBusStop12 = BusStop(title: "Lower Campus (Inner)", subtitle: "Inner", coordinate: cwLocation12, info: "Clockwise", listIndex: 12, imageName: UIImage(named: "LowerCampusInner.jpg"), beforeStop: betweenCW11n12, afterStop: betweenCW12n0, etaToNextStop: 103)
        
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
     * Builds the Bus Stop UIAlertController needed when a user refuses to share the current location with the app.
     */
    func buildBusStopAlert() {
        busStopAlert = UIAlertController(title: "Bus Stop", message: "Choose bus stop you want information for.", preferredStyle: .actionSheet)
        
        busStopAlert.addAction(UIAlertAction(title:"Main Entrance (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.MAIN_ENTRANCE_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.BARN_THEATER_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.MAIN_ENTRANCE_OUTER]
            print("Main Entrance (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Barn Theater (Inner)", style: .default, handler: { (action) in
            self.closestInnerBusStopToUser = self.cwBusStopList[self.BARN_THEATER_INNER]
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.MAIN_ENTRANCE_OUTER]
            self.closestBusStopToUser = self.cwBusStopList[self.BARN_THEATER_INNER]
            print("Barn Theater (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Lower Campus (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.LOWER_CAMPUS_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.LOWER_CAMPUS_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.LOWER_CAMPUS_OUTER]
            print("Lower Campus (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Lower Campus (Inner)", style: .default, handler: { (action) in
            self.closestInnerBusStopToUser = self.cwBusStopList[self.LOWER_CAMPUS_INNER]
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.LOWER_CAMPUS_OUTER]
            self.closestBusStopToUser = self.cwBusStopList[self.LOWER_CAMPUS_INNER]
            print("Lower Campus (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Lower Quarry Rd. (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.LOWER_QUARRY_RD_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.LOWER_QUARRY_RD_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.LOWER_QUARRY_RD_OUTER]
            print("Lower Campus (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Lower Quarry Rd. (Inner)", style: .default, handler: { (action) in
            self.closestInnerBusStopToUser = self.cwBusStopList[self.LOWER_QUARRY_RD_INNER]
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.LOWER_QUARRY_RD_OUTER]
            self.closestBusStopToUser = self.cwBusStopList[self.LOWER_QUARRY_RD_INNER]
            print("Lower Quarry Rd. (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"East Remote Parking Lot (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.EAST_REMOTE_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.EAST_REMOTE_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.EAST_REMOTE_OUTER]
            print("East Remote Parking Lot (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"East Remote Parking Lot (Inner)", style: .default, handler: { (action) in
            self.closestInnerBusStopToUser = self.cwBusStopList[self.EAST_REMOTE_INNER]
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.EAST_REMOTE_OUTER]
            self.closestBusStopToUser = self.cwBusStopList[self.EAST_REMOTE_INNER]
            print("East Remote Parking Lot (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"East Field House (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.EAST_FIELD_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.EAST_REMOTE_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.EAST_FIELD_OUTER]
            print("East Field House (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Bookstore (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.BOOKSTORE_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.BOOKSTORE_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.BOOKSTORE_OUTER]
            print("Bookstore (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Bookstore (Inner)", style: .default, handler: { (action) in
            self.closestInnerBusStopToUser = self.cwBusStopList[self.BOOKSTORE_INNER]
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.BOOKSTORE_OUTER]
            self.closestBusStopToUser = self.cwBusStopList[self.BOOKSTORE_INNER]
            print("Bookstore (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Crown College (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.CROWN_COLLEGE_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.BOOKSTORE_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.CROWN_COLLEGE_OUTER]
            print("Crown College (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"College 9/10 (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.COLLEGE_9_10_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.COLLEGE_9_10_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.COLLEGE_9_10_OUTER]
            print("College 9/10 (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"College 9/10 (Inner)", style: .default, handler: { (action) in
            self.closestInnerBusStopToUser = self.cwBusStopList[self.COLLEGE_9_10_INNER]
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.COLLEGE_9_10_OUTER]
            self.closestBusStopToUser = self.cwBusStopList[self.COLLEGE_9_10_INNER]
            print("College 9/10 (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Science Hill (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.SCIENCE_HILL_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.SCIENCE_HILL_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.SCIENCE_HILL_OUTER]
            print("Science Hill (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Science Hill (Inner)", style: .default, handler: { (action) in
            self.closestInnerBusStopToUser = self.cwBusStopList[self.SCIENCE_HILL_INNER]
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.SCIENCE_HILL_OUTER]
            self.closestBusStopToUser = self.cwBusStopList[self.SCIENCE_HILL_INNER]
            print("Science Hill (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Kresge College (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.KRESGE_COLLEGE_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.KRESGE_COLLEGE_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.KRESGE_COLLEGE_OUTER]
            print("Kresge College (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Kresge College (Inner)", style: .default, handler: { (action) in
            self.closestInnerBusStopToUser = self.cwBusStopList[self.KRESGE_COLLEGE_INNER]
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.KRESGE_COLLEGE_OUTER]
            self.closestBusStopToUser = self.cwBusStopList[self.KRESGE_COLLEGE_INNER]
            print("Kresge College (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Kerr Hall (Inner)", style: .default, handler: { (action) in
            self.closestInnerBusStopToUser = self.cwBusStopList[self.KERR_HALL_INNER]
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.KRESGE_COLLEGE_OUTER]
            self.closestBusStopToUser = self.cwBusStopList[self.KERR_HALL_INNER]
            print("Kerr Hall (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"College 8/Porter (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.COLLEGE_8_PORTER_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.COLLEGE_8_PORTER_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.COLLEGE_8_PORTER_OUTER]
            print("College 8/Porter (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"College 8/Porter (Inner)", style: .default, handler: { (action) in
            self.closestInnerBusStopToUser = self.cwBusStopList[self.COLLEGE_8_PORTER_INNER]
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.COLLEGE_8_PORTER_OUTER]
            self.closestBusStopToUser = self.cwBusStopList[self.COLLEGE_8_PORTER_INNER]
            print("College 8/Porter (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Family Student Housing (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.FAMILY_STUDENT_HOUSING_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.OAKES_COLLEGE_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.FAMILY_STUDENT_HOUSING_OUTER]
            print("Family Student Housing (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Oakes College (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.OAKES_COLLEGE_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.OAKES_COLLEGE_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.OAKES_COLLEGE_OUTER]
            print("Oakes College (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Oakes College (Inner)", style: .default, handler: { (action) in
            self.closestInnerBusStopToUser = self.cwBusStopList[self.OAKES_COLLEGE_INNER]
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.OAKES_COLLEGE_OUTER]
            self.closestBusStopToUser = self.cwBusStopList[self.OAKES_COLLEGE_INNER]
            print("Oakes College (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Arboretum (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.ARBORETUM_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.ARBORETUM_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.ARBORETUM_OUTER]
            print("Arboretum (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Arboretum (Inner)", style: .default, handler: { (action) in
            self.closestInnerBusStopToUser = self.cwBusStopList[self.ARBORETUM_INNER]
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.ARBORETUM_OUTER]
            self.closestBusStopToUser = self.cwBusStopList[self.ARBORETUM_INNER]
            print("Arboretum (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Tosca Terrace (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.TOSCA_TERRACE_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.WESTERN_DR_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.TOSCA_TERRACE_OUTER]
            print("Tosca Terrace (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Western Dr. (Outer)", style: .default, handler: { (action) in
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.WESTERN_DR_OUTER]
            self.closestInnerBusStopToUser = self.cwBusStopList[self.WESTERN_DR_INNER]
            self.closestBusStopToUser = self.ccwBusStopList[self.WESTERN_DR_OUTER]
            print("Western Dr. (Outer)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
        busStopAlert.addAction(UIAlertAction(title:"Western Dr. (Inner)", style: .default, handler: { (action) in
            self.closestInnerBusStopToUser = self.cwBusStopList[self.WESTERN_DR_INNER]
            self.closestOuterBusStopToUser = self.ccwBusStopList[self.WESTERN_DR_OUTER]
            self.closestBusStopToUser = self.cwBusStopList[self.WESTERN_DR_INNER]
            print("Western Dr. (Inner)")
            self.closestBusStopLabel.text = self.closestBusStopToUser.title
            
            if self.timer == nil { self.startTimer() }
        }))
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
     * Fires whenever we attempt to add an annotation to our MapView.
     * Handles customizing MKAnnotations and MKAnnotationViews.
     */
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if (annotation is MKUserLocation) {
            return nil
        }
        
        var anView: MKAnnotationView!
        
        if annotation is BusStop {
            let busStopAnnotation = annotation as! BusStop
            let reuseId = busStopAnnotation.title!
            anView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId)
            if anView == nil {
                
                anView = MKAnnotationView(annotation: busStopAnnotation, reuseIdentifier: reuseId)
                
                let busStopView = UIView()
                
                let busStopImageView = UIImageView(image: busStopAnnotation.imageName)
                busStopImageView.frame = CGRect(x: 0, y: 0, width: 300, height: 150)
                busStopView.addSubview(busStopImageView)
                
                let widthConstraint = NSLayoutConstraint(item: busStopView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 300)
                let heightConstraint = NSLayoutConstraint(item: busStopView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 150)
                
                busStopView.addConstraint(widthConstraint)
                busStopView.addConstraint(heightConstraint)
                
                anView?.detailCalloutAccessoryView = busStopView
                
                if busStopAnnotation.subtitle == "Inner" {
                    anView.image = UIImage(named: "InnerStop-5")
                } else if busStopAnnotation.subtitle == "Outer" {
                    anView.image = UIImage(named: "OuterStop-4")
                }
                
                anView?.canShowCallout = true
                anView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            } else {
                anView?.annotation = busStopAnnotation
            }
            
        } else if annotation is Bus {
            
            let busAnnotation = annotation as! Bus
            let reuseId = busAnnotation.id
            anView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? BusMKAnnotationView
            
            if anView == nil {
                anView = BusMKAnnotationView(annotation: busAnnotation, reuseIdentifier: reuseId)
                anView?.canShowCallout = true
//                anView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            } else {
                anView?.annotation = busAnnotation
            }
        }
        
        return anView
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        print("CHANGED!!!")
    }
    
    /*
     * Determine the closest bus stops to user's current location.
     */
    func getClosestBusStopsToUser() {
        // Assign a dummy value.
        var closestInnerStop = cwBusStopList[0]
        var closestOuterStop = ccwBusStopList[0]
        
        let userLocationCoordinates = CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        let innerStopCoordinates = CLLocation(latitude: cwBusStopList[0].coordinate.latitude, longitude: cwBusStopList[0].coordinate.longitude)
        let outerStopCoordinates = CLLocation(latitude: ccwBusStopList[0].coordinate.latitude, longitude: ccwBusStopList[0].coordinate.longitude)
        
        // Assign a dummy value to the minimum distance.
        var minDistanceInner = userLocationCoordinates.distance(from: innerStopCoordinates)
        var minDistanceOuter = userLocationCoordinates.distance(from: outerStopCoordinates)
        
        for stop in cwBusStopList {
            let currentStop = CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)
            if userLocationCoordinates.distance(from: currentStop) < minDistanceInner {
                minDistanceInner = userLocationCoordinates.distance(from: currentStop)
                closestInnerStop = stop
            }
        }
        closestInnerBusStopToUser = closestInnerStop
        
        for stop in ccwBusStopList {
            let currentStop = CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)
            if userLocationCoordinates.distance(from: currentStop) < minDistanceOuter {
                minDistanceOuter = userLocationCoordinates.distance(from: currentStop)
                closestOuterStop = stop
            }
        }
        closestOuterBusStopToUser = closestOuterStop
        
        closestBusStopToUser = minDistanceInner < minDistanceOuter ? closestInnerBusStopToUser : closestOuterBusStopToUser
        closestBusStopLabel.text = closestBusStopToUser.title
    }
    
    /*
     * Determines the next stop for each bus.
     */
    func getClosestBusStopToBuses() {
        for bus in newMainBusList.keys {
            let busLocationCoordinates = CLLocation(latitude: (newMainBusList[bus]?.coordinate.latitude)!, longitude: (newMainBusList[bus]?.coordinate.longitude)!)
            let busLocationCoordinates2D = CLLocationCoordinate2D(latitude: (newMainBusList[bus]?.coordinate.latitude)!, longitude: (newMainBusList[bus]?.coordinate.longitude)!)
            
            if newMainBusList[bus]?.direc == "Inner" {
                // Assign dummy values first.
                var closestInnerStop = cwBusStopList[0]
                let innerStopCoordinates = CLLocation(latitude: closestInnerStop.coordinate.latitude, longitude: closestInnerStop.coordinate.longitude)
                var minDistanceInner = busLocationCoordinates.distance(from: innerStopCoordinates)
                
                for stop in cwBusStopList {
                    let currentStop = CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)
                    if busLocationCoordinates.distance(from: currentStop) < minDistanceInner {
                        minDistanceInner = busLocationCoordinates.distance(from: currentStop)
                        closestInnerStop = stop
                    }
                }
                newMainBusList[bus]?.closestInnerStop = closestInnerStop.listIndex
                
                // If we're at the last bus stop in our list, reset next stop to 0.
                if closestInnerStop.listIndex == 12 {
                    if cwBusStopList[(newMainBusList[bus]?.closestInnerStop)!].beforeStop.contains(busLocationCoordinates2D) {
                        newMainBusList[bus]?.closestInnerStop = 12
                    } else {
                        newMainBusList[bus]?.closestInnerStop = 0
                    }
                }
                
                // Check if bus is before or after stop.
                if cwBusStopList[(newMainBusList[bus]?.closestInnerStop)!].beforeStop.contains(busLocationCoordinates2D) {
                    newMainBusList[bus]?.subtitle = cwBusStopList[(newMainBusList[bus]?.closestInnerStop)!].title!
                } else if cwBusStopList[(newMainBusList[bus]?.closestInnerStop)!].afterStop.contains(busLocationCoordinates2D) {
                    newMainBusList[bus]?.closestInnerStop = (newMainBusList[bus]?.closestInnerStop)! + 1
                    newMainBusList[bus]?.subtitle = cwBusStopList[(newMainBusList[bus]?.closestInnerStop)!].title!
                }
            }
            
            if newMainBusList[bus]?.direc == "Outer" {
                // Assign dummy values first.
                var closestOuterStop = ccwBusStopList[0]
                let outerStopCoordinates = CLLocation(latitude: closestOuterStop.coordinate.latitude, longitude: closestOuterStop.coordinate.longitude)
                var minDistanceOuter = busLocationCoordinates.distance(from: outerStopCoordinates)
                
                for stop in ccwBusStopList {
                    let currentStop = CLLocation(latitude: stop.coordinate.latitude, longitude: stop.coordinate.longitude)
                    if busLocationCoordinates.distance(from: currentStop) < minDistanceOuter {
                        minDistanceOuter = busLocationCoordinates.distance(from: currentStop)
                        closestOuterStop = stop
                    }
                }
                newMainBusList[bus]?.closestOuterStop = closestOuterStop.listIndex
                
                // If we're at the last bus stop in our list, reset next stop to 0.
                if closestOuterStop.listIndex == 15 {
                    if ccwBusStopList[(newMainBusList[bus]?.closestOuterStop)!].beforeStop.contains(busLocationCoordinates2D) {
                        newMainBusList[bus]?.closestOuterStop = 15
                    } else {
                        newMainBusList[bus]?.closestOuterStop = 0
                    }
                }
                
                // Check if bus is before or after stop.
                if ccwBusStopList[(newMainBusList[bus]?.closestOuterStop)!].beforeStop.contains(busLocationCoordinates2D) {
                    newMainBusList[bus]?.subtitle = ccwBusStopList[(newMainBusList[bus]?.closestOuterStop)!].title!
                } else if ccwBusStopList[(newMainBusList[bus]?.closestOuterStop)!].afterStop.contains(busLocationCoordinates2D) {
                    newMainBusList[bus]?.closestOuterStop = (newMainBusList[bus]?.closestOuterStop)! + 1
                    newMainBusList[bus]?.subtitle = ccwBusStopList[(newMainBusList[bus]?.closestOuterStop)!].title!
                }
            }
        }
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

