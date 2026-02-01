//
//  HistoryView.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: WorkoutHistoryStore
    @ObservedObject var tabReselect: TabReselectCoordinator

    @State private var path: [WorkoutHistoryItem] = []

    private enum ScrollAnchor {
        static let top = "historyTop"
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                List {
                    Color.clear
                        .frame(height: 1)
                        .id(ScrollAnchor.top)
                        .accessibilityHidden(true)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)

                    ForEach(store.workouts) { workout in
                        NavigationLink(value: workout) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.name)
                                    .font(.body.weight(.medium))

                                Text(workout.date, format: .dateTime.year().month().day())
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
                .navigationTitle("History")
                .onChange(of: tabReselect.historyReselectCount) { _, _ in
                    if !path.isEmpty {
                        path.removeAll()
                    } else {
                        withAnimation(.snappy) {
                            proxy.scrollTo(ScrollAnchor.top, anchor: .top)
                        }
                    }
                }
            }
            .navigationDestination(for: WorkoutHistoryItem.self) { workout in
                WorkoutEditorPlaceholderScreen(entryPoint: .editHistoryWorkout(workout))
            }
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView(store: WorkoutHistoryStore(), tabReselect: TabReselectCoordinator())
    }
}

