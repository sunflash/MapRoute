//
//  MapDataSource.swift
//  MapRoute
//
//  Created by Min Wu on 02/09/16.
//  Copyright © 2016 CellPointMobile. All rights reserved.
//

import Foundation
import MapKit
import SwiftyJSON

class MapDataSource: MapViewControllerDataSource {

    static let sharedDataSource = MapDataSource()

    func zoneData(completion: @escaping ([String: FareZone], [MKPolygon], [ZoneAnnotation]) -> Void) {

        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {

            let fileURL = Bundle.main.url(forResource: "ZealandZones", withExtension: "json")
            guard let url = fileURL else {return}
            let jsonData = try? Data(contentsOf: url)
            guard let data = jsonData else {return}
            guard let zealand = try? JSON(data: data) else {return}

            let polygon: (JSON) -> MKPolygon? = { coordinates in

                var points = [CLLocationCoordinate2D]()
                for (_, coordinateO) in coordinates {
                    guard let coordinate = coordinateO.array, let latitude = coordinate[1].double, let longitude = coordinate[0].double else {continue}
                    points += [CLLocationCoordinate2D(latitude: latitude, longitude: longitude)]
                }
                guard points.isEmpty == false else {return nil}
                return MKPolygon(coordinates: &points, count: points.count)
            }

            var zoneData = [String: FareZone]()
            var zonePolygons = [MKPolygon]()
            var zoneAnnotations = [ZoneAnnotation]()

            for (_, zoneInfo) in zealand["features"] {

                guard let geometryType = zoneInfo["geometry", "type"].string,
                    geometryType == "Polygon",
                    let polygon = polygon(zoneInfo["geometry", "coordinates"][0]) else {continue}

                let nameO = zoneInfo["properties", "Name"].string
                let zoneNumberO = zoneInfo["properties", "Shortname"].string
                // swiftlint:disable:next force_unwrapping
                let neighbourZonesO = zoneInfo["properties", "NeighbourZones"].string?.components(separatedBy: ",").filter {Int($0) != nil}.map {String(Int($0)!-1000)}
                let centerCoordinateO = zoneInfo["properties", "PolygonCentroid"].string?.components(separatedBy: ",")
                guard let name = nameO, let zoneNumber = zoneNumberO, let neighbourZones = neighbourZonesO else {continue}
                guard let centerCoordinate = centerCoordinateO, let centerLat = Double(centerCoordinate[1]), let centerLon = Double(centerCoordinate[0]) else {continue}
                let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)

                let annotation = ZoneAnnotation()
                annotation.coordinate = center
                annotation.title = zoneNumber
                zoneAnnotations += [annotation]

                polygon.title = zoneNumber
                zonePolygons += [polygon]

                let zone = FareZone(name: name, zoneNumber: zoneNumber, neighbourZones: Set(neighbourZones), centerCoordinate: center, polygon: polygon)
                zoneData[zoneNumber] = zone
            }

//            zoneData.flatMap{$0.value}.sorted{$0.0.zoneNumber.localizedStandardCompare($0.1.zoneNumber) == .orderedAscending}.forEach{ zone in
//                print("\(zone.zoneNumber) \(zone.name)")
//            }

            completion(zoneData, zonePolygons, zoneAnnotations)
        }
    }
}
