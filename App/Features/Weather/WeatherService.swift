// WeatherService.swift
//
// Pulls current weather from Open-Meteo. Open-Meteo is free, has no
// API-key requirement, and doesn't impose rate limits for personal
// use — perfect fit for a free MIT-licensed indie app. Single GET
// against api.open-meteo.com/v1/forecast with current_weather=true.
//
// Location: we use CoreLocation when the user has granted location
// permission, otherwise fall back to a coarse IP-geolocation lookup
// against ipapi.co. Either way the user can override their location
// in Settings → World Clock-style picker (TODO — for now we accept
// CL-then-IP-fallback). We cache a manual override in UserDefaults
// under "np.weatherLat" / "np.weatherLon" / "np.weatherLocLabel".

import Combine
import CoreLocation
import Foundation

struct WeatherSnapshot: Equatable {
    /// Temperature in the user's chosen unit (°C or °F)
    var temperature: Double
    /// Apparent (feels-like) temperature in the same unit
    var apparent: Double?
    /// Open-Meteo weather code (0=clear, 2=partly, 3=overcast, 45=fog,
    /// 51..67=drizzle/rain, 71..86=snow, 95..99=thunder). We map this
    /// to an SF Symbol + a friendly label.
    var weatherCode: Int
    /// Wind speed in km/h (we'll convert if the user picks imperial)
    var windKph: Double
    /// Approx human-readable label for the location ("Cupertino, CA")
    var locationLabel: String
    /// Last-fetched timestamp, used to show "Updated 5 min ago"
    var fetchedAt: Date

    /// True if the temperature/apparent are degrees Fahrenheit (we
    /// asked Open-Meteo for that unit). Decided per request based on
    /// the viewModel's `weatherUsesFahrenheit` setting.
    var fahrenheit: Bool

    var symbolName: String {
        switch weatherCode {
        case 0:               return "sun.max.fill"
        case 1, 2:            return "cloud.sun.fill"
        case 3:               return "cloud.fill"
        case 45, 48:          return "cloud.fog.fill"
        case 51...57:         return "cloud.drizzle.fill"
        case 61...67:         return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 80...82:         return "cloud.heavyrain.fill"
        case 95:              return "cloud.bolt.rain.fill"
        case 96, 99:          return "cloud.bolt.fill"
        default:              return "cloud"
        }
    }
    var label: String {
        switch weatherCode {
        case 0:               return "Clear"
        case 1, 2:            return "Partly cloudy"
        case 3:               return "Overcast"
        case 45, 48:          return "Foggy"
        case 51...57:         return "Drizzle"
        case 61...67:         return "Rain"
        case 71...77, 85, 86: return "Snow"
        case 80...82:         return "Showers"
        case 95...99:         return "Thunder"
        default:              return "Weather"
        }
    }
}

