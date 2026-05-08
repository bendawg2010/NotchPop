// TimerSound.swift
//
// Centralizes the "play a sound when a timer ends" logic so the
// Pomodoro and Countdown services don't each implement it slightly
// differently. Reads the user's choice from UserDefaults so we don't
// need to thread a NotchViewModel reference through every service:
//
//   np.sound                 (Bool) — master toggle, default true
//   np.timerSoundName        (String) — system sound name; default "Glass"
//
// macOS bundles a handful of named sounds at /System/Library/Sounds/.
// NSSound(named:) returns one of those by name. We also support the
// special name "Beep" which falls back to NSSound.beep() (the system
// alert sound the user has globally configured in Sound settings).

import AppKit

enum TimerSound {
    /// Built-in choices we expose in Settings → Pomodoro. Each one
    /// is either a name in /System/Library/Sounds/ OR our pseudo
    /// "Beep" entry that defers to the user's system alert sound.
    static let choices: [String] = [
        "Beep",
        "Glass",
        "Submarine",
        "Bell",
        "Hero",
        "Funk",
        "Frog",
        "Pop",
        "Sosumi",
        "Tink",
        "Ping",
        "Purr",
    ]

    static let defaultChoice = "Glass"

    /// Play whatever the user picked, IF the master sound toggle is on.
    /// No-op otherwise. Safe to call from any thread — NSSound dispatches
    /// playback to the audio system internally.
    static func play() {
        let d = UserDefaults.standard
        let enabled: Bool
        if d.object(forKey: "np.sound") != nil {
            enabled = d.bool(forKey: "np.sound")
        } else {
            enabled = true   // default = on
        }
        guard enabled else { return }

        let name = d.string(forKey: "np.timerSoundName") ?? defaultChoice
        playRaw(name: name)
    }

    /// Play a sound by name regardless of the master toggle. Used by
    /// the "Preview" button in Settings — clicking that should always
    /// produce sound, even if the user has temporarily muted alerts.
    static func playRaw(name: String) {
        if name == "Beep" {
            NSSound.beep()
            return
        }
        if let snd = NSSound(named: NSSound.Name(name)) {
            snd.stop()        // restart from the beginning if mid-play
            snd.play()
        } else {
            // Fall back to system beep if the named sound isn't installed.
            NSSound.beep()
        }
    }
}
