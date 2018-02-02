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
            self.image = UIImage(named: "OutOfServiceBus")
        } else if (busAnnotation.title?.contains("UPPER CAMPUS"))! {
            self.image = UIImage(named: "UpperCampusBus")
        } else if (busAnnotation.title?.contains("LOOP"))! {
            self.image = UIImage(named: "LoopBus")
        }
    }
    
    /*
     * Updates bus information.
     * Info: Bus Direction, Next Stop, and ETA.
     */
    func updateBusInfo() {
        
        let busInfoView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 150))
        
        let directionLabel = UILabel(frame: CGRect(x: 0, y: 5, width: 50, height: 20))
        let nextStopLabel = UILabel(frame: CGRect(x: 0, y: 25, width: 50, height: 20))
        let etaLabel = UILabel(frame: CGRect(x: 0, y: 45, width: 50, height: 20))
        
        directionLabel.text = "Direction: "// + busAnnotation.direc
        nextStopLabel.text = "Next Stop: "// + (busAnnotation.subtitle != nil ? busAnnotation.subtitle! : "Still Determining")
        etaLabel.text = "ETA: "// + busAnnotation.actualETA
        
        // Resize the UILabels.
        directionLabel.sizeToFit()
        nextStopLabel.sizeToFit()
        etaLabel.sizeToFit()
        
        let direction = UILabel(frame: CGRect(x: directionLabel.intrinsicContentSize.width, y: 5, width: 50, height: 20))
        let nextStop = UILabel(frame: CGRect(x: nextStopLabel.intrinsicContentSize.width, y: 25, width: 50, height: 20))
        let eta = UILabel(frame: CGRect(x: etaLabel.intrinsicContentSize.width, y: 45, width: 50, height: 20))
        
        direction.text = busAnnotation.direc
        nextStop.text = (busAnnotation.subtitle != nil ? busAnnotation.subtitle! : "Still Determining")
        eta.text = busAnnotation.actualETA
        
        direction.font = UIFont.boldSystemFont(ofSize: 17.0)
        nextStop.font = UIFont.boldSystemFont(ofSize: 17.0)
        eta.font = UIFont.boldSystemFont(ofSize: 17.0)
        eta.textColor = UIColor(red: CGFloat(0/255.0), green: CGFloat(100/255.0), blue: CGFloat(0/255.0), alpha: 1.0)
        
        direction.sizeToFit()
        nextStop.sizeToFit()
        eta.sizeToFit()
        
        busInfoView.addSubview(directionLabel)
        busInfoView.addSubview(direction)
        busInfoView.addSubview(nextStopLabel)
        busInfoView.addSubview(nextStop)
        busInfoView.addSubview(etaLabel)
        busInfoView.addSubview(eta)
        
        let nextStopWidth = nextStopLabel.intrinsicContentSize.width + nextStop.intrinsicContentSize.width
        let etaWidth = etaLabel.intrinsicContentSize.width + eta.intrinsicContentSize.width
        let nsLayoutWidth = nextStopWidth > etaWidth ? nextStopWidth : etaWidth
        
        let widthConstraint = NSLayoutConstraint(item: busInfoView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: nsLayoutWidth)
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
