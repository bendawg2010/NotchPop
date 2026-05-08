// SystemStatsService.swift
//
// Polls macOS for live CPU + RAM usage every 2s. CPU is sampled via
// host_statistics(HOST_CPU_LOAD_INFO), which returns CUMULATIVE jiffies
// since boot — we must cache the previous sample and compute the delta
// between two snapshots to get an instantaneous percent. Memory uses
// host_statistics64(HOST_VM_INFO64) for page-granular free/active/wired.

import Foundation
import Combine
import Darwin

final class SystemStatsService: ObservableObject {
    @Published var cpuPercent: Double = 0       // 0-100
    @Published var memoryPercent: Double = 0    // 0-100
    @Published var memoryUsedGB: Double = 0
    @Published var memoryTotalGB: Double = 0

    private var timer: Timer?
    private var previousCPUTicks: host_cpu_load_info?

    private let pollInterval: TimeInterval = 2.0
    private let totalPhysicalBytes: UInt64 = ProcessInfo.processInfo.physicalMemory

    func start() {
        // Set total once — it never changes.
        memoryTotalGB = Double(totalPhysicalBytes) / 1_073_741_824.0

        // Prime the CPU sample so the first published value isn't garbage.
        previousCPUTicks = readCPUTicks()

        sample()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    private func sample() {
        if let cpu = computeCPUPercent() {
            // Stay on the main actor for @Published mutations.
            DispatchQueue.main.async { self.cpuPercent = cpu }
        }
        if let mem = computeMemory() {
            DispatchQueue.main.async {
                self.memoryUsedGB = mem.usedGB
                self.memoryPercent = mem.percent
            }
        }
    }

    // MARK: - CPU

    /// Reads HOST_CPU_LOAD_INFO — cumulative tick counters per state.
    private func readCPUTicks() -> host_cpu_load_info? {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info()
        let kr = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { reboundPtr in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, reboundPtr, &size)
            }
        }
        return kr == KERN_SUCCESS ? info : nil
    }

    /// Compute (user_delta + system_delta) / total_delta * 100 vs the previous sample.
    private func computeCPUPercent() -> Double? {
        guard let current = readCPUTicks() else { return nil }
        defer { previousCPUTicks = current }
        guard let previous = previousCPUTicks else { return nil }

        let userDelta   = Double(current.cpu_ticks.0) - Double(previous.cpu_ticks.0) // CPU_STATE_USER
        let systemDelta = Double(current.cpu_ticks.1) - Double(previous.cpu_ticks.1) // CPU_STATE_SYSTEM
        let idleDelta   = Double(current.cpu_ticks.2) - Double(previous.cpu_ticks.2) // CPU_STATE_IDLE
        let niceDelta   = Double(current.cpu_ticks.3) - Double(previous.cpu_ticks.3) // CPU_STATE_NICE

        let total = userDelta + systemDelta + idleDelta + niceDelta
        guard total > 0 else { return nil }
        let active = userDelta + systemDelta + niceDelta
        return max(0, min(100, (active / total) * 100.0))
    }

    // MARK: - Memory

    private struct MemorySample {
        let usedGB: Double
        let percent: Double
    }

    /// Reads HOST_VM_INFO64 — page-counted free / active / wired / etc.
    private func computeMemory() -> MemorySample? {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        var stats = vm_statistics64()
        let kr = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(size)) { reboundPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, reboundPtr, &size)
            }
        }
        guard kr == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_kernel_page_size)
        let freeBytes = UInt64(stats.free_count) * pageSize
        let usedBytes = totalPhysicalBytes &- min(freeBytes, totalPhysicalBytes)

        let usedGB = Double(usedBytes) / 1_073_741_824.0
        let percent = totalPhysicalBytes > 0
            ? max(0, min(100, (Double(usedBytes) / Double(totalPhysicalBytes)) * 100.0))
            : 0
        return MemorySample(usedGB: usedGB, percent: percent)
    }

    deinit {
        timer?.invalidate()
    }
}
