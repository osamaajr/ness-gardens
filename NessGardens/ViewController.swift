//
//  ViewController.swift
//  NessGardens
//
//  Created by Osama Alnajar on 03/12/2025.
//

import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController, MKMapViewDelegate {

    // MARK: - Outlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var chooseTrailButton: UIButton!
    var bedLookup: [String: Bed] = [:]
    var firstRun = true
    var startTrackingTheUser = false

    @IBAction func chooseTrailTapped(_ sender: Any) {
        showTrailList()
    }    
    
    // MARK: - Location
    let locationManager = CLLocationManager()

    @objc func startUserTracking() {
        // Called by a timer after a short delay
        startTrackingTheUser = true
    }
    
    // MARK: - trails
    func showTrailList() {
        print("Trails available:", trails.map { $0.name })
        
        let alert = UIAlertController(title: "Choose a Trail",
                                      message: nil,
                                      preferredStyle: .actionSheet)
        
        for trail in trails {
            alert.addAction(UIAlertAction(title: trail.name, style: .default, handler: { _ in
                self.displayTrail(trail)
            }))
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    func displayTrail(_ trail: Trail) {

        mapView.removeOverlays(mapView.overlays)

        let coords = trailLocations
            .filter { $0.trail_id == trail.id }
            .compactMap { loc -> CLLocationCoordinate2D? in
                if let lat = Double(loc.latitude),
                   let lon = Double(loc.longitude) {
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
                return nil
            }

        let polyline = MKPolyline(coordinates: coords, count: coords.count)
        mapView.addOverlay(polyline)

        if let first = coords.first {
            let region = MKCoordinateRegion(
                center: first,
                latitudinalMeters: 300,
                longitudinalMeters: 300
            )
            mapView.setRegion(region, animated: true)
        }
    }

    
    func mapView(_ mapView: MKMapView,
                 rendererFor overlay: MKOverlay) -> MKOverlayRenderer {

        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemGreen
            renderer.lineWidth = 4
            return renderer
        }
        return MKOverlayRenderer()
    }



    // MARK: - Data
    var beds: [Bed] = []
    var plantsByBed: [String: [Plant]] = [:]
    var bedOrder: [String] = []
    var userLocation: CLLocation?
    var imagesByPlant: [String: [ImageInfo]] = [:]
    var trails: [Trail] = []
    var trailLocations: [TrailLocation] = []



    override func viewDidLoad() {
        super.viewDidLoad()
        
        chooseTrailButton.isEnabled = false

        mapView.mapType = .satellite
        mapView.showsUserLocation = true

        tableView.dataSource = self
        tableView.delegate = self
        mapView.delegate = self

        setupLocation()
        loadData()
    }


    // MARK: - Load API Data
    func loadData() {

        NetworkManager.shared.fetchBeds { beds in
            self.beds = beds
            self.bedLookup = Dictionary(uniqueKeysWithValues:
                beds.flatMap { bed in
                    [(bed.recnum, bed), (bed.short_name, bed)]
                }
            )

            NetworkManager.shared.fetchPlants { plants in
                let alive = plants.filter { $0.accsta == "C" }
                
                var grouped: [String: [Plant]] = [:]

                for plant in alive {
                    let bedList = plant.bed
                        .components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }

                    for bed in bedList {
                        grouped[bed, default: []].append(plant)
                    }
                }

                self.plantsByBed = grouped
                self.bedOrder = Array(grouped.keys)
                self.bedOrder = Array(self.plantsByBed.keys)

                DispatchQueue.main.async {
                    self.tableView.reloadData()
                    self.sortBedsByDistance()
                }

                NetworkManager.shared.fetchImages { images in
                    self.imagesByPlant = Dictionary(grouping: images, by: { $0.plant_recnum })

                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }

                NetworkManager.shared.fetchTrailLocations { locs in
                    self.trailLocations = locs

                    let uniqueIDs = Set(locs.map { $0.trail_id })
                    self.trails = uniqueIDs.map { id in
                        Trail(id: id, trail_name: "Trail \(id)", distance: nil, duration: nil, trail_description: nil, difficulty: nil, active: nil)
                    }

                    DispatchQueue.main.async {
                        print("Trails built:", self.trails.count)
                        self.chooseTrailButton.isEnabled = true
                    }
                }
            }
        }
    }

    // MARK: - Location Setup
    private func setupLocation() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        print("Requesting location permission")
    }
}


// MARK: - Location Delegate
extension ViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {

        guard let location = locations.last else { return }

        userLocation = location
        print("LOCATION UPDATE:", location.coordinate)

