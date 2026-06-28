import CoreLocation
import MapKit
import SwiftUI

struct GPSInspectorView: View {
    @Binding var metadata: PhotoMetadata
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var searchMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Map")
                .font(.headline)

            searchField

            if !searchResults.isEmpty {
                searchResultsList
            } else if !searchMessage.isEmpty {
                Text(searchMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let coordinate {
                AppleMapView(coordinate: coordinate) { selectedCoordinate in
                    apply(coordinate: selectedCoordinate)
                }
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                    Text("No GPS metadata")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
        .task(id: coordinateTaskID) {
            await reverseGeocodeCurrentCoordinate()
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(.secondary)

            TextField("Search Location...", text: $searchText)
                .textFieldStyle(.plain)
                .onSubmit {
                    Task {
                        await searchLocation()
                    }
                }

            if isSearching {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(searchResults.prefix(5).enumerated()), id: \.offset) { index, item in
                Button {
                    apply(mapItem: item)
                    searchResults = []
                    searchText = item.displayTitle
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                        if !item.displaySubtitle.isEmpty {
                            Text(item.displaySubtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                }
                .buttonStyle(.plain)

                if index < min(searchResults.count, 5) - 1 {
                    Divider()
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var coordinate: CLLocationCoordinate2D? {
        metadata.coordinate
    }

    private var coordinateTaskID: String {
        guard let coordinate else {
            return "no-gps"
        }

        return "\(coordinate.latitude),\(coordinate.longitude)"
    }

    private func searchLocation() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            searchMessage = ""
            return
        }

        isSearching = true
        searchMessage = ""

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        if let coordinate {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 35_000,
                longitudinalMeters: 35_000
            )
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = ranked(mapItems: response.mapItems)
            searchMessage = searchResults.isEmpty ? "No locations found" : ""
        } catch {
            searchResults = []
            searchMessage = "Location search failed"
        }

        isSearching = false
    }

    private func reverseGeocodeCurrentCoordinate() async {
        guard let coordinate else {
            metadata.clearGPSDisplayFields()
            return
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            guard let request = MKReverseGeocodingRequest(location: location) else {
                metadata.markGPSResolvingIfNeeded()
                return
            }

            let mapItems = try await request.mapItems
            guard let mapItem = ranked(mapItems: mapItems).first else {
                metadata.markGPSResolvingIfNeeded()
                return
            }

            applyLocationFields(from: mapItem, shouldUpdateCoordinate: false)
        } catch {
            metadata.markGPSResolvingIfNeeded()
        }
    }

    private func apply(mapItem: MKMapItem) {
        applyLocationFields(from: mapItem, shouldUpdateCoordinate: true)
    }

    private func apply(coordinate: CLLocationCoordinate2D) {
        metadata.latitude = String(format: "%.6f", coordinate.latitude)
        metadata.longitude = String(format: "%.6f", coordinate.longitude)
        metadata.altitude = ""
        metadata.locationName = "Resolving..."
        metadata.city = ""
        metadata.province = ""
        metadata.country = ""
        searchResults = []
        searchMessage = ""
    }

    private func applyLocationFields(from mapItem: MKMapItem, shouldUpdateCoordinate: Bool) {
        if shouldUpdateCoordinate {
            metadata.latitude = String(format: "%.6f", mapItem.location.coordinate.latitude)
            metadata.longitude = String(format: "%.6f", mapItem.location.coordinate.longitude)

            if mapItem.location.verticalAccuracy >= 0 {
                metadata.altitude = String(format: "%.0fm", mapItem.location.altitude)
            }
        }

        metadata.locationName = mapItem.bestLocationName
        metadata.city = mapItem.addressRepresentations?.cityName ?? metadata.city
        metadata.province = mapItem.addressRepresentations?.cityWithContext ?? metadata.province
        metadata.country = mapItem.addressRepresentations?.regionName ?? metadata.country
    }

    private func ranked(mapItems: [MKMapItem]) -> [MKMapItem] {
        mapItems.sorted { lhs, rhs in
            score(lhs) > score(rhs)
        }
    }

    private func score(_ item: MKMapItem) -> Int {
        var value = 0
        if item.pointOfInterestCategory != nil {
            value += 20
        }
        if item.name?.isEmpty == false {
            value += 8
        }
        if item.addressRepresentations?.cityName?.isEmpty == false {
            value += 4
        }

        let name = (item.name ?? "").lowercased()
        let publicHints = ["park", "reserve", "club", "resort", "museum", "hotel", "airport", "marina", "gardens", "centre", "center", "library", "stadium", "mall", "beach"]
        if publicHints.contains(where: { name.contains($0) }) {
            value += 12
        }

        let privateHints = ["condominium", "condo", "residence", "residences", "apartment", "apartments", "estate", "block", "tower"]
        if privateHints.contains(where: { name.contains($0) }) {
            value -= 16
        }

        return value
    }
}

private struct AppleMapView: NSViewRepresentable {
    let coordinate: CLLocationCoordinate2D
    let onCoordinateSelected: (CLLocationCoordinate2D) -> Void

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .includingAll
        mapView.showsCompass = true
        mapView.showsScale = true
        let recognizer = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.mapClicked(_:)))
        mapView.addGestureRecognizer(recognizer)
        return mapView
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCoordinateSelected: onCoordinateSelected)
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView
        context.coordinator.onCoordinateSelected = onCoordinateSelected
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1_200,
            longitudinalMeters: 1_200
        )
        mapView.setRegion(region, animated: true)
        mapView.removeAnnotations(mapView.annotations)

        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        weak var mapView: MKMapView?
        var onCoordinateSelected: (CLLocationCoordinate2D) -> Void

        init(onCoordinateSelected: @escaping (CLLocationCoordinate2D) -> Void) {
            self.onCoordinateSelected = onCoordinateSelected
        }

        @objc func mapClicked(_ recognizer: NSClickGestureRecognizer) {
            guard let mapView else {
                return
            }

            let point = recognizer.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            onCoordinateSelected(coordinate)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else {
                return nil
            }

            let identifier = "editable-gps-pin"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.markerTintColor = .systemRed
            view.isDraggable = true
            return view
        }

        func mapView(
            _ mapView: MKMapView,
            annotationView view: MKAnnotationView,
            didChange newState: MKAnnotationView.DragState,
            fromOldState oldState: MKAnnotationView.DragState
        ) {
            guard newState == .ending, let coordinate = view.annotation?.coordinate else {
                return
            }

            onCoordinateSelected(coordinate)
        }
    }
}

extension PhotoMetadata {
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude = Double(latitude), let longitude = Double(longitude) else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var locationDisplay: String {
        guard coordinate != nil else {
            return "No GPS metadata"
        }

        return locationName.isEmpty ? "Resolving..." : locationName
    }

    mutating func clearGPSDisplayFields() {
        locationName = ""
    }

    mutating func markGPSResolvingIfNeeded() {
        if coordinate != nil, locationName.isEmpty {
            locationName = "Resolving..."
        }
    }
}

private extension MKMapItem {
    var displayTitle: String {
        bestLocationName
    }

    var displaySubtitle: String {
        addressRepresentations?.fullAddress(includingRegion: true, singleLine: true)
            ?? addressRepresentations?.cityWithContext(.full)
            ?? ""
    }

    var bestLocationName: String {
        let candidates = [
            name,
            addressRepresentations?.cityWithContext(.full),
            addressRepresentations?.regionName
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .uniqued()

        return candidates.joined(separator: "\n")
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
