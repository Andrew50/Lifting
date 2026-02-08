//
//  Stores.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import Combine
import Foundation
import GRDB

@MainActor
final class TemplateStore: ObservableObject {
    @Published private(set) var templates: [TemplateSummary] = []

    private let dbQueue: DatabaseQueue
    private var cancellable: AnyCancellable?

    init(db: AppDatabase) {
        self.dbQueue = db.dbQueue
        startObservingTemplates()
    }

    private func startObservingTemplates() {
        let observation = ValueObservation.tracking { db in
            try TemplateRecord
                .order(Column("updated_at").desc, Column("created_at").desc)
                .fetchAll(db)
                .map { TemplateSummary(id: $0.id, name: $0.name) }
        }

        cancellable =
            observation
            .publisher(in: dbQueue)
            .receive(on: DispatchQueue.main)
            .replaceError(with: [])
            .sink { [weak self] summaries in
                self?.templates = summaries
            }
    }

    func createTemplate(name: String) throws -> String {
        let now = Date().timeIntervalSince1970
        let template = TemplateRecord(
            id: UUID().uuidString,
            name: name,
            createdAt: now,
            updatedAt: now
        )

        try dbQueue.write { db in
            try template.insert(db)
        }

        return template.id
    }

    func updateTemplateName(templateId: String, name: String) throws {
        let now = Date().timeIntervalSince1970
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE templates
                    SET name = ?, updated_at = ?
                    WHERE id = ?
                    """,
                arguments: [name, now, templateId]
            )
        }
    }

    func deleteTemplate(templateId: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM templates WHERE id = ?",
                arguments: [templateId]
            )
        }
    }

    func fetchTemplate(templateId: String) throws -> TemplateRecord? {
        try dbQueue.read { db in
            try TemplateRecord.fetchOne(db, key: templateId)
        }
    }

    func fetchTemplateExercises(templateId: String) throws -> [TemplateExerciseDetail] {
        try dbQueue.read { db in
            let sql = """
                SELECT
                  te.id AS id,
                  te.exercise_id AS exerciseId,
                  e.name AS exerciseName,
                  te.sort_order AS sortOrder,
                  te.planned_sets_count AS plannedSetsCount
                FROM template_exercises te
                JOIN exercises e ON e.id = te.exercise_id
                WHERE te.template_id = ?
                ORDER BY te.sort_order ASC
                """

            return try Row.fetchAll(db, sql: sql, arguments: [templateId]).map { row in
                TemplateExerciseDetail(
                    id: row["id"],
                    exerciseId: row["exerciseId"],
                    exerciseName: row["exerciseName"],
                    sortOrder: row["sortOrder"],
                    plannedSetsCount: row["plannedSetsCount"]
                )
            }
        }
    }

    func addTemplateExercise(templateId: String, exerciseId: String) throws {
        let now = Date().timeIntervalSince1970
        try dbQueue.write { db in
            let nextOrder: Int =
                try Int.fetchOne(
                    db,
                    sql:
                        "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM template_exercises WHERE template_id = ?",
                    arguments: [templateId]
                ) ?? 0

            let row = TemplateExerciseRecord(
                id: UUID().uuidString,
                templateId: templateId,
                exerciseId: exerciseId,
                sortOrder: nextOrder,
                plannedSetsCount: 3
            )
            try row.insert(db)

            try db.execute(
                sql: "UPDATE templates SET updated_at = ? WHERE id = ?",
                arguments: [now, templateId]
            )
        }
    }

    func updatePlannedSets(templateExerciseId: String, plannedSetsCount: Int) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE template_exercises SET planned_sets_count = ? WHERE id = ?",
                arguments: [plannedSetsCount, templateExerciseId]
            )
        }
    }

    func deleteTemplateExercise(templateExerciseId: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM template_exercises WHERE id = ?",
                arguments: [templateExerciseId]
            )
        }
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var workouts: [WorkoutSummary] = []

    private let dbQueue: DatabaseQueue
    private var cancellable: AnyCancellable?

    init(db: AppDatabase) {
        self.dbQueue = db.dbQueue
        startObservingHistory()
    }

    private func startObservingHistory() {
        let observation = ValueObservation.tracking { db in
            let records =
                try WorkoutRecord
                .filter(WorkoutRecord.Columns.status == WorkoutStatus.completed.rawValue)
                .order(WorkoutRecord.Columns.completedAt.desc, WorkoutRecord.Columns.startedAt.desc)
                .fetchAll(db)

            return try records.compactMap { workout -> WorkoutSummary? in
                guard let completedAt = workout.completedAt else { return nil }

                let exercisesSql = """
                    SELECT
                        we.id,
                        e.name,
                        (SELECT COUNT(*) FROM workout_sets ws WHERE ws.workout_exercise_id = we.id) as setsCount
                    FROM workout_exercises we
                    JOIN exercises e ON e.id = we.exercise_id
                    WHERE we.workout_id = ?
                    ORDER BY we.sort_order ASC
                    """

                let exercises = try Row.fetchAll(db, sql: exercisesSql, arguments: [workout.id]).map
                { row in
                    WorkoutExerciseSummary(
                        id: row["id"],
                        name: row["name"],
                        setsCount: row["setsCount"]
                    )
                }

                return WorkoutSummary(
                    id: workout.id,
                    name: workout.name,
                    completedAt: Date(timeIntervalSince1970: completedAt),
                    duration: completedAt - workout.startedAt,
                    exercises: exercises
                )
            }
        }

        cancellable =
            observation
            .publisher(in: dbQueue)
            .receive(on: DispatchQueue.main)
            .replaceError(with: [])
            .sink { [weak self] summaries in
                self?.workouts = summaries
            }
    }
}

@MainActor
final class WorkoutStore: ObservableObject {
    private let dbQueue: DatabaseQueue

    init(db: AppDatabase) {
        self.dbQueue = db.dbQueue
    }

    func fetchPendingWorkoutID() throws -> String? {
        try dbQueue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT id FROM workouts WHERE status = 0 LIMIT 1"
            )
        }
    }

    /// Default workout name based on time of day: "Morning Workout", "Afternoon Workout", or "Evening Workout".
    static func defaultWorkoutName(for date: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour < 12 { return "Morning Workout" }
        if hour < 18 { return "Afternoon Workout" }
        return "Evening Workout"
    }

    /// Creates a new blank pending workout if none exists; otherwise returns the existing pending workout id.
    func startOrResumePendingWorkout() throws -> String {
        if let existing = try fetchPendingWorkoutID() {
            return existing
        }

        let now = Date().timeIntervalSince1970
        let workout = WorkoutRecord(
            id: UUID().uuidString,
            name: Self.defaultWorkoutName(for: Date()),
            status: .pending,
            sourceTemplateId: nil,
            startedAt: now,
            completedAt: nil,
            notes: nil,
            createdAt: now,
            updatedAt: now
        )

        try dbQueue.write { db in
            try workout.insert(db)
        }

        return workout.id
    }

    /// Creates a new pending workout copied from a template. If a pending workout already exists, returns it.
    func startPendingWorkout(fromTemplate templateId: String) throws -> String {
        if let existing = try fetchPendingWorkoutID() {
            return existing
        }

        return try dbQueue.write { db in
            let now = Date().timeIntervalSince1970

            let workout = WorkoutRecord(
                id: UUID().uuidString,
                name: Self.defaultWorkoutName(for: Date()),
                status: .pending,
                sourceTemplateId: templateId,
                startedAt: now,
                completedAt: nil,
                notes: nil,
                createdAt: now,
                updatedAt: now
            )
            try workout.insert(db)

            // Copy exercises
            let templateExercises =
                try TemplateExerciseRecord
                .filter(TemplateExerciseRecord.Columns.templateId == templateId)
                .order(TemplateExerciseRecord.Columns.sortOrder.asc)
                .fetchAll(db)

            for te in templateExercises {
                let we = WorkoutExerciseRecord(
                    id: UUID().uuidString,
                    workoutId: workout.id,
                    exerciseId: te.exerciseId,
                    sortOrder: te.sortOrder
                )
                try we.insert(db)

                let count = max(0, te.plannedSetsCount)
                for i in 0..<count {
                    let set = WorkoutSetRecord(
                        id: UUID().uuidString,
                        workoutExerciseId: we.id,
                        sortOrder: i,
                        weight: nil,
                        reps: nil,
                        rir: nil,
                        isWarmUp: nil
                    )
                    try set.insert(db)
                }
            }

            return workout.id
        }
    }

    func completeWorkout(workoutId: String) throws {
        let now = Date().timeIntervalSince1970
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE workouts
                    SET status = 1, completed_at = ?, updated_at = ?
                    WHERE id = ? AND status = 0
                    """,
                arguments: [now, now, workoutId]
            )
        }
    }

    func discardPendingWorkout(workoutId: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM workouts WHERE id = ? AND status = 0",
                arguments: [workoutId]
            )
        }
    }

    func fetchWorkout(workoutId: String) throws -> WorkoutRecord? {
        try dbQueue.read { db in
            try WorkoutRecord.fetchOne(db, key: workoutId)
        }
    }

    func fetchWorkoutExercises(workoutId: String) throws -> [WorkoutExerciseDetail] {
        try dbQueue.read { db in
            let sql = """
                SELECT
                  we.id AS id,
                  we.exercise_id AS exerciseId,
                  e.name AS exerciseName,
                  we.sort_order AS sortOrder
                FROM workout_exercises we
                JOIN exercises e ON e.id = we.exercise_id
                WHERE we.workout_id = ?
                ORDER BY we.sort_order ASC
                """

            let exerciseRows = try Row.fetchAll(db, sql: sql, arguments: [workoutId])

            return try exerciseRows.map { row in
                let workoutExerciseId: String = row["id"]
                let sets =
                    try WorkoutSetRecord
                    .filter(WorkoutSetRecord.Columns.workoutExerciseId == workoutExerciseId)
                    .order(WorkoutSetRecord.Columns.sortOrder.asc)
                    .fetchAll(db)
                    .map { s in
                        WorkoutSetDetail(
                            id: s.id,
                            sortOrder: s.sortOrder,
                            weight: s.weight,
                            reps: s.reps,
                            rir: s.rir,
                            isWarmUp: s.isWarmUp
                        )
                    }

                return WorkoutExerciseDetail(
                    id: workoutExerciseId,
                    exerciseId: row["exerciseId"],
                    exerciseName: row["exerciseName"],
                    sortOrder: row["sortOrder"],
                    sets: sets
                )
            }
        }
    }

    func addWorkoutExercise(workoutId: String, exerciseId: String) throws {
        let now = Date().timeIntervalSince1970
        try dbQueue.write { db in
            let nextOrder: Int =
                try Int.fetchOne(
                    db,
                    sql:
                        "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM workout_exercises WHERE workout_id = ?",
                    arguments: [workoutId]
                ) ?? 0

            let we = WorkoutExerciseRecord(
                id: UUID().uuidString,
                workoutId: workoutId,
                exerciseId: exerciseId,
                sortOrder: nextOrder
            )
            try we.insert(db)

            // Default 1 empty set for new exercise
            let set = WorkoutSetRecord(
                id: UUID().uuidString,
                workoutExerciseId: we.id,
                sortOrder: 0,
                weight: nil,
                reps: nil,
                rir: nil,
                isWarmUp: nil
            )
            try set.insert(db)

            try db.execute(
                sql: "UPDATE workouts SET updated_at = ? WHERE id = ?",
                arguments: [now, workoutId]
            )
        }
    }

    func addSet(workoutExerciseId: String) throws {
        try dbQueue.write { db in
            let nextOrder: Int =
                try Int.fetchOne(
                    db,
                    sql:
                        "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM workout_sets WHERE workout_exercise_id = ?",
                    arguments: [workoutExerciseId]
                ) ?? 0

            let set = WorkoutSetRecord(
                id: UUID().uuidString,
                workoutExerciseId: workoutExerciseId,
                sortOrder: nextOrder,
                weight: nil,
                reps: nil,
                rir: nil,
                isWarmUp: nil
            )
            try set.insert(db)
        }
    }

    func deleteSet(setId: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM workout_sets WHERE id = ?",
                arguments: [setId]
            )
        }
    }

    func deleteWorkoutExercise(workoutExerciseId: String) throws {
        let now = Date().timeIntervalSince1970
        try dbQueue.write { db in
            let workoutId: String? = try String.fetchOne(
                db,
                sql: "SELECT workout_id FROM workout_exercises WHERE id = ?",
                arguments: [workoutExerciseId]
            )

            try db.execute(
                sql: "DELETE FROM workout_exercises WHERE id = ?",
                arguments: [workoutExerciseId]
            )

            if let workoutId {
                try db.execute(
                    sql: "UPDATE workouts SET updated_at = ? WHERE id = ?",
                    arguments: [now, workoutId]
                )
            }
        }
    }

    func updateSet(setId: String, weight: Double?, reps: Int?, rir: Double?, isWarmUp: Bool? = nil)
        throws
    {
        try dbQueue.write { db in
            let warmUpInt: Int? = isWarmUp.map { $0 ? 1 : 0 }
            try db.execute(
                sql: """
                    UPDATE workout_sets
                    SET weight = ?, reps = ?, rir = ?, is_warm_up = ?
                    WHERE id = ?
                    """,
                arguments: [weight, reps, rir, warmUpInt, setId]
            )
        }
    }

    /// All performed sets for an exercise across completed workouts, newest first.
    func fetchExerciseHistory(exerciseId: String) throws -> [ExerciseHistorySetEntry] {
        try dbQueue.read { db in
            let sql = """
                SELECT
                  ws.id AS id,
                  w.id AS workoutId,
                  w.name AS workoutName,
                  w.completed_at AS completedAt,
                  ws.sort_order AS sortOrder,
                  ws.weight AS weight,
                  ws.reps AS reps,
                  ws.rir AS rir,
                  ws.is_warm_up AS isWarmUp
                FROM workout_sets ws
                JOIN workout_exercises we ON we.id = ws.workout_exercise_id
                JOIN workouts w ON w.id = we.workout_id
                WHERE we.exercise_id = ? AND w.status = 1 AND w.completed_at IS NOT NULL
                ORDER BY w.completed_at DESC, ws.sort_order ASC
                """
            return try Row.fetchAll(db, sql: sql, arguments: [exerciseId]).map { row in
                let completedAt: TimeInterval = row["completedAt"] ?? 0
                let isWarmUp: Bool? = (row["isWarmUp"] as Int?).map { $0 != 0 }
                return ExerciseHistorySetEntry(
                    id: row["id"],
                    workoutId: row["workoutId"],
                    workoutName: row["workoutName"],
                    completedAt: Date(timeIntervalSince1970: completedAt),
                    sortOrder: row["sortOrder"],
                    weight: row["weight"],
                    reps: row["reps"],
                    rir: row["rir"],
                    isWarmUp: isWarmUp
                )
            }
        }
    }

    func updateWorkoutName(workoutId: String, name: String) throws {
        let now = Date().timeIntervalSince1970
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE workouts SET name = ?, updated_at = ? WHERE id = ?",
                arguments: [name, now, workoutId]
            )
        }
    }

    func updateWorkoutNotes(workoutId: String, notes: String?) throws {
        let now = Date().timeIntervalSince1970
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE workouts SET notes = ?, updated_at = ? WHERE id = ?",
                arguments: [notes, now, workoutId]
            )
        }
    }

    func deleteWorkout(workoutId: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM workouts WHERE id = ?",
                arguments: [workoutId]
            )
        }
    }
}

@MainActor
final class ExerciseStore: ObservableObject {
    @Published private(set) var exercises: [ExerciseRecord] = []

    private let dbQueue: DatabaseQueue

    init(db: AppDatabase) {
        self.dbQueue = db.dbQueue
    }

    func loadAll() async {
        do {
            let result = try await dbQueue.read { db in
                try ExerciseRecord.order(ExerciseRecord.Columns.name.asc).fetchAll(db)
            }
            exercises = result
        } catch {
            exercises = []
        }
    }
}
