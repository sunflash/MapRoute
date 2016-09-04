//
//  MapViewController.swift
//  MapRoute
//
//  Created by Min Wu on 02/09/16.
//  Copyright © 2016 CellPointMobile. All rights reserved.
//

import UIKit
import MapKit

class MapViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak private var mapView : MKMapView!
    
    private var zoneInfo = [String:FareZone]()
    private var polygons = [MKPolygon]()
    private var annotations = [MKPointAnnotation]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.addOverlays()
        self.mapView.showsPointsOfInterest = false
        self.mapView.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private func addOverlays() {
        
        DataSource.sharedDataSource.zoneData { zoneInfo, polygons, annotations in
            
            DispatchQueue.main.async {
                
                self.zoneInfo = zoneInfo
                self.polygons = polygons
                self.annotations = annotations
                
                guard self.polygons.count != 0, self.annotations.count != 0 else {return}
                self.mapView.addOverlays(self.polygons, level: MKOverlayLevel.aboveLabels)
                self.mapView.showAnnotations(self.annotations, animated: false)
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if overlay is MKPolygon {
            
            let render = MKPolygonRenderer(overlay: overlay)
            render.strokeColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
            render.lineWidth = 3;
            render.fillColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
            return render
        }
        return  MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
 
        if annotation is MKUserLocation {
            return nil
        }
        
        let identifier = "place"
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        annotationView.annotation = annotation
        annotationView.canShowCallout = true
        annotationView.image = #imageLiteral(resourceName: "first")

        return annotationView
    }
}

