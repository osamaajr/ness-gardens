//
//  NetworkManager.swift
//  NessGardens
//
//  Created by Osama Alnajar on 04/12/2025.
//

import Foundation

class NetworkManager {
    
    static let shared = NetworkManager()
    private init() {}

    private let baseURL = "https://cgi.csc.liv.ac.uk/~phil/Teaching/COMP228/ness/data.php"

    func fetchBeds(completion: @escaping ([Bed]) -> Void) {
        guard let url = URL(string: "\(baseURL)?class=beds") else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            let beds = try? JSONDecoder().decode([Bed].self, from: data)
            completion(beds ?? [])
        }.resume()
    }

    func fetchPlants(completion: @escaping ([Plant]) -> Void) {
        guard let url = URL(string: "\(baseURL)?class=plants") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            let plants = try? JSONDecoder().decode([Plant].self, from: data)
            completion(plants ?? [])
        }.resume()
    }

    func fetchImages(completion: @escaping ([ImageInfo]) -> Void) {
        guard let url = URL(string: "\(baseURL)?class=images") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            let imgs = try? JSONDecoder().decode([ImageInfo].self, from: data)
            completion(imgs ?? [])
        }.resume()
    }
    
    func fetchTrails(completion: @escaping ([Trail]) -> Void) {
        guard let url = URL(string: "\(baseURL)?class=trails") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            
            struct Root: Codable { let trails: [Trail] }
            let decoded = try? JSONDecoder().decode(Root.self, from: data)
            completion(decoded?.trails ?? [])
        }.resume()
    }


    func fetchTrailLocations(completion: @escaping ([TrailLocation]) -> Void) {
        guard let url = URL(string: "\(baseURL)?class=trail_locations") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }

            struct Root: Codable { let trail_locations: [TrailLocation] }
            let decoded = try? JSONDecoder().decode(Root.self, from: data)
            completion(decoded?.trail_locations ?? [])
        }.resume()
    }
}
