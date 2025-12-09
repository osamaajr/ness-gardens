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

    // beds data
    func fetchBeds(completion: @escaping ([Bed]) -> Void) {
        guard let url = URL(string: "\(baseURL)?class=beds") else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data else {
                print("No beds data:", error ?? "unknown error")
                completion([])
                return
            }

            do {
                struct Root: Codable { let beds: [Bed] }
                let root = try JSONDecoder().decode(Root.self, from: data)
                completion(root.beds)
            } catch {
                print("Beds decode error:", error)
                completion([])
            }
        }.resume()
    }
    
    // plants data
    func fetchPlants(completion: @escaping ([Plant]) -> Void) {
        guard let url = URL(string: "\(baseURL)?class=plants") else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data else {
                print("No plants data:", error ?? "unknown error")
                completion([])
                return
            }

            do {
                struct Root: Codable { let plants: [Plant] }
                let decoded = try JSONDecoder().decode(Root.self, from: data)
                completion(decoded.plants)
            } catch {
                print("Plants decode error:", error)
                completion([])
            }
        }.resume()
    }
    
    // images list
    func fetchImages(completion: @escaping ([ImageInfo]) -> Void) {
        guard let url = URL(string: "\(baseURL)?class=images") else { return }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data else {
                print("No images data:", error ?? "unknown error")
                completion([])
                return
            }

            do {
                struct Root: Codable { let images: [ImageInfo] }
                let decoded = try JSONDecoder().decode(Root.self, from: data)
                completion(decoded.images)
            } catch {
                print("Images decode error:", error)
                completion([])
            }
        }.resume()
    }
    
    // trails meta
    func fetchTrails(completion: @escaping ([Trail]) -> Void) {
        guard let url = URL(string: "\(baseURL)?class=trails") else { return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            
            struct Root: Codable { let trails: [Trail] }
            let decoded = try? JSONDecoder().decode(Root.self, from: data)
            completion(decoded?.trails ?? [])
        }.resume()
    }

    // each trail's coordinates
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
