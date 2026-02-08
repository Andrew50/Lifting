//
//  ExerciseSearch.swift
//  Lifting
//

import Foundation

struct ExerciseSearch {
    static func normalizeForFuzzySearch(_ input: String) -> String {
        input
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .map { ch in
                if ch.isLetter || ch.isNumber { return ch }
                if ch == " " { return ch }
                // Treat punctuation like separators so "incline-bench" still matches "incline bench"
                return " "
            }
            .reduce(into: "") { out, ch in
                // Collapse repeated spaces
                if ch == " ", out.last == " " { return }
                out.append(ch)
            }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns a score where larger is a better match. `nil` means "no match".
    /// Incorporates frequency into the score.
    static func fuzzyScore(
        query rawQuery: String,
        candidate rawCandidate: String,
        frequency: Int = 0,
        frequencyWeight: Double = 0.2 // Configurable balance
    ) -> Int? {
        let query = normalizeForFuzzySearch(rawQuery)
        guard !query.isEmpty else { return 0 }

        let candidate = normalizeForFuzzySearch(rawCandidate)
        guard !candidate.isEmpty else { return nil }

        var baseScore: Int
        
        // Fast path: contiguous substring match should float to the top.
        if let range = candidate.range(of: query) {
            let start = candidate.distance(from: candidate.startIndex, to: range.lowerBound)
            // Earlier matches and shorter candidates rank higher.
            baseScore = 10_000 - (start * 20) - candidate.count
        } else {
            let candidateChars = Array(candidate)
            let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
            guard !terms.isEmpty else { return nil }

            func scoreTerm(_ term: String) -> Int? {
                let termChars = Array(term)
                guard !termChars.isEmpty else { return 0 }

                var score = 0
                var cIndex = 0
                var lastMatch = -10

                for t in termChars {
                    while cIndex < candidateChars.count, candidateChars[cIndex] != t {
                        cIndex += 1
                    }
                    if cIndex >= candidateChars.count { return nil }

                    // Base points per matched character
                    score += 25

                    // Bonus for matching at word boundary (start or preceded by space)
                    if cIndex == 0 || candidateChars[cIndex - 1] == " " {
                        score += 40
                    }

                    // Bonus for consecutive characters (prefer tighter matches)
                    if cIndex == lastMatch + 1 {
                        score += 30
                    }

                    // Slight bonus for earlier matches
                    score += max(0, 30 - cIndex)

                    lastMatch = cIndex
                    cIndex += 1
                }

                // Small penalty for very long candidate strings.
                score -= max(0, candidateChars.count - termChars.count)
                return score
            }

            var total = 0
            for term in terms {
                guard let termScore = scoreTerm(term) else { return nil }
                total += termScore
            }
            baseScore = total
        }
        
        // Add frequency bonus
        // We use a logarithmic scaling for frequency so that 100 uses doesn't completely overwhelm the search score
        // but still provides a significant boost.
        let frequencyBonus = Int(Double(baseScore) * frequencyWeight * log2(Double(frequency + 1)))
        
        return baseScore + frequencyBonus
    }
}
