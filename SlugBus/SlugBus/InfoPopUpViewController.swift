//
//  InfoPopUpViewController.swift
//  SlugBus
//
//  Created by Ivan Alvarado on 2/2/18.
//  Copyright © 2018 UCSC Slugs. All rights reserved.
//

import UIKit

class InfoPopUpViewController: UIViewController {

    @IBOutlet weak var infoPopUpView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        infoPopUpView.layer.cornerRadius = 10
        infoPopUpView.layer.borderWidth = 3.0
        infoPopUpView.layer.borderColor = UIColor.white.cgColor
        infoPopUpView.clipsToBounds = true
        infoPopUpView.layer.masksToBounds = true
//        infoPopUpView.backgroundColor =
        self.view.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        self.showAnimate()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func closeInfoPopUp() {
        self.removeAnimate()
    }
    
    func showAnimate() {
        self.view.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        self.view.alpha = 0.0;
        UIView.animate(withDuration: 0.25, animations: {
            self.view.alpha = 1.0
            self.view.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        });
    }
    
    func removeAnimate() {
        UIView.animate(withDuration: 0.25, animations: {
            self.view.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            self.view.alpha = 0.0;
        }, completion:{(finished : Bool)  in
            if (finished)
            {
                self.view.removeFromSuperview()
            }
        });
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch: UITouch? = touches.first
        
        if touch?.view != infoPopUpView {
            removeAnimate()
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
