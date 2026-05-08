// AirPodsService.swift
//
// Polls connected AirPods (and other Bluetooth headphones) for battery
// levels by shelling out to `system_profiler -xml SPBluetoothDataType`
// and parsing the resulting plist. We deliberately avoid IOBluetooth /
// CoreBluetooth: the per-device-battery characteristic is gated behind
// private SPI and TCC permission prompts, while system_profiler's
// public profile already exposes the same numbers without any
// entitlements or user-facing permission dialog.

import Foundation
import Combine

/// Snapshot of the currently-connected headphones. `nil` percentages
/// mean that side simply isn't reporting — e.g. AirPods Max is a
/// single-piece device with only `device_batteryLevelMain`, and an
/// AirPod that's still in the case won't report its own level until
/// it's pulled out.
struct AirPodsState: Equatable {
    var connected: Bool
    var model: String
    var leftPercent: Int?
    var rightPercent: Int?
    var casePercent: Int?

    static let disconnected = AirPodsState(
        connected: false,
        model: "",
        leftPercent: nil,
        rightPercent: nil,
        casePercent: nil
    )
}

final class AirPodsService: ObservableObject {
    @Published var state: AirPodsState = .disconnected

    /// Polling cadence. system_profiler is cheap (~150 ms) but not
    /// free, and AirPods battery only ticks in 10% increments anyway,
    /// so 60s is plenty.
    private let pollInterval: TimeInterval = 60
    private var timer: Timer?

    /// Run system_profiler off the main thread so the UI stays smooth.
    private let queue = DispatchQueue(label: "com.notchpop.airpods.poll",
                                      qos: .utility)

    func start() {
        // Immediate first poll, then every `pollInterval` seconds.
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval,
                                     repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: - Polling

    private func refresh() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let next = Self.fetchState()
            DispatchQueue.main.async {
                if self.state != next {
                    self.state = next
                }
            }
        }
    }

    /// Runs system_profiler synchronously, parses the plist, and
    /// returns the first connected audio device's battery snapshot.
    /// Returns `.disconnected` on any failure or when nothing relevant
    /// is connected.
    private static func fetchState() -> AirPodsState {
        guard let data = runSystemProfiler() else {
            return .disconnected
        }
        guard let plist = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: nil) else {
            return .disconnected
        }
        // Plist root is an array containing one dict; the dict has an
        // `_items` array of bluetooth controller dicts.
        guard let root = plist as? [[String: Any]] else {
            return .disconnected
        }
        for entry in root {
            guard let items = entry["_items"] as? [[String: Any]] else {
                continue
            }
            for controller in items {
                if let connected = controller["device_connected"]
                        as? [[String: Any]],
                   let device = firstAudioDevice(in: connected) {
                    return device
                }
                // Some macOS versions stash devices as a flat
                // `devices_list` array of single-key dicts. Walk that
                // too, filtering by `device_isconnected == attrib_Yes`.
                if let list = controller["devices_list"]
                        as? [[String: Any]],
                   let device = firstAudioDevice(in: list,
                                                 requireConnectedFlag: true) {
                    return device
                }
            }
        }
        return .disconnected
    }

    // MARK: - Plist walking

    /// Each Bluetooth device in the system_profiler output is wrapped
    /// in a single-key dict where the key is the device's user-visible
    /// name (e.g. "Ben's AirPods Pro") and the value is a property
    /// dict. Iterates those entries, returns the first that looks like
    /// audio gear and has at least one battery reading.
    private static func firstAudioDevice(
        in entries: [[String: Any]],
        requireConnectedFlag: Bool = false
    ) -> AirPodsState? {
        for entry in entries {
            for (deviceName, raw) in entry {
                guard let props = raw as? [String: Any] else { continue }
                if requireConnectedFlag {
                    let flag = props["device_isconnected"] as? String
                    guard flag == "attrib_Yes" else { continue }
                }
                guard isAudioDevice(props) else { continue }
                let left = parsePercent(props["device_batteryLevelLeft"])
                let right = parsePercent(props["device_batteryLevelRight"])
                let caseLvl = parsePercent(props["device_batteryLevelCase"])
                let main = parsePercent(props["device_batteryLevelMain"])
                // If there's no battery reading at all, skip — this is
                // probably a device that's paired but not reporting,
                // and we shouldn't claim it's "connected" in the UI.
                if left == nil && right == nil && caseLvl == nil && main == nil {
                    continue
                }
                // Single-piece devices (AirPods Max, Beats Studio Pro,
                // generic over-ears) only expose `device_batteryLevelMain`.
                // Surface that as left so the UI has at least one
                // reading to render.
                let resolvedLeft = left ?? main
                return AirPodsState(
                    connected: true,
                    model: cleanModel(name: deviceName, props: props),
                    leftPercent: resolvedLeft,
                    rightPercent: right,
                    casePercent: caseLvl
                )
            }
        }
        return nil
    }

    /// Headphones / Audio devices we care about. We accept anything
    /// whose `device_minorType` is Headphones OR whose
    /// `device_majorType` is Audio (covers some speakers / headsets
    /// that report a different minor type but still surface a battery).
    private static func isAudioDevice(_ props: [String: Any]) -> Bool {
        let minor = (props["device_minorType"] as? String) ?? ""
        let major = (props["device_majorType"] as? String) ?? ""
        if minor == "Headphones" { return true }
        if major == "Audio" { return true }
        return false
    }

    /// Strips a trailing `%` and parses to Int. Returns `nil` for
    /// missing keys, empty values, or unparseable strings (rather
    /// than 0, which would mean "completely dead" in the UI).
    private static func parsePercent(_ value: Any?) -> Int? {
        guard let s = value as? String, !s.isEmpty else { return nil }
        let trimmed = s.hasSuffix("%") ? String(s.dropLast()) : s
        return Int(trimmed)
    }

    /// Best-effort device label. Apple doesn't expose a clean model
    /// string in system_profiler, so we take the user-set Bluetooth
    /// name ("Ben's AirPods Pro 2"), fall back to a generic if it's
    /// empty. The user-set name is almost always informative enough.
    private static func cleanModel(name: String,
                                   props: [String: Any]) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let major = props["device_majorType"] as? String, major == "Audio" {
            return "Bluetooth Headphones"
        }
        return "Generic Bluetooth Headphones"
    }

    // MARK: - Process invocation

    /// Spawns `/usr/sbin/system_profiler -xml -detailLevel mini
    /// SPBluetoothDataType` and returns the captured stdout. We use
    /// `Process` rather than `system()` / `popen()` so we don't go
    /// through a shell — there's nothing to escape, no $PATH lookup,
    /// and we get a clean Pipe for the plist data.
    private static func runSystemProfiler() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        process.arguments = [
            "-xml",
            "-detailLevel", "mini",
            "SPBluetoothDataType"
        ]
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return nil
        }
        // Read before waiting to avoid filling the pipe buffer on
        // chatty machines (lots of paired devices).
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return data.isEmpty ? nil : data
    }
}
