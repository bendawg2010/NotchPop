// NetworkInfoService.swift
//
// Pulls the user's Wi-Fi SSID and primary IPv4 address. Wi-Fi name
// uses CoreWLAN (CWWiFiClient.shared().interface()?.ssid()). IP
// address comes from getifaddrs(), filtered to en0/en1/en2 (the
// usual Mac wireless / wired interfaces). Refreshes every 10s on
// a Timer; also on .didChangeNotification.

import Foundation
import CoreWLAN
import Network
import SystemConfiguration

final class NetworkInfoService: ObservableObject {
    @Published var ssid: String?
    @Published var ipAddress: String?
    @Published var rssi: Int?              // signal strength in dBm
    @Published var lastUpdated: Date?

    private var timer: Timer?

    init() {
        refresh()
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        // CoreWLAN — the canonical way to read SSID + RSSI on macOS.
        // Returns nil if Wi-Fi is off, no association, or the user
        // hasn't granted Location permission (macOS 14+ requires it
        // to read SSID for privacy reasons).
        let client = CWWiFiClient.shared()
        let iface = client.interface()
        let s = iface?.ssid()
        let r = iface?.rssiValue()
        let ip = Self.primaryIPv4()
        DispatchQueue.main.async {
            self.ssid = s
            self.rssi = (r != 0 ? r : nil) as Int?
            self.ipAddress = ip
            self.lastUpdated = Date()
        }
    }

    /// Walk the local interface list and return the first IPv4 on
    /// en0/en1/en2 that's NOT a loopback. Avoids utun*, awdl*, etc.
    private static func primaryIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        let preferred = Set(["en0", "en1", "en2", "en3"])
        var fallback: String?
        while let p = ptr {
            let addr = p.pointee.ifa_addr.pointee
            if addr.sa_family == UInt8(AF_INET) {
                let name = String(cString: p.pointee.ifa_name)
                var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(p.pointee.ifa_addr,
                                          socklen_t(p.pointee.ifa_addr.pointee.sa_len),
                                          &hostBuf, socklen_t(hostBuf.count),
                                          nil, 0, NI_NUMERICHOST)
                if result == 0 {
                    let ip = String(cString: hostBuf)
                    if ip != "127.0.0.1" {
                        if preferred.contains(name) { return ip }
                        if fallback == nil { fallback = ip }
                    }
                }
            }
            ptr = p.pointee.ifa_next
        }
        return fallback
    }

    /// Convert RSSI in dBm to a 0–4 bars rating. -50 strongest,
    /// -90 unusable.
    var bars: Int {
        guard let r = rssi else { return 0 }
        switch r {
        case -50...0:   return 4
        case -65 ..< -50: return 3
        case -75 ..< -65: return 2
        case -85 ..< -75: return 1
        default: return 0
        }
    }
}
