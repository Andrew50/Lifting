//
//  ExercisePickerView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

struct ExercisePickerView: View {
    @ObservedObject var exerciseStore: ExerciseStore
    let onSelect: (ExerciseRecord) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeForFuzzySearch(_ input: String) -> String {
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
    private func fuzzyScore(query rawQuery: String, candidate rawCandidate: String) -> Int? {
        let query = normalizeForFuzzySearch(rawQuery)
        guard !query.isEmpty else { return 0 }

        let candidate = normalizeForFuzzySearch(rawCandidate)
        guard !candidate.isEmpty else { return nil }

        // Fast path: contiguous substring match should float to the top.
        if let range = candidate.range(of: query) {
            let start = candidate.distance(from: candidate.startIndex, to: range.lowerBound)
            // Earlier matches and shorter candidates rank higher.
            return 10_000 - (start * 20) - candidate.count
        }

        let candidateChars = Array(candidate)

        // All query terms must match (order-independent), but scoring still rewards word boundaries and adjacency.
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

        return total
    }

    private var filteredExercises: [ExerciseRecord] {
        let query = trimmedQuery
        guard !query.isEmpty else { return exerciseStore.exercises }

        return exerciseStore.exercises
            .compactMap { exercise -> (exercise: ExerciseRecord, score: Int)? in
                guard let score = fuzzyScore(query: query, candidate: exercise.name) else { return nil }
                return (exercise, score)
            }
            .sorted { a, b in
                if a.score != b.score { return a.score > b.score }
                return a.exercise.name.localizedCaseInsensitiveCompare(b.exercise.name) == .orderedAscending
            }
            .map(\.exercise)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search exercises", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !trimmedQuery.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.thickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List(filteredExercises) { exercise in
                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    Text(exercise.name)
                }
            }
        }
        .navigationTitle("Add Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if exerciseStore.exercises.isEmpty {
                await exerciseStore.loadAll()
            }
        }
    }
}

