//
//  CommonExerciseSearchView.swift
//  Lifting
//

import SwiftUI

struct CommonExerciseSearchView: View {
    @ObservedObject var exerciseStore: ExerciseStore
    let onSelect: (ExerciseRecord) -> Void
    var navigationTitle: String = "Exercises"
    var showFrequency: Bool = true
    
    // Balance between fuzzy match and frequency (0.0 to 1.0)
    // 0.0 means ignore frequency, 1.0 means frequency has heavy influence
    var frequencyWeight: Double = 0.2

    @State private var searchText: String = ""

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredExercises: [ExerciseRecord] {
        let query = trimmedQuery
        if query.isEmpty {
            // If no query, sort by frequency then name
            return exerciseStore.exercises.sorted { a, b in
                let freqA = exerciseStore.exerciseFrequencies[a.id] ?? 0
                let freqB = exerciseStore.exerciseFrequencies[b.id] ?? 0
                if freqA != freqB { return freqA > freqB }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }

        return exerciseStore.exercises
            .compactMap { exercise -> (exercise: ExerciseRecord, score: Int)? in
                let freq = exerciseStore.exerciseFrequencies[exercise.id] ?? 0
                guard let score = ExerciseSearch.fuzzyScore(
                    query: query,
                    candidate: exercise.name,
                    frequency: freq,
                    frequencyWeight: frequencyWeight
                ) else { return nil }
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
            searchBar
            
            List(filteredExercises) { exercise in
                Button {
                    onSelect(exercise)
                } label: {
                    HStack {
                        Text(exercise.name)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        if showFrequency {
                            let count = exerciseStore.exerciseFrequencies[exercise.id] ?? 0
                            if count > 0 {
                                Text("\(count)×")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
        .navigationTitle(navigationTitle)
        .task {
            await exerciseStore.loadAll()
        }
    }
    
    private var searchBar: some View {
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
    }
}
