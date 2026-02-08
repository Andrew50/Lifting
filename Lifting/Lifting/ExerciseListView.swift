//
//  ExerciseListView.swift
//  Lifting
//

import SwiftUI

struct ExerciseListView: View {
    @ObservedObject var container: AppContainer
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
                return " "
            }
            .reduce(into: "") { out, ch in
                if ch == " ", out.last == " " { return }
                out.append(ch)
            }
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fuzzyScore(query rawQuery: String, candidate rawCandidate: String) -> Int? {
        let query = normalizeForFuzzySearch(rawQuery)
        guard !query.isEmpty else { return 0 }

        let candidate = normalizeForFuzzySearch(rawCandidate)
        guard !candidate.isEmpty else { return nil }

        if let range = candidate.range(of: query) {
            let start = candidate.distance(from: candidate.startIndex, to: range.lowerBound)
            return 10_000 - (start * 20) - candidate.count
        }

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
                while cIndex < candidateChars.count, candidateChars[cIndex] != t { cIndex += 1 }
                if cIndex >= candidateChars.count { return nil }
                score += 25
                if cIndex == 0 || candidateChars[cIndex - 1] == " " { score += 40 }
                if cIndex == lastMatch + 1 { score += 30 }
                score += max(0, 30 - cIndex)
                lastMatch = cIndex
                cIndex += 1
            }
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
        guard !query.isEmpty else { return container.exerciseStore.exercises }

        return container.exerciseStore.exercises
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
                NavigationLink(value: exercise) {
                    Text(exercise.name)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Exercises")
        .navigationDestination(for: ExerciseRecord.self) { exercise in
            ExerciseHistoryView(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                workoutStore: container.workoutStore
            )
        }
        .task {
            if container.exerciseStore.exercises.isEmpty {
                await container.exerciseStore.loadAll()
            }
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseListView(container: AppContainer())
    }
}
