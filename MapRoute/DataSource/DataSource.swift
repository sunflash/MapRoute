//
//  DataSource.swift
//  MapRoute
//
//  Created by Min Wu on 02/09/16.
//  Copyright © 2016 CellPointMobile. All rights reserved.
//

import Foundation
import MapKit

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
}

class DataSource {
    
    static let sharedDataSource = DataSource()
    
    func zoneData(completion: @escaping ([String:FareZone],[MKPolygon],[ZoneAnnotation])->Void)   {
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.userInitiated).async {
        
            let fileURL = Bundle.main.url(forResource: "ZealandZones", withExtension: "json")
            guard let url = fileURL else {return}
            let jsonData = try? Data(contentsOf: url)
            guard let data = jsonData else {return}
            let zealand = JSON(data: data)
            
            let polygon: (JSON) -> MKPolygon? =  { coordinates in
                
                var points = [CLLocationCoordinate2D]()
                for (_, coordinateO) in coordinates {
                    guard let coordinate = coordinateO.array, let latitude = coordinate[1].double, let longitude = coordinate[0].double else {continue}
                    points += [CLLocationCoordinate2D(latitude: latitude, longitude: longitude)]
                }
                guard points.count != 0 else {return nil}
                return MKPolygon(coordinates: &points, count: points.count)
            }
            
            var zoneData = [String:FareZone]()
            var zonePolygons = [MKPolygon]()
            var zoneAnnotations = [ZoneAnnotation]()
            
            for (_, zoneInfo) in zealand["features"] {
                
                guard let geometryType = zoneInfo["geometry","type"].string, geometryType == "Polygon", let polygon = polygon(zoneInfo["geometry","coordinates"][0]) else {continue}
                
                let nameO = zoneInfo["properties","Name"].string
                let zoneNumberO = zoneInfo["properties","Shortname"].string
                let neighbourZonesO = zoneInfo["properties","NeighbourZones"].string?.components(separatedBy: ",").filter{Int($0) != nil}.map{String(Int($0)!-1000)}
                let centerCoordinateO = zoneInfo["properties","PolygonCentroid"].string?.components(separatedBy: ",")
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
            
            completion(zoneData,zonePolygons,zoneAnnotations)
       }
    }
    
    class func highLightZonesInfo() -> (zones:Set<String>,locations:[LocationAnnotation])  {
    
        let highlightZones = Set(["1","2","32","43","54","66","76","8","96","97","28","27","140","141",
                                    "269","262","263","275","277","26","22","20","99","89","77","67","33","44","55","260"])
        
        let jouneyBegin = LocationAnnotation()
        jouneyBegin.coordinate = CLLocationCoordinate2DMake( 55.683729, 12.590080)
        jouneyBegin.title = "København, Frederiksberg, City"
        jouneyBegin.subtitle = "Bredgade 36, 1260 København K"
        
        let jouneyEnd = LocationAnnotation()
        jouneyEnd.coordinate = CLLocationCoordinate2DMake(55.215841, 11.812547)
        jouneyEnd.title = "Næstved"
        jouneyEnd.subtitle = "Bystævnet 8, Rønnebæk, 4700 Næstved"
    
        return(highlightZones,[jouneyBegin,jouneyEnd])
    }
}
