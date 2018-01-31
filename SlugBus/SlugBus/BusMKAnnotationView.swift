//
//  BusMKAnnotationView.swift
//  SlugBus
//
//  Created by Ivan Alvarado on 1/30/18.
//  Copyright © 2018 UCSC Slugs. All rights reserved.
//

import MapKit
import UIKit

class BusMKAnnotationView: MKAnnotationView {
    
    var busAnnotation: Bus!
    
    override init(annotation: MKAnnotation!, reuseIdentifier: String!) {
        busAnnotation = annotation as! Bus
        
        super.init(annotation: busAnnotation, reuseIdentifier: reuseIdentifier)
        
        determineBusIcon()
        updateBusInfo()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /*
     * Determines which bus icon to for Bus Annotations depending on the type of bus it is.
     * Types: Loop, Upper Campus, Out of Service.
     */
    func determineBusIcon() {
        if (busAnnotation.title?.contains("OUT OF SERVICE"))! {
            self.image = UIImage(named: "OutOfService")
        } else if (busAnnotation.title?.contains("UPPER CAMPUS"))! {
            self.image = UIImage(named: "UpperCampus")
        } else if (busAnnotation.title?.contains("LOOP"))! {
            self.image = UIImage(named: "Loop")
        }
    }
    
    /*
     * Updates bus information.
     * Info: Bus Direction, Next Stop, and ETA.
     */
    func updateBusInfo() {
        
        let busInfoView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 150))
        
        let directionLabel = UILabel(frame: CGRect(x: 0, y: 5, width: 300, height: 20))
        let nextStopLabel = UILabel(frame: CGRect(x: 0, y: 25, width: 300, height: 20))
        let etaLabel = UILabel(frame: CGRect(x: 0, y: 45, width: 300, height: 20))
        
        directionLabel.text = "Direction: " + busAnnotation.direc
        nextStopLabel.text = "Next Stop: " + (busAnnotation.subtitle != nil ? busAnnotation.subtitle! : "Still Determining")
        etaLabel.text = "ETA: " + String(busAnnotation.direc == "Inner" ? busAnnotation.innerETA : busAnnotation.outerETA)
        
        busInfoView.addSubview(directionLabel)
        busInfoView.addSubview(nextStopLabel)
        busInfoView.addSubview(etaLabel)
        
        let widthConstraint = NSLayoutConstraint(item: busInfoView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 300)
        let heightConstraint = NSLayoutConstraint(item: busInfoView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 60)
        
        busInfoView.addConstraint(widthConstraint)
        busInfoView.addConstraint(heightConstraint)
        
        self.detailCalloutAccessoryView = busInfoView
    }
    
    func reloadData() {
        self.setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        determineBusIcon()
        updateBusInfo()
    }
}
