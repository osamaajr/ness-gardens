//
//  PlantDetailViewController.swift
//  NessGardens
//
//  Created by Osama Alnajar on 04/12/2025.
//

import UIKit
import MapKit

class PlantDetailViewController: UIViewController {

    @IBOutlet weak var mainImageView: UIImageView!
    @IBOutlet weak var infoTextView: UITextView!
    @IBOutlet weak var originMapView: MKMapView!
    
    var plant: Plant?
    var images: [ImageInfo] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        // load all UI data
        loadPlantDetails()
    }

    func loadPlantDetails() {

        // return nothing if theres no plant
        guard let plant = plant else { return }

        var info = ""
        info += "Genus: \(plant.genus)\n"
        info += "Species: \(plant.species)\n"
        info += "Common name: \(plant.vernacular_name ?? "None")\n"
        info += "Cultivar: \(plant.cultivar_name ?? "None")\n"
        info += "Beds: \(plant.bed)\n"

        infoTextView.text = info

        // Load first plant image
        if let first = images.first {
            let urlStr = "https://cgi.csc.liv.ac.uk/~phil/Teaching/COMP228/ness_images/\(first.filename)"
            if let url = URL(string: urlStr) {

                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data {
                        DispatchQueue.main.async {
                            self.mainImageView.image = UIImage(data: data)
                        }
                    }
                }.resume()
            }
        }

        // Show map if coordinates available
        if let latStr = plant.latitude,
           let lonStr = plant.longitude,
           let lat = Double(latStr),
           let lon = Double(lonStr) {

            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)

            // zoom out enough to show general origin
            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 50000,
                longitudinalMeters: 50000
            )

            originMapView.setRegion(region, animated: false)

            // add pin
            let pin = MKPointAnnotation()
            pin.coordinate = coordinate
            pin.title = "Plant Origin"
            originMapView.addAnnotation(pin)

        } else {
            // hide map if no coords
            originMapView.isHidden = true
        }
    }
}

