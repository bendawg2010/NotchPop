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

    /// Bump display brightness up or down by one step. macOS doesn't
    /// expose brightness keys as ordinary keyboard keys — they're
    /// system-defined HID events with NX_KEYTYPE codes. The previous
    /// version (CGEvent.keyboardEvent virtualKey 144/145) wrote
    /// keyboard key 144/145 which... isn't a thing, so nothing
    /// happened. User report: "brightness thing either" doesn't work.
    ///
    /// Fix: NSEvent.otherEvent(systemDefined) with subtype 8 and
    /// data1 packed as `(keyCode << 16) | flags`, where keyCode is
    /// NX_KEYTYPE_BRIGHTNESS_UP (0x90) or NX_KEYTYPE_BRIGHTNESS_DOWN
    /// (0x91), flags is 0xa00 for keydown and 0xb00 for keyup. This
    /// is the EXACT path the keyboard daemon uses when you press
    /// the F1/F2 keys.
    func nudgeBrightness(up: Bool) {
        // NX_KEYTYPE_BRIGHTNESS_UP = 0x90, _DOWN = 0x91.
        let keyType: Int32 = up ? 0x90 : 0x91
        // Flags byte: 0xa00 = keyDown, 0xb00 = keyUp.
        for flagWord in [0xa00, 0xb00] {
            let data1: Int = (Int(keyType) << 16) | flagWord
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1)
            // Post via cghidEventTap so it lands in the same queue
            // the system keyboard daemon would post into.
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
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
