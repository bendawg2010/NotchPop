// ArraySafeIndex.swift
//
// Add a `[safe:]` subscript on Array that returns nil instead of
// trapping when the index is out of bounds. Used by the World Clock
// timezone picker because the user's free-text search filters the
// list while the stored selection index is into the FULL list —
// when the filter excludes the currently-selected timezone we
// gracefully render "—" instead of crashing.

import Foundation

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
