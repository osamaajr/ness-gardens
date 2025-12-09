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
    var favourites: Set<String> = []
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
    
    // MARK: - Trails
    func showTrailList() {
        print("Trails available:", trails.map { $0.name })
        
        let alert = UIAlertController(title: "Choose a Trail",
                                      message: nil,
                                      preferredStyle: .actionSheet)
        
        // menu items for all available trails
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

        // build polyline from trail coordinates
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
        
        
        // centre view on first point
        if let first = coords.first {
            let region = MKCoordinateRegion(
                center: first,
                latitudinalMeters: 300,
                longitudinalMeters: 300
            )
            mapView.setRegion(region, animated: true)
        }
    }

    // renderer for trail lines
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
    
    
    func loadFavourites() {
        let saved = UserDefaults.standard.stringArray(forKey: "favourites") ?? []
        favourites = Set(saved)
    }

    func saveFavourites() {
        UserDefaults.standard.set(Array(favourites), forKey: "favourites")
    }




    // MARK: - Data
    var beds: [Bed] = []
    var plantsByBed: [String: [Plant]] = [:]
    var bedOrder: [String] = []     // current ordering of bed sections
    var userLocation: CLLocation?
    var imagesByPlant: [String: [ImageInfo]] = [:]
    var trails: [Trail] = []
    var trailLocations: [TrailLocation] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // restore saved favourites
        if let saved = UserDefaults.standard.array(forKey: "favourites") as? [String] {
            favourites = Set(saved)
        }
        
        loadFavourites()
        
        chooseTrailButton.isEnabled = false

        mapView.mapType = .satellite
        mapView.showsUserLocation = true

        tableView.dataSource = self
        tableView.delegate = self
        mapView.delegate = self

        setupLocation()
        loadData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // debug: ensure table is loading sections properly
        print("Sections:", tableView.numberOfSections)
        if tableView.numberOfSections > 0 {
            print("Rows in first section:", tableView.numberOfRows(inSection: 0))
        }
    }


    // MARK: - Load API Data
    func loadData() {
        
        // beds then plants then images then trails
        NetworkManager.shared.fetchBeds { beds in
            self.beds = beds
            self.bedLookup = Dictionary(uniqueKeysWithValues:
                beds.map { ($0.bed_id, $0) }
            )

            NetworkManager.shared.fetchPlants { plants in
                
                var grouped: [String: [Plant]] = [:]
                
                print("Total plants from API:", plants.count)

                let alive = plants.filter { $0.accsta.uppercased() == "C" }
                print("Alive plants (accsta == 'C'):", alive.count)

                // group plants by each bed they appear in
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
                
                // load plant images
                NetworkManager.shared.fetchImages { images in
                    self.imagesByPlant = Dictionary(grouping: images, by: { $0.recnum })

                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }
                }

                // load trail coords
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

            // initial zoom in on user
            let span = MKCoordinateSpan(latitudeDelta: 0.0025, longitudeDelta: 0.0025)
            let region = MKCoordinateRegion(center: location.coordinate,
                                            span: span)

            mapView.setRegion(region, animated: true)
            // start following after short delay
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
    
    // tappable bed header to shows pins on map
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let bed = bedOrder[section]
        return plantsByBed[bed]?.count ?? 0
    }
    
    // MARK: - Cell config
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        
        cell.selectionStyle = .default

        let bed = bedOrder[indexPath.section]
        
        guard let plants = plantsByBed[bed] else {
            cell.textLabel?.text = "Loading..."
            cell.detailTextLabel?.text = nil
            cell.imageView?.image = nil
            cell.accessoryView = nil
            return cell
        }
        
        let plant = plants[indexPath.row]

        // plant name foormatting
        let epithet = plant.infraspecific_epithet ?? ""
        cell.textLabel?.text = "\(plant.genus) \(plant.species) \(epithet)"
            .trimmingCharacters(in: .whitespaces)

        var subtitle = ""
        if let vn = plant.vernacular_name, !vn.isEmpty { subtitle += vn }
        if let cv = plant.cultivar_name, !cv.isEmpty {
            subtitle += subtitle.isEmpty ? " '\(cv)'" : " – '\(cv)'"
        }
        cell.detailTextLabel?.text = subtitle
        cell.detailTextLabel?.numberOfLines = 2
        
        // favourite star
        let starButton = UIButton(type: .system)
        starButton.tintColor = .systemYellow
        starButton.frame = CGRect(x: 0, y: 0, width: 30, height: 30)

        let isFavourite = favourites.contains(plant.recnum)
        let icon = isFavourite ? "star.fill" : "star"
        starButton.setImage(UIImage(systemName: icon), for: .normal)

        starButton.tag = Int(plant.recnum) ?? 0
        starButton.addTarget(self,
                             action: #selector(toggleFavourite(_:)),
                             for: .touchUpInside)

        cell.accessoryView = starButton
        
        // load thumbnail if available
        if let imgList = imagesByPlant[plant.recnum],
           let firstImage = imgList.first,
           let url = URL(string:
            "https://cgi.csc.liv.ac.uk/~phil/Teaching/COMP228/ness_thumbnails/\(firstImage.filename)"
           ) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data {
                    DispatchQueue.main.async {
                        cell.imageView?.image = UIImage(data: data)
                        cell.imageView?.contentMode = .scaleAspectFit
                        cell.setNeedsLayout()
                    }
                }
            }.resume()

        } else {
            cell.imageView?.image = UIImage(systemName: "leaf")
            cell.imageView?.contentMode = .scaleAspectFit
        }
        return cell
    }
    
    //push detail view
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
    
    // bed header tap to show all plant pins in that bed
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

        // add plant pins
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
    
    @objc func toggleFavourite(_ sender: UIButton) {
        let recnum = String(sender.tag)

        // Toggle value
        if favourites.contains(recnum) {
            favourites.remove(recnum)
        } else {
            favourites.insert(recnum)
        }
        
        UserDefaults.standard.set(Array(favourites), forKey: "favourites")
        if favourites.contains(recnum) {
            sender.setImage(UIImage(systemName: "star.fill"), for: .normal)
        } else {
            sender.setImage(UIImage(systemName: "star"), for: .normal)
        }
        tableView.reloadData()
    }
    
    // MARK: - Bed Sorting
    func sortBedsByDistance() {
        
        guard let userLocation = userLocation else { return }
        let validBeds = bedOrder.compactMap { bedLookup[$0] }
        // sort beds by distance to user
        let sorted = validBeds.sorted { bedA, bedB in
            guard let coordA = bedA.coordinate,
                  let coordB = bedB.coordinate else {
                return false
            }
            
            let locA = CLLocation(latitude: coordA.latitude, longitude: coordA.longitude)
            let locB = CLLocation(latitude: coordB.latitude, longitude: coordB.longitude)
            
            return locA.distance(from: userLocation) < locB.distance(from: userLocation)
        }
        
        bedOrder = sorted.map { $0.bed_id }
        tableView.reloadData()
    }
}
