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
    private var zoneAnnotations = [MKPointAnnotation]()
    
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
    
    private var tapZoneLock = false
    
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
                self.zoneAnnotations = annotations
                
                if self.polygons.count > 0 {
                    self.mapView.addOverlays(self.polygons, level: MKOverlayLevel.aboveLabels)
                }
                
                if self.zoneAnnotations.count > 0 {
                    self.mapView.showAnnotations(self.zoneAnnotations, animated: false)
                }
                
                //self.showJouney()
            }
        }
    }
    
    private func showJouney() {
        
        self.tapZoneLock = true
        
        let highlightZones = DataSource.highLightZones()
        self.highlighZones(zones: highlightZones)
        self.selectedZones = highlightZones
    
        let jouneyBegin = MKPointAnnotation()
        jouneyBegin.coordinate = CLLocationCoordinate2DMake( 55.683729, 12.590080)
        jouneyBegin.title = "København, Frederiksberg, City"
        jouneyBegin.subtitle = "Bredgade 36, 1260 København K"
        
        let jouneyEnd = MKPointAnnotation()
        jouneyEnd.coordinate = CLLocationCoordinate2DMake(55.215841, 11.812547)
        jouneyEnd.title = "Næstved"
        jouneyEnd.subtitle = "Bystævnet 8, Rønnebæk, 4700 Næstved"
        
        self.mapView.showAnnotations([jouneyBegin,jouneyEnd], animated: false);
    }
    
    private enum ZonePolygonHighlightState {
        case Select
        case Deselect
        case Neighbour
    }
    
    private func polygonFillColor(zoneNumber: String?) -> UIColor {
        
        if let number = zoneNumber, self.selectedZones.contains(number) {
            return polygonFillColor(state: .Select)
        } else if let number = zoneNumber, self.neighbourZones.contains(number) {
            return polygonFillColor(state: .Neighbour)
        } else {
            return polygonFillColor(state: .Deselect)
        }
    }
    
    private func polygonFillColor(state: ZonePolygonHighlightState) -> UIColor {
    
        let alpha: CGFloat = 0.7
        switch state {
        case .Select:
            return self.zonePolygonSelectedColor.withAlphaComponent(alpha)
        case .Deselect:
            return self.zonePolygonDeselectColor.withAlphaComponent(alpha)
        case .Neighbour:
            return self.zonePolygonNeighbourZoneColor.withAlphaComponent(alpha)
        }
    }
    
    private func highlighZones(zones:Set<String>) {
        
        self.mapViewPolygon { polygonInfo in
            
            guard zones.contains(polygonInfo.zoneNumber) else {return false}
            guard let polygonRender = self.mapView.renderer(for: polygonInfo.polygon) as? MKPolygonRenderer else {return false}
            polygonRender.fillColor = polygonFillColor(state: .Select)
            return false
        }
    }
    
    //------------------------------------------------------------------------------------------
    // MARK: - User Action
    
    typealias zonePolygonInfo = (zoneNumber:String,polygon:MKPolygon)
    
    func mapViewPolygon(enumerate:(zonePolygonInfo)->Bool) {
        
        for overlay in self.mapView.overlays {
            guard let polygon = overlay as? MKPolygon, let zoneNumber = polygon.title else {continue}
            let polygonInfo:zonePolygonInfo = (zoneNumber,polygon)
            let stop = enumerate(polygonInfo)
            if stop == true {break}
        }
    }
    
    private enum ZoneAction {
        case Selected
        case Deselected
        case Invalid
    }
    
    private func tapOnZone(zoneNumber: String) -> ZoneAction {
        
        var zoneAction = ZoneAction.Invalid
        if selectedZones.contains(zoneNumber) {
            selectedZones.remove(zoneNumber)
            zoneAction = .Deselected
        } else if selectedZones.count == 0 || self.neighbourZones.contains(zoneNumber) {
            selectedZones.insert(zoneNumber)
            zoneAction = .Selected
        } else {
            print("Tap zone isn't neighbour zone to selected zones.")
        }
        return zoneAction
    }
    
    @objc private func handleMapTap(tap: UIGestureRecognizer) {
        
        guard tapZoneLock == false else {return}
        
        let tapPoint = tap.location(in: self.mapView)
        let tapCoordinate = self.mapView.convert(tapPoint, toCoordinateFrom: self.mapView)
        let tapMapPoint = MKMapPointForCoordinate(tapCoordinate)
        
        self.mapViewPolygon { polygonInfo in
            
            guard let polygonRender = self.mapView.renderer(for: polygonInfo.polygon) as? MKPolygonRenderer else {return false}
            let polygonPoint = polygonRender.point(for: tapMapPoint)
            guard polygonRender.path.contains(polygonPoint) != false else {return false}
            
            let zoneNumber = polygonInfo.zoneNumber
            let action = self.tapOnZone(zoneNumber: zoneNumber)
            
            switch action {
            case .Deselected:
                polygonRender.fillColor = polygonFillColor(state: .Deselect)
            case .Selected:
                polygonRender.fillColor = polygonFillColor(state: .Select)
            default:
                break
            }
    
            self.updateNeighbourZone(tapZoneNumber: zoneNumber, action: action)
            return true
        }
    }
    
    private func updateNeighbourZone(tapZoneNumber: String, action: ZoneAction) {
        
        guard action != .Invalid else {return}
        
        if let zones = self.zoneData[tapZoneNumber]?.neighbourZones {
            
            let newNeighbourZones : (Set<String>) -> Set<String> = {zones in
                
                var newNeighbourZones = Set(zones)
                newNeighbourZones = newNeighbourZones.subtracting(self.neighbourZones)
                newNeighbourZones = newNeighbourZones.subtracting(self.selectedZones)
                self.neighbourZones = self.neighbourZones.union(zones)
                return newNeighbourZones
            }
            
            let removeNeighbourZones : (String,Set<String>) -> Set<String> = { tapZone, zones in
                
                var removeNeighbourZones = Set(zones)
                removeNeighbourZones = removeNeighbourZones.subtracting(self.selectedZones)
                for selectedZone in self.selectedZones {
                    guard tapZone != selectedZone, let neighbourZones = self.zoneData[selectedZone]?.neighbourZones else {continue}
                    removeNeighbourZones = removeNeighbourZones.subtracting(neighbourZones)
                }
                self.neighbourZones = self.neighbourZones.subtracting(removeNeighbourZones)
                return removeNeighbourZones
            }
            
            var addZones = Set<String>()
            var removeZones = Set<String>()
            
            switch action {
            case .Selected:
                addZones = newNeighbourZones(zones)
            case .Deselected:
                removeZones = removeNeighbourZones(tapZoneNumber,zones)
                if self.neighbourZones.contains(tapZoneNumber) {
                    addZones = [tapZoneNumber]
                }
            default:
                break
            }
            
            let updateTotalCount = addZones.count + removeZones.count
            var updateCount = 0
            
            guard updateTotalCount != 0 else {return}
            
            self.mapViewPolygon { zonePolygonInfo in
                
                if addZones.contains(zonePolygonInfo.zoneNumber) {
                    guard let polygonRender = self.mapView.renderer(for: zonePolygonInfo.polygon) as? MKPolygonRenderer else {return false};
                    polygonRender.fillColor = self.polygonFillColor(state: .Neighbour)
                    updateCount += 1
                } else if removeZones.contains(zonePolygonInfo.zoneNumber) {
                    guard let polygonRender = self.mapView.renderer(for: zonePolygonInfo.polygon) as? MKPolygonRenderer else {return false};
                    polygonRender.fillColor = self.polygonFillColor(state: .Deselect)
                    updateCount += 1
                }
                return (updateCount >= updateTotalCount)
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
        
        if self.zoneAnnotations.contains(annotation as! MKPointAnnotation) {
            
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
            
        } else {
            
            let identifier = "pins"
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) ?? MKPinAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            annotationView.annotation = annotation
            annotationView.canShowCallout = true
        }
        
        return nil
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        let latitudeDelta = mapView.region.span.latitudeDelta
        let hidden = latitudeDelta > 1.0
        
        for annotation in self.mapView.annotations {
            
            guard let pointAnnotation = annotation as? MKPointAnnotation, self.zoneAnnotations.contains(pointAnnotation) else {return}
            
            let annotationView = self.mapView.view(for: annotation)
            annotationView?.isHidden = hidden
        }
    }
}

