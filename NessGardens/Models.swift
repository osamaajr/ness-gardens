//
//  Models.swift
//  NessGardens
//
//  Created by Osama Alnajar on 04/12/2025.
//

import Foundation
import CoreLocation


struct Bed: Codable {
    let recnum: String
    let short_name: String
    let full_name: String
    let latitude: String
    let longitude: String

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = Double(latitude),
              let lon = Double(longitude) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}


struct Plant: Codable {
    let recnum: String
    let accsta: String
    let genus: String
    let species: String
    let infraspecific_epithet: String?
    let vernacular_name: String?
    let cultivar_name: String?
    let bed: String
    let latitude: String?
    let longitude: String?
}


struct ImageInfo: Codable {
    let recnum: String
    let plant_recnum: String
    let filename: String
}


struct Trail: Codable {
    let id: String
    let trail_name: String
    let distance: String?
    let duration: String?
    let trail_description: String?
    let difficulty: String?
    let active: String?

    var name: String { trail_name }

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case trail_name = "Trail_Name"
        case distance = "Distance"
        case duration = "Duration"
        case trail_description = "Description"
        case difficulty = "Difficulty"
        case active = "Active"
    }
}



struct TrailLocation: Codable {
    let id: String
    let trail_id: String
    let sequence_no: String
    let latitude: String
    let longitude: String
    let active: String

    enum CodingKeys: String, CodingKey {
        case id = "ID"
        case trail_id = "Trail_ID"
        case sequence_no = "Sequence_No"
        case latitude = "Latitude"
        case longitude = "Longitude"
        case active = "Active"
    }
}
