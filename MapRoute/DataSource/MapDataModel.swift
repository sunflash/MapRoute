//
//  MapDataModel.swift
//  MapRoute
//
//  Created by Min Wu on 30/12/2016.
//  Copyright © 2016 CellPointMobile. All rights reserved.
//

import Foundation
import MapKit
import RealmSwift
import SwiftyJSON

class Coordinate: Object {
    @objc dynamic var latitude: Double = 0
    @objc dynamic var longitude: Double = 0
}

class ZoneInfo: Object {

    @objc dynamic var zoneName = ""
    @objc dynamic var zoneNumber = ""
    @objc dynamic var neighbourZones = ""
    @objc dynamic var center: Coordinate?
    let polygonCoordinates = List<Coordinate>()

    override static func primaryKey() -> String? {
        return "zoneNumber"
    }
}

class MapDataModel: MapViewControllerDataSource {

    static let sharedDataModel = MapDataModel()
    static private let realmFileName = "ZoneInfos"
    static private let jsonFileName = "ZealandZones"

    func zoneData(completion: @escaping ([String: FareZone], [MKPolygon], [ZoneAnnotation]) -> Void) {

        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {

            let realmFileURL = Bundle.main.url(forResource: MapDataModel.realmFileName, withExtension: "realm")
            let config = Realm.Configuration(fileURL: realmFileURL, readOnly: true)
            guard let realm = try? Realm(configuration: config) else {return}

            let zoneInfos = realm.objects(ZoneInfo.self)

            var zoneData = [String: FareZone]()
            var zonePolygons = [MKPolygon]()
            var zoneAnnotations = [ZoneAnnotation]()

            let polygon: (List<Coordinate>) -> MKPolygon? = { coordinates in
                var points = [CLLocationCoordinate2D]()
                points += coordinates.compactMap {CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)}
                guard points.isEmpty == false else {return nil}
                return MKPolygon(coordinates: &points, count: points.count)
            }

            for zoneInfo in zoneInfos {

                guard let centerLat = zoneInfo.center?.latitude, let centerLon = zoneInfo.center?.longitude else {continue}
                guard let polygon = polygon(zoneInfo.polygonCoordinates) else {continue}

                let name = zoneInfo.zoneName
                let zoneNumber = zoneInfo.zoneNumber
                let neighbourZones = zoneInfo.neighbourZones.components(separatedBy: ",")
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

private typealias ConvertMapData = MapDataModel
extension ConvertMapData {

    class func convertZoneJsonToRealm() { // swiftlint:disable:this cyclomatic_complexity

        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {

            let fileURL = Bundle.main.url(forResource: jsonFileName, withExtension: "json")
            guard let url = fileURL else {return}
            let jsonData = try? Data(contentsOf: url)
            guard let data = jsonData else {return}
            guard let zealand = try? JSON(data: data) else {return}

            let documentURL = URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
            let realmFileURL = documentURL.appendingPathComponent("\(self.realmFileName).realm")
            guard let realm = try? Realm(fileURL: realmFileURL) else {return}
            print("!! \(documentURL)")

            let polygon: (JSON) -> [Coordinate]? = { coordinates in

                var points = [Coordinate]()
                for (_, coordinateO) in coordinates {
                    guard let coordinate = coordinateO.array, let latitude = coordinate[1].double, let longitude = coordinate[0].double else {continue}
                    let point = Coordinate()
                    point.latitude = latitude
                    point.longitude = longitude
                    points += [point]
                }
                guard points.isEmpty == false else {return nil}
                return points
            }

            realm.beginWrite()

            for (_, zoneInfo) in zealand["features"] {

                guard let geometryType = zoneInfo["geometry", "type"].string, geometryType == "Polygon", let polygonCoordinates = polygon(zoneInfo["geometry", "coordinates"][0]) else {continue}

                let nameO = zoneInfo["properties", "Name"].string
                let zoneNumberO = zoneInfo["properties", "Shortname"].string
                // swiftlint:disable:next force_unwrapping
                let neighbourZonesO = zoneInfo["properties", "NeighbourZones"].string?.components(separatedBy: ",").filter {Int($0) != nil}.map {String(Int($0)!-1000)}
                let centerCoordinateO = zoneInfo["properties", "PolygonCentroid"].string?.components(separatedBy: ",")
                guard let name = nameO, let zoneNumber = zoneNumberO, let neighbourZones = neighbourZonesO else {continue}
                guard let centerCoordinate = centerCoordinateO, let centerLat = Double(centerCoordinate[1]), let centerLon = Double(centerCoordinate[0]) else {continue}
                let center = Coordinate()
                center.latitude = centerLat
                center.longitude = centerLon

                let zoneData = ZoneInfo()
                zoneData.zoneName = name
                zoneData.zoneNumber = zoneNumber
                zoneData.neighbourZones = neighbourZones.joined(separator: ",")
                zoneData.center = center
                polygonCoordinates.forEach {zoneData.polygonCoordinates.append($0)}

                realm.add(zoneData, update: true)
            }

            try? realm.commitWrite()
        }
    }
}
