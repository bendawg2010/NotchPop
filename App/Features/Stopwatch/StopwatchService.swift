// StopwatchService.swift
//
// Standard count-up stopwatch with lap support. Uses a single
// monotonic accumulator (`elapsedAccumulated`) plus a `runStart`
// timestamp; current display = accumulator + (now - runStart) when
// running. This avoids drift from per-tick subtraction errors and
// keeps the timer accurate even if the system sleeps during a run.

import Foundation
import Combine

final class StopwatchService: ObservableObject {
    @Published var elapsed: TimeInterval = 0
    @Published var running: Bool = false
    @Published var laps: [TimeInterval] = []

    private var elapsedAccumulated: TimeInterval = 0
    private var runStart: Date?
    private var ticker: Timer?

    func start() {
        guard !running else { return }
        runStart = Date()
        running = true
        ticker?.invalidate()
        ticker = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func pause() {
        guard running else { return }
        if let s = runStart {
            elapsedAccumulated += Date().timeIntervalSince(s)
        }
        runStart = nil
        running = false
        ticker?.invalidate()
        ticker = nil
        refresh()
    }

    func toggle() { running ? pause() : start() }

    func reset() {
        ticker?.invalidate()
        ticker = nil
        running = false
        runStart = nil
        elapsedAccumulated = 0
        elapsed = 0
        laps.removeAll()
    }

    /// Mark a lap. Captures the current elapsed in the lap list.
    /// Last entry is the freshest lap.
    func lap() {
        guard running else { return }
        laps.insert(elapsed, at: 0)
        if laps.count > 50 { laps.removeLast(laps.count - 50) }
    }

    private func refresh() {
        if let s = runStart {
            elapsed = elapsedAccumulated + Date().timeIntervalSince(s)
        } else {
            elapsed = elapsedAccumulated
        }
    }

    /// MM:SS.ms formatted display — large readable digits.
    var formatted: String {
        let m = Int(elapsed) / 60
        let s = Int(elapsed) % 60
        let ms = Int((elapsed - floor(elapsed)) * 100)
        return String(format: "%02d:%02d.%02d", m, s, ms)
    }
}
