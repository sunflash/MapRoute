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
    
    private var zoneData = [String:FareZone]()
    private var polygons = [MKPolygon]()
    private var annotations = [MKPointAnnotation]()
    
    private var selectedZones = Set<String>()
    private var neighbourZones = Set<String>()
    
    private let zoneLabelTag = 8
    private let zoneLabelBackgroundColor = #colorLiteral(red: 0.9411764741, green: 0.4980392158, blue: 0.3529411852, alpha: 1)
    private let zoneLabelBorderColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    private let zoneLabelTextColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    
    private let zonePolygonBorderPathColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
    private let zonePolygonDeselectColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
    private let zonePolygonNeighbourZoneColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)
    private let zonePolygonSelectedColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
    
    //------------------------------------------------------------------------------------------
    // MARK: - View
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.configureMapView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func configureMapView() {
    
        self.addMapOverlays()
        self.mapView.showsPointsOfInterest = false
        self.mapView.isRotateEnabled = false
        self.mapView.isPitchEnabled = false
        self.mapView.delegate = self
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(tap:)))
        singleTap.numberOfTapsRequired = 1
        
        let doubleTap = UITapGestureRecognizer(target: self, action: nil)
        doubleTap.numberOfTapsRequired = 2
        singleTap.require(toFail: doubleTap)
        self.mapView.addGestureRecognizer(singleTap)
        self.mapView.addGestureRecognizer(doubleTap)
    }

    private func addMapOverlays() {
        
        DataSource.sharedDataSource.zoneData { zoneData, polygons, annotations in
            
            DispatchQueue.main.async {
                
                self.zoneData = zoneData
                self.polygons = polygons
                self.annotations = annotations
                
                guard self.polygons.count != 0, self.annotations.count != 0 else {return}
                self.mapView.addOverlays(self.polygons, level: MKOverlayLevel.aboveLabels)
                self.mapView.showAnnotations(self.annotations, animated: false)
            }
        }
    }
    
    func polygonFillColor(zoneNumber: String?) -> UIColor {
        
        if let number = zoneNumber, selectedZones.contains(number) {
            return self.zonePolygonSelectedColor.withAlphaComponent(0.7)
        } else {
            return self.zonePolygonDeselectColor.withAlphaComponent(0.7)
        }
    }
    
    //------------------------------------------------------------------------------------------
    // MARK: - User Action
    
    func handleMapTap(tap: UIGestureRecognizer) {
        
        let tapPoint = tap.location(in: self.mapView)
        let tapCoordinate = self.mapView.convert(tapPoint, toCoordinateFrom: self.mapView)
        let tapMapPoint = MKMapPointForCoordinate(tapCoordinate)
        
        for overlay in self.mapView.overlays {
            
            guard let polygon = overlay as? MKPolygon, let polygonRender = self.mapView.renderer(for: polygon) as? MKPolygonRenderer else {continue}
            let polygonPoint = polygonRender.point(for: tapMapPoint)
            guard polygonRender.path.contains(polygonPoint) != false else {continue}
            
            guard let zoneNumber = polygon.title else {continue}
            if selectedZones.contains(zoneNumber) {
                selectedZones.remove(zoneNumber)
            } else {
                selectedZones.insert(zoneNumber)
            }
            polygonRender.fillColor = self.polygonFillColor(zoneNumber: zoneNumber)
            
            self.updateNeighbourZone(tapZoneNumber: zoneNumber)
            break
        }
    }
    
    func updateNeighbourZone(tapZoneNumber: String) {
        
        if let zones = self.zoneData[tapZoneNumber]?.neighbourZones {
            
            var newNeighbourZones = Set(zones)
            newNeighbourZones = newNeighbourZones.subtracting(self.neighbourZones)
            self.neighbourZones = self.neighbourZones.union(zones)
            
            print(newNeighbourZones)
            
            for overlay in self .mapView.overlays {
                
                guard let polygon = overlay as? MKPolygon, let zoneNumber = polygon.title, newNeighbourZones.contains(zoneNumber) else {continue}
                guard let polygonRender = self.mapView.renderer(for: polygon) as? MKPolygonRenderer else {continue};
                polygonRender.fillColor = self.zonePolygonNeighbourZoneColor.withAlphaComponent(0.7)
            }
        }
    }
    
    //------------------------------------------------------------------------------------------
    // MARK: - MapView Delegate
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if let polygon = overlay as? MKPolygon {
            
            let render = MKPolygonRenderer(polygon: polygon)
            render.strokeColor = self.zonePolygonBorderPathColor
            render.lineWidth = 1;
            render.fillColor = self.polygonFillColor(zoneNumber: polygon.title)
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
        annotationView.canShowCallout = false
        
        if let zoneNumberLabel = annotationView.viewWithTag(self.zoneLabelTag) as? UILabel {
            zoneNumberLabel.text = annotation.title ?? ""
        } else {
        
            let zoneNumberLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 26, height: 26))
            zoneNumberLabel.textAlignment = .center
            zoneNumberLabel.textColor = self.zoneLabelTextColor
            zoneNumberLabel.font = UIFont.boldSystemFont(ofSize: 10)
            zoneNumberLabel.text = annotation.title ?? ""
            zoneNumberLabel.tag = self.zoneLabelTag
            zoneNumberLabel.layer.backgroundColor = self.zoneLabelBackgroundColor.cgColor
            zoneNumberLabel.layer.cornerRadius = 13
            zoneNumberLabel.layer.borderColor = self.zoneLabelBorderColor.cgColor
            zoneNumberLabel.layer.borderWidth = 1
            annotationView.addSubview(zoneNumberLabel)
        }
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        let latitudeDelta = mapView.region.span.latitudeDelta
        let hidden = latitudeDelta > 1.0
        
        for annotation in self.mapView.annotations {
            let annotationView = self.mapView.view(for: annotation)
            annotationView?.isHidden = hidden
        }
    }
}