        if firstRun {
            firstRun = false

            let span = MKCoordinateSpan(latitudeDelta: 0.0025,
                                        longitudeDelta: 0.0025)

            let region = MKCoordinateRegion(center: location.coordinate,
                                            span: span)

            mapView.setRegion(region, animated: true)

            Timer.scheduledTimer(timeInterval: 5.0,
                                 target: self,
                                 selector: #selector(startUserTracking),
                                 userInfo: nil,
                                 repeats: false)
        }

        if startTrackingTheUser {
            mapView.setCenter(location.coordinate, animated: true)
        }
        sortBedsByDistance()
    }
}

// MARK: - TableView DataSource + Delegate
extension ViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return bedOrder.count
    }
    
    func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        return bedOrder[section]
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let button = UIButton(type: .system)
        button.setTitle(bedOrder[section], for: .normal)
        button.backgroundColor = UIColor.systemGray6
        button.tag = section
        button.addTarget(self, action: #selector(bedHeaderTapped(_:)), for: .touchUpInside)
        return button
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        let bed = bedOrder[section]
        return plantsByBed[bed]?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")

        
        let bed = bedOrder[indexPath.section]
        
        guard let plants = plantsByBed[bed] else {
            cell.textLabel?.text = "Loading..."
            return cell
        }
        
        let plant = plants[indexPath.row]

        let epithet = plant.infraspecific_epithet ?? ""
        cell.textLabel?.text = "\(plant.genus) \(plant.species) \(epithet)"
            .trimmingCharacters(in: .whitespaces)
        
        var subtitle = ""
        if let vn = plant.vernacular_name, !vn.isEmpty { subtitle += vn }
        if let cv = plant.cultivar_name, !cv.isEmpty {
            subtitle += subtitle.isEmpty ? "‘\(cv)’" : " – ‘\(cv)’"
        }
        
        cell.detailTextLabel?.text = subtitle
        cell.detailTextLabel?.numberOfLines = 2

        if let imgList = imagesByPlant[plant.recnum],
           let firstImage = imgList.first {
            
            let thumbURL =
            "https://cgi.csc.liv.ac.uk/~phil/Teaching/COMP228/ness_thumbnails/\(firstImage.filename)"
            
            if let url = URL(string: thumbURL) {
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data {
                        DispatchQueue.main.async {
                            // Set thumbnail and force layout update
                            cell.imageView?.image = UIImage(data: data)
                            cell.imageView?.contentMode = .scaleAspectFit
                            cell.setNeedsLayout()
                        }
                    }
                }.resume()
            }
        } else {
            cell.imageView?.image = UIImage(systemName: "leaf")
            cell.imageView?.contentMode = .scaleAspectFit
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let bed = bedOrder[indexPath.section]
        guard let plant = plantsByBed[bed]?[indexPath.row] else { return }
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(
            withIdentifier: "PlantDetailViewController"
        ) as! PlantDetailViewController
        vc.plant = plant
        vc.images = imagesByPlant[plant.recnum] ?? []
        navigationController?.pushViewController(vc, animated: true)
    }
    
    
    @objc func bedHeaderTapped(_ sender: UIButton) {
        let section = sender.tag
        let bedKey = bedOrder[section]

        guard let bed = bedLookup[bedKey] else { return }
        mapView.removeAnnotations(mapView.annotations)

        if let coord = bed.coordinate {
            let region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 150,
                longitudinalMeters: 150
            )
            mapView.setRegion(region, animated: true)
        }

        if let plantsInBed = plantsByBed[bedKey] {
            for plant in plantsInBed {

                guard
                    let latStr = plant.latitude,
                    let lonStr = plant.longitude,
                    let lat = Double(latStr),
                    let lon = Double(lonStr)
                else { continue }

                let pin = MKPointAnnotation()
                pin.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                pin.title = "\(plant.genus) \(plant.species)"
                pin.subtitle = plant.vernacular_name

                mapView.addAnnotation(pin)
            }
        }
    }

    
    // MARK: - TableView DataSource + Delegate
    func sortBedsByDistance() {
        
        guard let userLocation = userLocation else { return }
        let validBeds = bedOrder.compactMap { bedLookup[$0] }
        let sorted = validBeds.sorted { bedA, bedB in
            guard let coordA = bedA.coordinate,
                  let coordB = bedB.coordinate else {
                return false
            }
            
            let locA = CLLocation(latitude: coordA.latitude, longitude: coordA.longitude)
            let locB = CLLocation(latitude: coordB.latitude, longitude: coordB.longitude)
            
            return locA.distance(from: userLocation) < locB.distance(from: userLocation)
        }
        
        bedOrder = sorted.map { $0.recnum }
        tableView.reloadData()
    }
}
