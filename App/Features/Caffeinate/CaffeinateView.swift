// CaffeinateView.swift
//
// Keeps the Mac awake by holding an IOPMAssertion. Toggle is
// persisted across launches — if user enabled it then quit
// NotchPop, the assertion is gone (process-scoped), but on
// relaunch we see the saved-on flag and re-arm.

import IOKit.pwr_mgt
import SwiftUI

final class CaffeinateService: ObservableObject {
    @Published var isAwake: Bool {
        didSet {
            UserDefaults.standard.set(isAwake, forKey: "np.caffeinateOn")
            if isAwake { arm() } else { disarm() }
        }
    }
    private var assertionID: IOPMAssertionID = 0

    init() {
        self.isAwake = UserDefaults.standard.bool(forKey: "np.caffeinateOn")
        if isAwake { arm() }
    }

    private func arm() {
        let reason = "NotchPop · Caffeinate" as CFString
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason, &assertionID)
    }
    private func disarm() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
    }
    deinit { disarm() }
}

struct CaffeinateView: View {
    @StateObject private var service = CaffeinateService()
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: service.isAwake ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(LinearGradient(
                        colors: service.isAwake
                            ? [Color(red: 1.00, green: 0.85, blue: 0.20),
                               Color(red: 1.00, green: 0.40, blue: 0.30)]
                            : [.gray, .gray.opacity(0.5)],
                        startPoint: .top, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 2) {
                    Text(service.isAwake ? "Mac is awake" : "Mac sleeps normally")
                        .font(.system(size: 14, weight: .heavy))
                    Text(service.isAwake
                         ? "Display won't dim or sleep while this is on."
                         : "Toggle on to keep your Mac awake.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            Toggle(isOn: $service.isAwake) {
                Text(service.isAwake ? "Stop caffeinating" : "Caffeinate")
                    .font(.system(size: 13, weight: .heavy))
            }
            .toggleStyle(.switch)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
