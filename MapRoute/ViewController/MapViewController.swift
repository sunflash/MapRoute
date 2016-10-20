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
    private var zoneAnnotations = [ZoneAnnotation]()
    private var routes = [MKPolyline]()
    
    private var selectedZones = Set<String>()
    private var neighbourZones = Set<String>()
    
    private let zoneLabelTag = 8
    private let zoneLabelSize : CGFloat = 26
    private let zoneLabelBackgroundColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
    private let zoneLabelBorderColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    private let zoneLabelTextColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    
    private let zonePolygonBorderPathColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
    private let zonePolygonDeselectColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
    private let zonePolygonNeighbourZoneColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)
    private let zonePolygonSelectedColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)
    
    private let routeLineColor = #colorLiteral(red: 0.1411764771, green: 0.3960784376, blue: 0.5647059083, alpha: 1)
    
    private var tapZoneLock = false
    
    enum zoneLabelStyle {
        case basic
        case circularBorder
    }
    
    var showZoneLabels = true
    var zonesLabelsStyle = zoneLabelStyle.circularBorder
    
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
                    self.mapView.addOverlays(self.polygons, level: .aboveLabels)
                }
                
                if self.routes.count > 0 {
                    self.mapView.addOverlays(self.routes, level: .aboveLabels)
                }
                
                if self.zoneAnnotations.count > 0 && self.showZoneLabels == true {
                    self.mapView.addAnnotations(self.zoneAnnotations)
                }
            }
        }
    }
    
    //------------------------------------------------------------------------------------------
    // MARK: - MapView UI
    
    private enum ZonePolygonHighlightState {
        case select
        case deselect
        case neighbour
    }
    
    private func polygonFillColor(zoneNumber: String?) -> UIColor {
        
        if let number = zoneNumber, self.selectedZones.contains(number) {
            return polygonFillColor(state: .select)
        } else if let number = zoneNumber, self.neighbourZones.contains(number) {
            return polygonFillColor(state: .neighbour)
        } else {
            return polygonFillColor(state: .deselect)
        }
    }
    
    private func polygonFillColor(state: ZonePolygonHighlightState) -> UIColor {
    
        let alpha: CGFloat = 0.7
        switch state {
        case .select:
            return self.zonePolygonSelectedColor.withAlphaComponent(alpha)
        case .deselect:
            return self.zonePolygonDeselectColor.withAlphaComponent(alpha)
        case .neighbour:
            return self.zonePolygonNeighbourZoneColor.withAlphaComponent(alpha)
        }
    }
    
    private func highlighZones(zones:Set<String>) {
        
        self.mapViewPolygon { polygonInfo in
            
            guard zones.contains(polygonInfo.zoneNumber) else {return false}
            guard let polygonRender = self.mapView.renderer(for: polygonInfo.polygon) as? MKPolygonRenderer else {return false}
            polygonRender.fillColor = polygonFillColor(state: .select)
            return false
        }
    }
    
    typealias zonePolygonInfo = (zoneNumber:String,polygon:MKPolygon)
    
    func mapViewPolygon(enumerate:(zonePolygonInfo)->Bool) {
        
        for overlay in self.mapView.overlays {
            guard let polygon = overlay as? MKPolygon, let zoneNumber = polygon.title else {continue}
            let polygonInfo:zonePolygonInfo = (zoneNumber,polygon)
            let stop = enumerate(polygonInfo)
            if stop == true {break}
        }
    }
    
    //------------------------------------------------------------------------------------------
    // MARK: - User Action
    
    func displayJourney(zones:Set<String>? = nil,locations:[LocationAnnotation]? = nil, route:[CLLocationCoordinate2D]? = nil) {
        
        self.tapZoneLock = true
        
        if let zones = zones {
            self.highlighZones(zones: zones)
            self.selectedZones = self.selectedZones.union(zones)
        }
        if let locations = locations {
            self.mapView.showAnnotations(locations, animated: false)
        }
        if let route = route {
            let polyline = MKPolyline(coordinates: route, count: route.count)
            self.routes += [polyline]
        }
    }
    
    private enum ZoneAction {
        case selected
        case deselected
        case invalid
    }
    
    private func tapOnZone(zoneNumber: String) -> ZoneAction {
        
        var zoneAction = ZoneAction.invalid
        if selectedZones.contains(zoneNumber) {
            selectedZones.remove(zoneNumber)
            zoneAction = .deselected
        } else if selectedZones.count == 0 || self.neighbourZones.contains(zoneNumber) {
            selectedZones.insert(zoneNumber)
            zoneAction = .selected
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
            case .deselected:
                polygonRender.fillColor = polygonFillColor(state: .deselect)
            case .selected:
                polygonRender.fillColor = polygonFillColor(state: .select)
            default:
                break
            }
    
            self.updateNeighbourZone(tapZoneNumber: zoneNumber, action: action)
            return true
        }
    }
    
    private func updateNeighbourZone(tapZoneNumber: String, action: ZoneAction) {
        
        guard action != .invalid else {return}
        
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
            case .selected:
                addZones = newNeighbourZones(zones)
            case .deselected:
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
                    polygonRender.fillColor = self.polygonFillColor(state: .neighbour)
                    updateCount += 1
                } else if removeZones.contains(zonePolygonInfo.zoneNumber) {
                    guard let polygonRender = self.mapView.renderer(for: zonePolygonInfo.polygon) as? MKPolygonRenderer else {return false};
                    polygonRender.fillColor = self.polygonFillColor(state: .deselect)
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
            render.lineWidth = 1
            render.fillColor = self.polygonFillColor(zoneNumber: polygon.title)
            return render
            
        } else if let polyline = overlay as? MKPolyline {
            
            let render = MKPolylineRenderer(overlay: polyline)
            render.lineWidth = 3
            render.strokeColor = self.routeLineColor
            return render
        }
        return  MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
 
        if annotation is MKUserLocation {
            return nil
        }
        
        if let zoneAnnotation = annotation as? ZoneAnnotation  {
            
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: zoneAnnotation.identifier) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: zoneAnnotation.identifier)
            annotationView.annotation = annotation
            annotationView.canShowCallout = false
            
            if let zoneNumberLabel = annotationView.viewWithTag(self.zoneLabelTag) as? UILabel {
                zoneNumberLabel.text = annotation.title ?? ""
            } else {
                
                let centerLabel:(CGFloat)->CGRect = { size in
                    let point = -size/2
                    return CGRect(x: point, y: point, width: size, height: size)
                }
                
                let zoneNumberLabel = UILabel(frame: centerLabel(self.zoneLabelSize))
                zoneNumberLabel.textAlignment = .center
                zoneNumberLabel.textColor = self.zoneLabelTextColor
                zoneNumberLabel.font = UIFont.boldSystemFont(ofSize: 10)
                zoneNumberLabel.text = annotation.title ?? ""
                zoneNumberLabel.tag = self.zoneLabelTag
                
                if self.zonesLabelsStyle == .circularBorder {
                    zoneNumberLabel.layer.backgroundColor = self.zoneLabelBackgroundColor.cgColor
                    zoneNumberLabel.layer.cornerRadius = (self.zoneLabelSize / 2)
                    zoneNumberLabel.layer.borderColor = self.zoneLabelBorderColor.cgColor
                    zoneNumberLabel.layer.borderWidth = 1
                }
                
                annotationView.addSubview(zoneNumberLabel)
            }
            return annotationView
            
        } else if let locationAnnotation = annotation as? LocationAnnotation {
            
            let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: locationAnnotation.identifier) ?? MKPinAnnotationView(annotation: annotation, reuseIdentifier: locationAnnotation.identifier)
            annotationView.annotation = annotation
            annotationView.canShowCallout = true
            return annotationView
        }
        
        return nil
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        guard self.mapView.annotations.count > 0 else {return}
        
        let latitudeDelta = mapView.region.span.latitudeDelta
        let hidden = latitudeDelta > 0.55
        
        for annotation in self.mapView.annotations {
            guard annotation is ZoneAnnotation else {continue}
            let annotationView = self.mapView.view(for: annotation)
            annotationView?.isHidden = hidden
        }
    }
}

