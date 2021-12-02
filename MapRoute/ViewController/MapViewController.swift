//
//  MapViewController.swift
//  MapRoute
//
//  Created by Min Wu on 02/09/16.
//  Copyright © 2016 CellPointMobile. All rights reserved.
//

import UIKit
import MapKit

// swiftlint:disable file_length

//------------------------------------------------------------------------------------------
// MARK: - MapViewControllerDelegate

protocol MapViewControllerDelegate: AnyObject {
    func shoudSelectRoute(index: Int) -> Bool
    func selectedZones(zones: Set<String>)
    func selectedZoneIsNotConnected()
    func exceedMaxSelectedZoneLimit()
}

extension MapViewControllerDelegate { // Delegate default
    func shoudSelectRoute(index: Int) -> Bool {
        true
    }
    func selectedZones(zones: Set<String>) {} // Optional
    func selectedZoneIsNotConnected() {} // Optional
    func exceedMaxSelectedZoneLimit() {} // Optional
}

//------------------------------------------------------------------------------------------
// MARK: - MapViewControllerDataSource

protocol MapViewControllerDataSource: AnyObject {

    func zoneData(completion: @escaping ([String: FareZone], [MKPolygon], [ZoneAnnotation]) -> Void)
}

//------------------------------------------------------------------------------------------
// MARK: - Map View Controller Objects

struct FareZone {

    let name: String
    let zoneNumber: String
    let neighbourZones: Set<String>
    let centerCoordinate: CLLocationCoordinate2D
    let polygon: MKPolygon
}

class ZoneAnnotation: MKPointAnnotation {
    let identifier = "zoneNumber"
}

class LocationAnnotation: MKPointAnnotation {
    let identifier = "location"
    var imageName: String?
    var showCalloutDelay: Double?
    var showCalloutDuration: Double?
}

//------------------------------------------------------------------------------------------
// MARK: - MapViewController

class MapViewController: UIViewController, MKMapViewDelegate {

    @IBOutlet weak private(set) var mapView: MKMapView!

    private var zoneData = [String: FareZone]()
    private var polygons = [MKPolygon]()
    private var zoneAnnotations = [ZoneAnnotation]()
    private var locationAnnotations = [LocationAnnotation]()
    private var routes = [MKPolyline]()

    private var selectedZones = Set<String>()
    private var neighbourZones = Set<String>()

