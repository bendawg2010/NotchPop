// NotesService.swift
//
// Backing store for the "Quick Notes" pane. Single string of free-form
// text that auto-saves to UserDefaults under "np.notes.text" with a
// 600ms Combine debounce so we don't thrash disk on every keystroke.
// Restores on init; clear() wipes the buffer.

import Combine
import Foundation

final class NotesService: ObservableObject {
    @Published var text: String

    private static let storageKey = "np.notes.text"
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Restore from UserDefaults synchronously so the first render
        // already shows the user's last note.
        self.text = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""

        // Auto-save on change, debounced. dropFirst() so the restore
        // value we just assigned doesn't trigger an immediate write.
        $text
            .dropFirst()
            .debounce(for: .milliseconds(600), scheduler: DispatchQueue.main)
            .sink { value in
                UserDefaults.standard.set(value, forKey: Self.storageKey)
            }
            .store(in: &cancellables)
    }

    /// Empty the note. Persists immediately rather than waiting for
    /// the debounce so a clear feels instant if the app is killed.
    func clear() {
        text = ""
        UserDefaults.standard.set("", forKey: Self.storageKey)
    }
}
