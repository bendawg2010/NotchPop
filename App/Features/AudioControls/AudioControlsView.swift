// AudioControlsView.swift
//
// Pane shown inside the expanded notch when the Audio tab is active.
// Volume + brightness sliders that drive macOS directly. Volume goes
// through Core Audio's AudioObject* APIs (the public, supported way
// to set output volume); brightness is set via `osascript` calling
// the System Events brightness AppleScript path because there's no
// public API for brightness on macOS.
//
// User feedback: "add more modules ... brightness/volume sliders"
// — pinning these as one-stop controls inside the notch.

import AppKit
import AVFoundation
import CoreAudio
import SwiftUI

final class AudioControlsService: ObservableObject {
    @Published var volume: Float = 0.5

    init() {
        refresh()
    }

    /// Read the current default-output device volume and update the
    /// @Published value so the slider reflects reality.
    func refresh() {
        var deviceID: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                    &addr, 0, nil, &size, &deviceID)
        var v: Float32 = 0
        var vSize = UInt32(MemoryLayout<Float32>.size)
        addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &vSize, &v)
        if status == noErr {
            DispatchQueue.main.async { self.volume = v }
        }
    }

    /// Set the system output volume to the given value (0…1).
    func setVolume(_ newValue: Float) {
        let clamped = max(0, min(1, newValue))
        self.volume = clamped
        var deviceID: AudioObjectID = 0
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                    &addr, 0, nil, &size, &deviceID)
        var v: Float32 = clamped
        let vSize = UInt32(MemoryLayout<Float32>.size)
        addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectSetPropertyData(deviceID, &addr, 0, nil, vSize, &v)
    }

    /// Set system brightness via osascript. There is no public API
    /// for this on macOS — Apple gates the brightness assistant
    /// behind the private DisplayServices framework. The osascript
    /// path uses System Events keystrokes to bump brightness in
    /// 1/16 increments, which is the SAME mechanism the F1/F2 keys
    /// drive when you press them.
    func nudgeBrightness(up: Bool) {
        // Send the F1/F2 keystroke equivalents via CGEvent.
        // F1 = 122 (down), F2 = 120 (up). Wait — in macOS reality
        // F1 is the brightness-DOWN key when fn-row defaults are
        // active; F2 is brightness-UP. We post the appropriate
        // virtual key.
        let keyCode: CGKeyCode = up ? 144 : 145 // brightness up / down system codes
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        down?.post(tap: .cghidEventTap)
        let upE = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        upE?.post(tap: .cghidEventTap)
    }
}

struct AudioControlsView: View {
    @ObservedObject var service: AudioControlsService

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 18)
                Slider(value: Binding(
                    get: { Double(service.volume) },
                    set: { service.setVolume(Float($0)) }
                ), in: 0...1)
                Text("\(Int(service.volume * 100))%")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 36, alignment: .trailing)
                    .monospacedDigit()
            }
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 18)
                Spacer()
                Button {
                    service.nudgeBrightness(up: false)
                } label: {
                    Image(systemName: "sun.min")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .help("Brightness down")

                Button {
                    service.nudgeBrightness(up: true)
                } label: {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .help("Brightness up")
                Spacer()
                Button {
                    service.setVolume(0)
                } label: {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
                .help("Mute")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 88)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .onAppear { service.refresh() }
    }

    private var volumeIcon: String {
        let v = service.volume
        if v <= 0.001 { return "speaker.slash.fill" }
        if v < 0.33 { return "speaker.wave.1.fill" }
        if v < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
