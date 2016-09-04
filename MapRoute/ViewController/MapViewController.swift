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
    
    private let zoomLabelTag = 8
    
    //------------------------------------------------------------------------------------------
    // MARK: - View
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.addOverlays()
        self.mapView.showsPointsOfInterest = false
        self.mapView.isRotateEnabled = false
        self.mapView.isPitchEnabled = false
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
    
    //------------------------------------------------------------------------------------------
    // MARK: - MapView Delegate
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if overlay is MKPolygon {
            
            let render = MKPolygonRenderer(overlay: overlay)
            render.strokeColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
            render.lineWidth = 1;
            render.fillColor = #colorLiteral(red: 0.9686274529, green: 0.78039217, blue: 0.3450980484, alpha: 1).withAlphaComponent(0.7)
            return render
        }
        return  MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
 
        if annotation is MKUserLocation {
            return nil
        }
        
        let identifier = "zoneNumber"
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        annotationView.annotation = annotation
        annotationView.canShowCallout = true
        
        if let zoneNumberLabel = annotationView.viewWithTag(self.zoomLabelTag) as? UILabel {
            zoneNumberLabel.text = annotation.title ?? ""
        } else {
        
            let zoneNumberLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 26, height: 26))
            zoneNumberLabel.textAlignment = .center
            zoneNumberLabel.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
            zoneNumberLabel.font = UIFont.boldSystemFont(ofSize: 10)
            zoneNumberLabel.text = annotation.title ?? ""
            zoneNumberLabel.tag = self.zoomLabelTag
            zoneNumberLabel.layer.backgroundColor = #colorLiteral(red: 0.9372549057, green: 0.3490196168, blue: 0.1921568662, alpha: 1).cgColor
            zoneNumberLabel.layer.cornerRadius = 13
            zoneNumberLabel.layer.borderColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1).cgColor
            zoneNumberLabel.layer.borderWidth = 1
            annotationView.addSubview(zoneNumberLabel)
        }
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        let latitudeDelta = mapView.region.span.latitudeDelta
        let hidden = latitudeDelta > 0.5
        
        for annotation in self.mapView.annotations {
            let annotationView = self.mapView.view(for: annotation)
            annotationView?.isHidden = hidden
        }
    }
}

