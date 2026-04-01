import SwiftUI

struct ExerciseListView: View {
    @State private var exercises: [String] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading exercises...")
                        .padding()
                } else if exercises.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("No exercises found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        Text("Check your database setup")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        Section {
                            Text("Total: \(exercises.count) exercises")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        ForEach(exercises, id: \.self) { exercise in
                            HStack {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .foregroundColor(.blue)
                                Text(exercise)
                                    .font(.body)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        loadExercises()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                loadExercises()
            }
        }
    }
    
    func loadExercises() {
        isLoading = true
        
        // Small delay to show loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            exercises = ExerciseDatabase.shared.getAllExercises()
            isLoading = false
            
            print("Loaded \(exercises.count) exercises for display")
        }
    }
}

#Preview {
    ExerciseListView()
}