//
//  MapContentViewController.swift
//  MapRoute
//
//  Created by Min Wu on 03/11/2016.
//  Copyright © 2016 CellPointMobile. All rights reserved.
//

import UIKit

class MapContentViewController: UIViewController {
    
    private weak var mapViewController : MapViewController?
    
    //------------------------------------------------------------------------------------------
    // MARK: - View

    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private func configureView() {
        
        self.mapViewController?.showZoneLabels = true
    }

    //------------------------------------------------------------------------------------------
    // MARK: - Navigation
    
    private let mapViewControllerSegueIdentifier = "MapViewController"
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        let mapView = {
            guard let mapViewVC = segue.destination as? MapViewController else {return}
            self.mapViewController = mapViewVC
            self.mapViewController?.dataSource = MapDataModel.sharedDataModel
        }
        
        guard let identifier = segue.identifier else {return}
        
        switch identifier  {
        case self.mapViewControllerSegueIdentifier:
            mapView()
        default:
            break
        }
    }

}
