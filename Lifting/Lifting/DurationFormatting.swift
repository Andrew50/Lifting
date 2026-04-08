//
//  DurationFormatting.swift
//  Lifting
//

import Foundation

extension Int {
    /// Formats a seconds count as "M:SS" (e.g. 90 → "1:30").
    var formattedAsMinutesSeconds: String {
        String(format: "%d:%02d", self / 60, self % 60)
    }
}

extension TimeInterval {
    /// Formats a duration as "H:MM:SS" or "M:SS", dropping hours when zero.
    var formattedDuration: String {
        let total = Int(self)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formats elapsed time since a start timestamp as "M:SS".
    static func elapsed(since startedAt: TimeInterval?) -> String {
        guard let start = startedAt else { return "0:00" }
        let total = max(0, Int(Date().timeIntervalSince1970 - start))
        return total.formattedAsMinutesSeconds
    }
}