final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading: Bool = false

    /// User-set unit preference. Persisted in UserDefaults so the
    /// service can pick the right Open-Meteo `temperature_unit`
    /// without round-tripping through NotchViewModel.
    @Published var fahrenheit: Bool {
        didSet {
            UserDefaults.standard.set(fahrenheit, forKey: "np.weatherFahrenheit")
            // Re-fetch in the new unit so the user sees the change immediately.
            refresh()
        }
    }

    private let locationManager = CLLocationManager()
    private var refreshTimer: Timer?
    /// Exponential backoff guard — bail out if we've failed 5 times in a row
    /// (e.g. user is offline). Resets on a successful fetch.
    private var consecutiveFailures = 0
    private var lastFix: CLLocation?

    override init() {
        let d = UserDefaults.standard
        self.fahrenheit = d.object(forKey: "np.weatherFahrenheit") as? Bool
            ?? Locale.current.usesMetricSystem == false
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// Begin updates. Call once when the Weather tab first appears.
    /// Subsequent calls are no-ops (the timer + delegate are already
    /// running). Refresh triggers every 15 minutes.
    func start() {
        if refreshTimer != nil { return }
        // Ask for permission lazily — we DON'T request it at app
        // launch because a free indie app shouldn't be popping
        // permission dialogs the user didn't ask for.
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorized:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            // Fall back to IP-based geolocation
            fetchByIP()
        @unknown default:
            fetchByIP()
        }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        if let loc = lastFix {
            fetch(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude,
                  label: snapshot?.locationLabel ?? "Your location")
        } else if locationManager.authorizationStatus == .denied
                    || locationManager.authorizationStatus == .restricted {
            fetchByIP()
        } else {
            locationManager.startUpdatingLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastFix = loc
        // We just want one fix every 15 min — stop the live updates
        // until the next refresh tick.
        manager.stopUpdatingLocation()
        // Reverse-geocode to a friendly label (best-effort; if the
        // network isn't there we fall back to "lat, lon" rounded).
        let geo = CLGeocoder()
        geo.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            let label = Self.label(from: placemarks?.first, fallback: loc)
            self?.fetch(lat: loc.coordinate.latitude,
                        lon: loc.coordinate.longitude,
                        label: label)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("NotchPop weather: location error \(error.localizedDescription)")
        // Fall back to IP geolocation so the user still sees something.
        fetchByIP()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorized:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            fetchByIP()
        default: break
        }
    }

    // MARK: - Network

    /// Open-Meteo doesn't need a key. Hits a single GET and decodes
    /// the inline `current_weather` block. Bumps consecutiveFailures
    /// on errors so the periodic refresh backs off when offline.
    private func fetch(lat: Double, lon: Double, label: String) {
        let unit = fahrenheit ? "fahrenheit" : "celsius"
        let urlStr = "https://api.open-meteo.com/v1/forecast?"
            + "latitude=\(lat)&longitude=\(lon)"
            + "&current_weather=true"
            + "&temperature_unit=\(unit)"
            + "&windspeed_unit=kmh"
        guard let url = URL(string: urlStr) else { return }
        isLoading = true
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    self?.lastError = error.localizedDescription
                    self?.consecutiveFailures += 1
                    return
                }
                guard let data = data else {
                    self?.lastError = "Empty response"
                    self?.consecutiveFailures += 1
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode(OMResponse.self, from: data)
                    self?.snapshot = WeatherSnapshot(
                        temperature: decoded.current_weather.temperature,
                        apparent: nil,
                        weatherCode: decoded.current_weather.weathercode,
                        windKph: decoded.current_weather.windspeed,
                        locationLabel: label,
                        fetchedAt: Date(),
                        fahrenheit: self?.fahrenheit ?? false
                    )
                    self?.lastError = nil
                    self?.consecutiveFailures = 0
                } catch {
                    self?.lastError = "Couldn't parse weather"
                    self?.consecutiveFailures += 1
                }
            }
        }.resume()
    }

    /// Coarse IP-based lat/lon when the user has denied CL permission.
    /// Uses ipapi.co — also free, no key.
    private func fetchByIP() {
        guard let url = URL(string: "https://ipapi.co/json/") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let lat = json["latitude"] as? Double,
                  let lon = json["longitude"] as? Double else { return }
            let city = json["city"] as? String ?? "Approximate location"
            let region = json["region_code"] as? String ?? ""
            let label = region.isEmpty ? city : "\(city), \(region)"
            DispatchQueue.main.async {
                self?.fetch(lat: lat, lon: lon, label: label)
            }
        }.resume()
    }

    private static func label(from placemark: CLPlacemark?, fallback: CLLocation) -> String {
        if let p = placemark {
            if let city = p.locality, let admin = p.administrativeArea {
                return "\(city), \(admin)"
            }
            if let city = p.locality { return city }
            if let admin = p.administrativeArea { return admin }
        }
        return String(format: "%.2f, %.2f",
                      fallback.coordinate.latitude,
                      fallback.coordinate.longitude)
    }

    // MARK: - Open-Meteo decoding

    private struct OMResponse: Decodable {
        let current_weather: OMCurrent
    }
    private struct OMCurrent: Decodable {
        let temperature: Double
        let windspeed: Double
        let weathercode: Int
    }
}