    private let zoneLabelTag = 8
    private let zoneLabelSize: CGFloat = 26
    private let zoneLabelBackgroundColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
    private let zoneLabelBorderColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    private let zoneLabelTextColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)

    private let zonePolygonBorderPathColor = #colorLiteral(red: 0.501960814, green: 0.501960814, blue: 0.501960814, alpha: 1)
    private let zonePolygonDeselectColor = #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1)
    private let zonePolygonNeighbourZoneColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)
    private let zonePolygonSelectedColor = #colorLiteral(red: 0.4666666687, green: 0.7647058964, blue: 0.2666666806, alpha: 1)

    private let routeLineColor = #colorLiteral(red: 0.1411764771, green: 0.3960784376, blue: 0.5647059083, alpha: 1)
    private let routeSelectedLineColor = #colorLiteral(red: 0.1647058824, green: 0.9921568627, blue: 0.1843137255, alpha: 1)

    private let boundingRegionColor = #colorLiteral(red: 0.9764705896, green: 0.850980401, blue: 0.5490196347, alpha: 1)

    var tapZoneLock = false
    var maxSelectedZoneLimit: Int?
    var areaBoundingRegion: MKCoordinateRegion?

    var showBoundingRegion = false

    enum ZoneLabelStyle {
        case basic
        case circularBorder
    }

    var showZoneLabels = false
    var zonesLabelsStyle = ZoneLabelStyle.basic

    weak var delegate: MapViewControllerDelegate?
    weak var dataSource: MapViewControllerDataSource?

    private(set) var selectedRouteIndex: Int?
    private(set) var higlightRouteIndices = Set<Int>()
    private(set) var defaultRegion: MKCoordinateRegion?
    private(set) var isNeighbourZoneHidden = false

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
        self.mapView.isRotateEnabled = false
        self.mapView.isPitchEnabled = false
        if #available(iOS 9.0, *) {
            self.mapView.showsScale = false
        }
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

        self.dataSource?.zoneData { zoneData, polygons, annotations in

            DispatchQueue.main.async {

                self.zoneData = zoneData
                self.polygons = polygons
                self.zoneAnnotations = annotations

                if self.polygons.isEmpty == false {
                    self.mapView.addOverlays(self.polygons, level: .aboveLabels)
                }

                self.showMapOverlay()
            }
        }
    }

    private func showMapOverlay() {

        if self.routes.isEmpty == false {
            for (index, route) in self.routes.enumerated() {
                route.title = String(index)
                if index != self.selectedRouteIndex {
                    self.mapView.addOverlay(route, level: .aboveLabels)
                }
            }
            if let selectedRouteIndex = self.selectedRouteIndex { // Add selected route to top
                self.mapView.addOverlay(self.routes[selectedRouteIndex], level: .aboveLabels)
            }
        }

        let showLocations = (self.locationAnnotations.isEmpty == false)
        let showSelectedZone = (self.selectedZones.isEmpty == false)
        let showRegion = (self.defaultRegion != nil || self.areaBoundingRegion != nil)

        if self.zoneAnnotations.isEmpty == false && self.showZoneLabels == true {
            if showLocations || showSelectedZone || showRegion {
                self.mapView.addAnnotations(self.zoneAnnotations)
            } else {
                self.mapView.showAnnotations(self.zoneAnnotations, animated: false)
            }
        }

        if showLocations == true && showSelectedZone == true {
            self.mapView.addAnnotations(self.locationAnnotations)
            self.zoomIntoSelectedZone()
        } else if showLocations == true {
            self.mapView.showAnnotations(self.locationAnnotations, animated: false)
        } else if showSelectedZone == true {
            self.zoomIntoSelectedZone()
        }

        if self.tapZoneLock == false {
            self.showNeighbourZone()
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

    private func changeZonesFillColors(zones: Set<String>, state: ZonePolygonHighlightState) {
        for zoneNumber in zones {
            guard let zoneInfo = self.zoneData[zoneNumber] else {continue}
            guard let polygonRender = self.mapView.renderer(for: zoneInfo.polygon) as? MKPolygonRenderer else {return}
            polygonRender.fillColor = self.polygonFillColor(state: state)
        }
    }

    private func highlightRoute(routeIndex: Int) {

        for (index, route) in self.routes.enumerated() {
            guard let routeRender = self.mapView.renderer(for: route) as? MKPolylineRenderer else {continue}
            routeRender.strokeColor = (index == routeIndex) ? self.routeSelectedLineColor : self.routeLineColor
            if index == routeIndex {
                let topIndex = self.mapView.overlays.count - 1
                self.mapView.insertOverlay(route, at: topIndex)
            }
        }
    }

    private typealias ZonePolygonInfo = (zoneNumber: String, polygon: MKPolygon)

    private func mapViewPolygon(enumerate: (ZonePolygonInfo) -> Bool) {

        for overlay in self.mapView.overlays {
            guard let polygon = overlay as? MKPolygon, let zoneNumber = polygon.title else {continue}
            let polygonInfo: ZonePolygonInfo = (zoneNumber, polygon)
            let stop = enumerate(polygonInfo)
            if stop == true {break}
        }
    }

    private func zoomIntoSelectedZone(animated: Bool = false) {

        guard self.polygons.isEmpty == false else {return}

        let mapRects = self.polygons.filter {self.selectedZones.contains($0.title ?? "")}.map {self.mapView.mapRectThatFits($0.boundingMapRect)}

        let minX = mapRects.map {$0.origin.x}.min()
        let minY = mapRects.map {$0.origin.y}.min()
        let maxX = mapRects.map {$0.origin.x+$0.size.width}.max()
        let maxY = mapRects.map {$0.origin.y+$0.size.height}.max()
        guard let pX = minX, let pY = minY else {return} // swiftlint:disable:this identifier_name
        guard let mX = maxX, let mY = maxY else {return} // swiftlint:disable:this identifier_name
        let width = mX - pX
        let height = mY - pY
        let zoomMapRect = MKMapRect(origin: MKMapPoint(x: pX, y: pY), size: MKMapSize(width: width, height: height))
        let edgePadding = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        self.mapView.setVisibleMapRect(zoomMapRect, edgePadding: edgePadding, animated: animated)
    }

    //------------------------------------------------------------------------------------------
    // MARK: - User Action (Public)

    func displayJourney(zones: Set<String>? = nil, locations: [LocationAnnotation]? = nil, route: [CLLocationCoordinate2D]? = nil) {

        self.tapZoneLock = true

        if let zones = zones {
            self.changeZonesFillColors(zones: zones, state: .select)
            self.selectedZones = self.selectedZones.union(zones)
        }
        if let locations = locations {
            self.locationAnnotations += locations
        }
        if let route = route {
            let polyline = MKPolyline(coordinates: route, count: route.count)
            self.routes += [polyline]
        }
    }

    func selectRoute(routeIndex: Int) {

        guard routeIndex < self.routes.count else {return}
        self.selectedRouteIndex = routeIndex
        self.highlightRoute(routeIndex: routeIndex)
    }

    func highlightOnlyZones(zones: Set<String>, animated: Bool) {

        let deselectZones = self.selectedZones.subtracting(zones)
        let highlightZones = zones.subtracting(self.selectedZones)
        self.selectedZones = zones
        self.changeZonesFillColors(zones: deselectZones, state: .deselect)
        self.changeZonesFillColors(zones: highlightZones, state: .select)

        self.zoomIntoSelectedZone(animated: animated)
    }

    func highlightOnlyRoutes(routes: [[CLLocationCoordinate2D]]?) {

        self.mapView.removeOverlays(self.routes)
        self.routes.removeAll()
        self.higlightRouteIndices.removeAll()

        guard let routes = routes, routes.isEmpty == false else {return}
        let polylines = routes.map { MKPolyline(coordinates: $0, count: $0.count)}
        _ = polylines.enumerated().map {$1.title = String($0)}
        self.routes += polylines
        let highlightRoutes = Set(0...(self.routes.count-1))
        self.higlightRouteIndices = self.higlightRouteIndices.union(highlightRoutes)
        self.mapView.addOverlays(polylines, level: .aboveLabels)
    }

    func showNeighbourZone(hidden: Bool = false) {

        guard self.selectedZones.isEmpty == false else {return}
        if hidden == false &&  self.isSelectedZonesReachMaxLimit() == true {
            self.isNeighbourZoneHidden = true
            return
        }
        var neighbourZone = Set(self.selectedZones.compactMap {self.zoneData[$0]?.neighbourZones}.flatMap {$0})
        self.neighbourZones = neighbourZone
        neighbourZone.subtract(self.selectedZones)
        let highlightState: ZonePolygonHighlightState = (hidden == false) ? .neighbour : .deselect
        self.changeZonesFillColors(zones: neighbourZone, state: highlightState)
        self.isNeighbourZoneHidden = hidden
    }

    func zoomIntoRegion(location: CLLocationCoordinate2D, span: MKCoordinateSpan, animated: Bool = true) -> MKCoordinateRegion {
        let region = MKCoordinateRegion(center: location, span: span)
        self.mapView.setRegion(region, animated: animated)
        self.defaultRegion = region
        return region
    }

    func zoomIntoRegion(region: MKCoordinateRegion, animated: Bool = true) {
        self.mapView.setRegion(region, animated: animated)
        self.defaultRegion = region
    }

    //------------------------------------------------------------------------------------------
    // MARK: - User Action (Private)

    @objc private func handleMapTap(tap: UIGestureRecognizer) {

        let tapPoint = tap.location(in: self.mapView)
        let tapCoordinate = self.mapView.convert(tapPoint, toCoordinateFrom: self.mapView)
        let tapMapPoint = MKMapPoint(tapCoordinate)

        if tapZoneLock == false {
            self.tapZone(tapMapPoint: tapMapPoint)
        } else {
            self.tapRoute(tapMapPoint: tapMapPoint)
        }
    }

    private func tapRoute(tapMapPoint: MKMapPoint) {

        guard self.routes.isEmpty == false else {return}

        var nearestDistance = Double(MAXFLOAT)
        var routeIndex = -1

        for (index, route) in self.routes.enumerated() {
            let distance = distanceToRoute(point: tapMapPoint, route: route)
            if distance < nearestDistance {
                nearestDistance = distance
                routeIndex = index
            }
        }

        let maxDistance: Double = 5000
        guard nearestDistance <= maxDistance && routeIndex >= 0 else {return}

        if self.delegate?.shoudSelectRoute(index: routeIndex) == true {
            self.selectedRouteIndex = routeIndex
            self.highlightRoute(routeIndex: routeIndex)
        }
    }

    private func distanceToRoute(point: MKMapPoint, route: MKPolyline) -> Double {

        var distance = Double(MAXFLOAT)
        var routePoints = [MKMapPoint]()
        let routePointCount = route.pointCount

        for point in UnsafeBufferPointer(start: route.points(), count: routePointCount) {
            routePoints.append(point)
        }

        for (index, routePoint) in routePoints.enumerated() {

            guard index <= (routePointCount-2) else {break}

            let rA = routePoint // swiftlint:disable:this identifier_name
            let rB = routePoints[index+1]  // swiftlint:disable:this identifier_name
            let xDelta = rB.x - rA.x
            let yDelta = rB.y - rA.y
            if xDelta == 0.0 && yDelta == 0.0 { // Points must not be equal
                continue
            }

            // swiftlint:disable:next identifier_name
            let u: Double = ((point.x - rA.x) * xDelta + (point.y - rA.y) * yDelta) / (xDelta * xDelta + yDelta * yDelta)
            var ptClosest = MKMapPoint()

            if u < 0.0 {
                ptClosest = rA
            } else if u > 1.0 {
                ptClosest = rB
            } else {
                ptClosest = MKMapPoint(x: rA.x + u * xDelta, y: rA.y + u * yDelta)
            }
            distance = min(distance, ptClosest.distance(to: point))
        }
        return distance
    }

    private enum ZoneAction {
        case selected
        case deselected
        case invalid
        case reachMaxLimit
    }

    private func tapOnZone(zoneNumber: String) -> ZoneAction {

        var zoneAction = ZoneAction.invalid
        if selectedZones.contains(zoneNumber) {
            guard self.isSelectedZonesConnectedAfterRemoval(removalZone: zoneNumber) == true else {return .invalid}
            selectedZones.remove(zoneNumber)
            zoneAction = .deselected
        } else if self.isSelectedZonesReachMaxLimit() == true {
            return .reachMaxLimit
        } else if selectedZones.isEmpty == true || self.neighbourZones.contains(zoneNumber) {
            selectedZones.insert(zoneNumber)
            zoneAction = .selected
        }
        return zoneAction
    }

    private func tapZone(tapMapPoint: MKMapPoint) {

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
            case .invalid:
                self.delegate?.selectedZoneIsNotConnected()
            case .reachMaxLimit:
                self.delegate?.exceedMaxSelectedZoneLimit()
            }

            if action != .invalid {
                self.delegate?.selectedZones(zones: self.selectedZones)
            }

            self.updateNeighbourZone(tapZoneNumber: zoneNumber, action: action)

            return true
        }
    }

    private func findNewNeighbourZones(zones: Set<String>) -> Set<String> {

        var newNeighbourZones = Set(zones)
        newNeighbourZones = newNeighbourZones.subtracting(self.neighbourZones)
        newNeighbourZones = newNeighbourZones.subtracting(self.selectedZones)
        self.neighbourZones = self.neighbourZones.union(zones)
        return newNeighbourZones
    }

    private func findNeighbourZonesToRemove(tapZone: String, zones: Set<String>) -> Set<String> {

        var removeNeighbourZones = Set(zones)
        removeNeighbourZones = removeNeighbourZones.subtracting(self.selectedZones)
        for selectedZone in self.selectedZones {
            guard tapZone != selectedZone, let neighbourZones = self.zoneData[selectedZone]?.neighbourZones else {continue}
            removeNeighbourZones = removeNeighbourZones.subtracting(neighbourZones)
        }
        self.neighbourZones = self.neighbourZones.subtracting(removeNeighbourZones)
        return removeNeighbourZones
    }

    private func updateNeighbourZone(tapZoneNumber: String, action: ZoneAction) {

        guard action != .invalid else {return}

        if self.isSelectedZonesReachMaxLimit() == true {
            self.showNeighbourZone(hidden: true)
            return
        } else if self.isNeighbourZoneHidden == true {
            self.showNeighbourZone()
        }

        if let zones = self.zoneData[tapZoneNumber]?.neighbourZones {

            var addZones = Set<String>()
            var removeZones = Set<String>()

            switch action {
            case .selected:
                addZones = self.findNewNeighbourZones(zones: zones)
            case .deselected:
                removeZones =  self.findNeighbourZonesToRemove(tapZone: tapZoneNumber, zones: zones)
                if self.neighbourZones.contains(tapZoneNumber) && self.neighbourZones.count > 1 {
                    addZones = [tapZoneNumber]
                }
            default:
                break
            }

            guard (addZones.count + removeZones.count) != 0 else {return}
            changeZonesFillColors(zones: addZones, state: .neighbour)
            changeZonesFillColors(zones: removeZones, state: .deselect)
        }
    }

    private func isSelectedZonesConnectedAfterRemoval(removalZone: String) -> Bool {

        var selectedZonesAfterRemoval = Set(self.selectedZones)
        selectedZonesAfterRemoval.remove(removalZone)
        guard selectedZonesAfterRemoval.count > 1 else {return true}

        var connectedZones = Set<String>()

        func findConnectedZones(zoneNumber: String) {
            var nearbySelectedZones = self.zoneData[zoneNumber]?.neighbourZones.intersection(selectedZonesAfterRemoval) ?? Set<String>()
            nearbySelectedZones.subtract(connectedZones)
            connectedZones = connectedZones.union(nearbySelectedZones)
            _ = nearbySelectedZones.map {findConnectedZones(zoneNumber: $0)}
        }

        guard let randomSelectedZone = selectedZonesAfterRemoval.first else {return false}
        findConnectedZones(zoneNumber: randomSelectedZone)

        return (connectedZones.count == selectedZonesAfterRemoval.count)
    }

    private func isSelectedZonesReachMaxLimit() -> Bool {
        guard let maxLimit = maxSelectedZoneLimit else {return false}
        return (selectedZones.count >= maxLimit)
    }

    //------------------------------------------------------------------------------------------
    // MARK: - Map Help Function

    class func convertMapRegionToMapRect(region: MKCoordinateRegion) -> MKMapRect {

        let centerLat = region.center.latitude
        let centerLon = region.center.longitude
        let deltaLat = region.span.latitudeDelta
        let deltaLon = region.span.longitudeDelta

        let pointALat = centerLat + deltaLat/2
        let pointALon = centerLon - deltaLon/2
        // swiftlint:disable:next identifier_name
        let a = MKMapPoint(CLLocationCoordinate2D(latitude: pointALat, longitude: pointALon))

        let pointBLat = centerLat - deltaLat/2
        let pointBLon = centerLon + deltaLon/2
        // swiftlint:disable:next identifier_name
        let b = MKMapPoint(CLLocationCoordinate2D(latitude: pointBLat, longitude: pointBLon))

        return MKMapRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x-b.x), height: abs(a.y-b.y))
    }

    class func isCoordinateInsideRegion(coordinate: CLLocationCoordinate2D, region: MKCoordinateRegion) -> Bool {

        let mapPoint = MKMapPoint(coordinate)
        let mapRect = MapViewController.convertMapRegionToMapRect(region: region)
        return (mapRect.contains(mapPoint))
    }

    //------------------------------------------------------------------------------------------
    // MARK: - MapView Function

    private var areaOverlay: MKOverlay?
    private var isAdjustingMapRectInProgress = false

    private func limitedVisibleAreaToBoundingRegion() {

        if self.areaOverlay == nil, let region = self.areaBoundingRegion {
            let mapRect = MapViewController.convertMapRegionToMapRect(region: region)
            let circle = MKCircle(mapRect: mapRect)
            self.areaOverlay = circle
            if showBoundingRegion == true {
                self.mapView.insertOverlay(circle, at: 0, level: .aboveLabels)
            }
        }

        guard let area = self.areaOverlay else {return}
        let isInsideAreaBoundingMapRect = self.mapView.visibleMapRect.contains(area.boundingMapRect)

        if isInsideAreaBoundingMapRect == true {

            // Is entirely inside the map view but adjust if user is zoomed out too much...
            let widthRatio = area.boundingMapRect.size.width / self.mapView.visibleMapRect.size.width
            let heightRatio = area.boundingMapRect.size.height / self.mapView.visibleMapRect.size.height

            let ratio = 0.8
            if (widthRatio < ratio) || (heightRatio < ratio) {
                self.isAdjustingMapRectInProgress = true
                self.mapView.setVisibleMapRect(area.boundingMapRect, animated: true)
                self.isAdjustingMapRectInProgress = false
            }

        } else if area.intersects!(self.mapView.visibleMapRect) == false { // swiftlint:disable:this force_unwrapping

            // Is no longer visible in the map view.
            // Reset to bounding map rect
            self.isAdjustingMapRectInProgress = true
            self.mapView.setVisibleMapRect(area.boundingMapRect, animated: true)
            self.isAdjustingMapRectInProgress = false
        }
    }

    //------------------------------------------------------------------------------------------
    // MARK: - Configure annotation

    private func configureZoneNumberAnnotation(mapView: MKMapView, zoneAnnotation: ZoneAnnotation) -> MKAnnotationView {

        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: zoneAnnotation.identifier) ??
            MKAnnotationView(annotation: zoneAnnotation, reuseIdentifier: zoneAnnotation.identifier)
        annotationView.annotation = zoneAnnotation
        annotationView.isHidden = (mapView.region.span.latitudeDelta > self.hiddenZoneAnnotationDelta)

        if let zoneNumberLabel = annotationView.viewWithTag(self.zoneLabelTag) as? UILabel {
            zoneNumberLabel.text = zoneAnnotation.title ?? ""
        } else {

            let centerLabel: (CGFloat) -> CGRect = { size in
                let point = -size/2
                return CGRect(x: point, y: point, width: size, height: size)
            }

            let zoneNumberLabel = UILabel(frame: centerLabel(self.zoneLabelSize))
            zoneNumberLabel.textAlignment = .center
            zoneNumberLabel.textColor = self.zoneLabelTextColor
            zoneNumberLabel.font = UIFont.boldSystemFont(ofSize: 10)
            zoneNumberLabel.text = zoneAnnotation.title ?? ""
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
    }

    private func configureLocationAnnotation(mapView: MKMapView, locationAnnotation: LocationAnnotation) -> MKAnnotationView {

        let newAnnotationView: () -> MKAnnotationView = {
            if locationAnnotation.imageName != nil {
                return MKAnnotationView(annotation: locationAnnotation, reuseIdentifier: locationAnnotation.identifier)
            } else {
                return MKPinAnnotationView(annotation: locationAnnotation, reuseIdentifier: locationAnnotation.identifier)
            }
        }
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: locationAnnotation.identifier) ?? newAnnotationView()
        annotationView.annotation = locationAnnotation
        annotationView.canShowCallout = true
        if let imageName = locationAnnotation.imageName {
            let image = UIImage(named: imageName)
            annotationView.image = image
            let y = (image?.size.height ?? 0) / 2 // swiftlint:disable:this identifier_name
            annotationView.centerOffset = CGPoint(x: 0, y: -y)
        }
        self.autoShowAnnotationCallout(mapView: mapView, locationAnnotation: locationAnnotation)
        return annotationView
    }

    private func autoShowAnnotationCallout(mapView: MKMapView, locationAnnotation: LocationAnnotation) {

        guard let calloutDelay = locationAnnotation.showCalloutDelay, let calloutDuration = locationAnnotation.showCalloutDuration else {return}

        let showCalloutTime: DispatchTime = .now() + DispatchTimeInterval.milliseconds(Int(calloutDelay*1000)) + 0.1
        let hideCalloutTime  = showCalloutTime + DispatchTimeInterval.milliseconds(Int(calloutDuration*1000))

        let showCallout: (DispatchTime) -> Void = { time in
            DispatchQueue.main.asyncAfter(deadline: time) {
                mapView.selectAnnotation(locationAnnotation, animated: true)
            }
        }

        let hideCallout: (DispatchTime) -> Void = { time in
            let selectedAnnotation = mapView.selectedAnnotations.first as? LocationAnnotation
            if selectedAnnotation != locationAnnotation {
                DispatchQueue.main.asyncAfter(deadline: time) {
                    mapView.deselectAnnotation(locationAnnotation, animated: true)
                }
            }
        }
        showCallout(showCalloutTime)
        hideCallout(hideCalloutTime)
    }

    //------------------------------------------------------------------------------------------
    // MARK: - MapView Delegate

    private let hiddenZoneAnnotationDelta = 0.55

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {

        if let polygon = overlay as? MKPolygon {

            let render = MKPolygonRenderer(polygon: polygon)
            render.strokeColor = self.zonePolygonBorderPathColor
            render.lineWidth = 1
            render.fillColor = self.polygonFillColor(zoneNumber: polygon.title)
            return render

        } else if let polyline = overlay as? MKPolyline {

            let render = MKPolylineRenderer(overlay: polyline)
            render.lineWidth = 2.5

            if let title = polyline.title, let routeIndex = Int(title) {
                let isSelectedRoute = (routeIndex == self.selectedRouteIndex)
                let isHighlightedRoute =  (self.higlightRouteIndices.contains(routeIndex))
                render.strokeColor = (isSelectedRoute == true || isHighlightedRoute == true) ? self.routeSelectedLineColor : self.routeLineColor
            }
            return render
        } else if let circle = overlay as? MKCircle {
            let render = MKCircleRenderer(circle: circle)
            render.fillColor = self.boundingRegionColor
            return render
        }
        return  MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {

        if annotation is MKUserLocation {
            return nil
        }

        if let zoneAnnotation = annotation as? ZoneAnnotation {
            return self.configureZoneNumberAnnotation(mapView: mapView, zoneAnnotation: zoneAnnotation)
        } else if let locationAnnotation = annotation as? LocationAnnotation {
            return self.configureLocationAnnotation(mapView: mapView, locationAnnotation: locationAnnotation)
        }
        return nil
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {

        if self.mapView.annotations.isEmpty == false {
            let latitudeDelta = mapView.region.span.latitudeDelta
            let hidden = latitudeDelta > self.hiddenZoneAnnotationDelta

            for annotation in self.mapView.annotations {
                guard annotation is ZoneAnnotation else {continue}
                let annotationView = self.mapView.view(for: annotation)
                annotationView?.isHidden = hidden
            }
        }

        if self.areaBoundingRegion != nil {
            guard self.isAdjustingMapRectInProgress == false else {return}
            self.limitedVisibleAreaToBoundingRegion()
        }
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {

    }

    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {

    }
}
