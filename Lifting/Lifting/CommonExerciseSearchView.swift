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
                let searchableText =
                    "\(exercise.name) \(exercise.equipment) \(exercise.muscleGroup)"
                guard
                    let score = ExerciseSearch.fuzzyScore(
                        query: query,
                        candidate: searchableText,
                        frequency: freq,
                        frequencyWeight: frequencyWeight
                    )
                else { return nil }
                return (exercise, score)
            }
            .sorted { a, b in
                if a.score != b.score { return a.score > b.score }
                return a.exercise.name.localizedCaseInsensitiveCompare(b.exercise.name)
                    == .orderedAscending
            }
            .map(\.exercise)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredExercises.enumerated()), id: \.element.id) { index, exercise in
                        Button {
                            onSelect(exercise)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(exercise.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    HStack(spacing: 6) {
                                        categoryChip(text: exercise.equipment.capitalized)
                                        categoryChip(text: exercise.muscleGroup.capitalized)
                                    }
                                }
                                Spacer()

                                if showFrequency {
                                    let count = exerciseStore.exerciseFrequencies[exercise.id] ?? 0
                                    if count > 0 {
                                        Text("\(count)×")
                                            .font(.system(size: 11, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppTheme.accentLight)
                                            .foregroundStyle(AppTheme.accentText)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < filteredExercises.count - 1 {
                            Divider()
                                .overlay(AppTheme.fieldBorder)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
        }
        .background(AppTheme.background)
        .navigationTitle(navigationTitle)
        .task {
            await exerciseStore.loadAll()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.textTertiary)

            TextField("Search exercises", text: $searchText)
                .foregroundStyle(AppTheme.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !trimmedQuery.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.fieldBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private func categoryChip(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppTheme.fieldBackground)
            .foregroundStyle(AppTheme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
