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
    @Published private(set) var canLoadMore: Bool = true

    private let dbQueue: DatabaseQueue
    private var cancellable: AnyCancellable?
    private var currentLimit: Int = 20
    private let pageSize: Int = 20

    init(db: AppDatabase) {
        self.dbQueue = db.dbQueue
        startObservingHistory()
    }

    func loadMore() {
        guard canLoadMore else { return }
        currentLimit += pageSize
        startObservingHistory()
    }

    private func startObservingHistory() {
        let limit = currentLimit
        let observation = ValueObservation.tracking { db in
            let totalCount = try WorkoutRecord
                .filter(WorkoutRecord.Columns.status == WorkoutStatus.completed.rawValue)
                .fetchCount(db)

            let records =
                try WorkoutRecord
                .filter(WorkoutRecord.Columns.status == WorkoutStatus.completed.rawValue)
                .order(WorkoutRecord.Columns.completedAt.desc, WorkoutRecord.Columns.startedAt.desc)
                .limit(limit)
                .fetchAll(db)

            let workoutIds = records.map { $0.id }
            if workoutIds.isEmpty { return ([WorkoutSummary](), false) }

            // Batch fetch exercise summaries for these workouts
            let placeholders = workoutIds.map { _ in "?" }.joined(separator: ",")
            let exercisesSql = """
                SELECT
                    we.workout_id,
                    we.id,
                    e.name,
                    (SELECT COUNT(*) FROM workout_sets ws WHERE ws.workout_exercise_id = we.id) as setsCount
                FROM workout_exercises we
                JOIN exercises e ON e.id = we.exercise_id
                WHERE we.workout_id IN (\(placeholders))
                ORDER BY we.sort_order ASC
                """
            let allExercises = try Row.fetchAll(
                db, sql: exercisesSql, arguments: StatementArguments(workoutIds))
            let exercisesByWorkoutId = Dictionary(grouping: allExercises, by: { $0["workout_id"] as String })

            let summaries = records.compactMap { workout -> WorkoutSummary? in
                guard let completedAt = workout.completedAt else { return nil }

                let exercises = (exercisesByWorkoutId[workout.id] ?? []).map { row in
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

            return (summaries, totalCount > limit)
        }

        cancellable =
            observation
            .publisher(in: dbQueue)
            .receive(on: DispatchQueue.main)
            .replaceError(with: ([], false))
            .sink { [weak self] summaries, hasMore in
                self?.workouts = summaries
                self?.canLoadMore = hasMore
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
    nonisolated static func defaultWorkoutName(for date: Date = Date()) -> String {
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
    /// Sets are pre-filled from each exercise's last completed workout when available.
    func startPendingWorkout(fromTemplate templateId: String) throws -> String {
        if let existing = try fetchPendingWorkoutID() {
            return existing
        }

        // Read phase: template exercises and last completed sets per exercise
        let templateExercises = try dbQueue.read { db in
            try TemplateExerciseRecord
                .filter(TemplateExerciseRecord.Columns.templateId == templateId)
                .order(TemplateExerciseRecord.Columns.sortOrder.asc)
                .fetchAll(db)
        }
        let exerciseIds = templateExercises.map(\.exerciseId)
        let lastSetsByExercise = try fetchLastCompletedSetsByExercise(exerciseIds: exerciseIds)

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

            for te in templateExercises {
                let we = WorkoutExerciseRecord(
                    id: UUID().uuidString,
                    workoutId: workout.id,
                    exerciseId: te.exerciseId,
                    sortOrder: te.sortOrder
                )
                try we.insert(db)

                let count = max(0, te.plannedSetsCount)
                let previousSets = lastSetsByExercise[te.exerciseId] ?? []
                for i in 0..<count {
                    let prev = previousSets.indices.contains(i) ? previousSets[i] : nil
                    let set = WorkoutSetRecord(
                        id: UUID().uuidString,
                        workoutExerciseId: we.id,
                        sortOrder: i,
                        weight: prev?.weight,
                        reps: prev?.reps,
                        distance: nil,
                        seconds: nil,
                        notes: nil,
                        rpe: nil,
                        rir: prev?.rir,
                        isWarmUp: prev?.isWarmUp,
                        restTimerSeconds: prev?.restTimerSeconds
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
            // Discard empty sets
            let emptySetsSql = """
                DELETE FROM workout_sets 
                WHERE id IN (
                    SELECT ws.id 
                    FROM workout_sets ws
                    JOIN workout_exercises we ON we.id = ws.workout_exercise_id
                    WHERE we.workout_id = ? AND (ws.weight IS NULL OR ws.reps IS NULL)
                )
                """
            try db.execute(sql: emptySetsSql, arguments: [workoutId])

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

    func countEmptySets(workoutId: String) throws -> Int {
        try dbQueue.read { db in
            let sql = """
                SELECT COUNT(*) 
                FROM workout_sets ws
                JOIN workout_exercises we ON we.id = ws.workout_exercise_id
                WHERE we.workout_id = ? AND (ws.weight IS NULL OR ws.reps IS NULL)
                """
            return try Int.fetchOne(db, sql: sql, arguments: [workoutId]) ?? 0
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
            let workoutExerciseIds = exerciseRows.map { $0["id"] as String }

            // Batch fetch all sets for these exercises
            let sets = try WorkoutSetRecord
                .filter(workoutExerciseIds.contains(WorkoutSetRecord.Columns.workoutExerciseId))
                .order(WorkoutSetRecord.Columns.sortOrder.asc)
                .fetchAll(db)

            let setsByExerciseId = Dictionary(grouping: sets, by: { $0.workoutExerciseId })

            return exerciseRows.map { row in
                let workoutExerciseId: String = row["id"]
                let exerciseSets = (setsByExerciseId[workoutExerciseId] ?? []).map { s in
                    let rpe = s.rpe ?? s.rir.map { 10 - $0 }
                    return WorkoutSetDetail(
                        id: s.id,
                        sortOrder: s.sortOrder,
                        weight: s.weight,
                        reps: s.reps,
                        rir: s.rir,
                        rpe: rpe,
                        isWarmUp: s.isWarmUp,
                        isCompleted: s.isCompleted,
                        restTimerSeconds: s.restTimerSeconds
                    )
                }

                return WorkoutExerciseDetail(
                    id: workoutExerciseId,
                    exerciseId: row["exerciseId"],
                    exerciseName: row["exerciseName"],
                    sortOrder: row["sortOrder"],
                    sets: exerciseSets
                )
            }
        }
    }

    /// Adds an exercise to a workout. Creates sets pre-filled from the exercise's last completed workout when available.
    func addWorkoutExercise(workoutId: String, exerciseId: String) throws {
        let previousSets = (try fetchLastCompletedSetsByExercise(exerciseIds: [exerciseId]))[exerciseId] ?? []

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

            if previousSets.isEmpty {
                let set = WorkoutSetRecord(
                    id: UUID().uuidString,
                    workoutExerciseId: we.id,
                    sortOrder: 0,
                    weight: nil,
                    reps: nil,
                    distance: nil,
                    seconds: nil,
                    notes: nil,
                    rpe: nil,
                    rir: nil,
                    isWarmUp: nil,
                    restTimerSeconds: nil
                )
                try set.insert(db)
            } else {
                for (i, prev) in previousSets.enumerated() {
                    let set = WorkoutSetRecord(
                        id: UUID().uuidString,
                        workoutExerciseId: we.id,
                        sortOrder: i,
                        weight: prev.weight,
                        reps: prev.reps,
                        distance: nil,
                        seconds: nil,
                        notes: nil,
                        rpe: nil,
                        rir: prev.rir,
                        isWarmUp: prev.isWarmUp,
                        restTimerSeconds: prev.restTimerSeconds
                    )
                    try set.insert(db)
                }
            }

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
                distance: nil,
                seconds: nil,
                notes: nil,
                rpe: nil,
                rir: nil,
                isWarmUp: nil,
                restTimerSeconds: nil
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

    /// Replace the exercise in a workout exercise slot, keeping the same position. Clears existing sets.
    func replaceWorkoutExercise(workoutExerciseId: String, newExerciseId: String) throws {
        let now = Date().timeIntervalSince1970
        try dbQueue.write { db in
            // Delete old sets
            try db.execute(
                sql: "DELETE FROM workout_sets WHERE workout_exercise_id = ?",
                arguments: [workoutExerciseId]
            )
            // Update exercise_id
            try db.execute(
                sql: "UPDATE workout_exercises SET exercise_id = ? WHERE id = ?",
                arguments: [newExerciseId, workoutExerciseId]
            )
            // Insert one empty set
            try db.execute(
                sql: """
                    INSERT INTO workout_sets (id, workout_exercise_id, sort_order, weight, reps, rir)
                    VALUES (?, ?, 0, NULL, NULL, NULL)
                    """,
                arguments: [UUID().uuidString, workoutExerciseId]
            )
            // Touch workout updated_at
            if let workoutId = try String.fetchOne(
                db,
                sql: "SELECT workout_id FROM workout_exercises WHERE id = ?",
                arguments: [workoutExerciseId])
            {
                try db.execute(
                    sql: "UPDATE workouts SET updated_at = ? WHERE id = ?",
                    arguments: [now, workoutId]
                )
            }
        }
    }

    func updateSet(
        setId: String,
        weight: Double?,
        reps: Int?,
        rir: Double? = nil,
        rpe: Double? = nil,
        isWarmUp: Bool? = nil,
        isCompleted: Bool? = nil,
        restTimerSeconds: Int? = nil
    ) throws {
        try dbQueue.write { db in
            if var set = try WorkoutSetRecord.fetchOne(db, key: setId) {
                if let weight { set.weight = weight }
                if let reps { set.reps = reps }
                if let rir { set.rir = rir }
                if let rpe {
                    set.rpe = rpe
                    set.rir = 10 - rpe
                }
                if let isWarmUp { set.isWarmUp = isWarmUp }
                if let isCompleted { set.isCompleted = isCompleted }
                if let restTimerSeconds { set.restTimerSeconds = restTimerSeconds }
                try set.update(db)
            }
        }
    }

    func toggleSetCompleted(setId: String, completed: Bool) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE workout_sets SET is_completed = ? WHERE id = ?",
                arguments: [completed ? 1 : 0, setId]
            )
        }
    }

    func clearSetRestTimer(setId: String) throws {
        try dbQueue.write { db in
            if var set = try WorkoutSetRecord.fetchOne(db, key: setId) {
                set.restTimerSeconds = nil
                try set.update(db)
            }
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
                  w.started_at AS startedAt,
                  w.completed_at AS completedAt,
                  ws.sort_order AS sortOrder,
                  ws.weight AS weight,
                  ws.reps AS reps,
                  ws.rir AS rir,
                  ws.is_warm_up AS isWarmUp,
                  ws.rest_timer_seconds AS restTimerSeconds
                FROM workout_sets ws
                JOIN workout_exercises we ON we.id = ws.workout_exercise_id
                JOIN workouts w ON w.id = we.workout_id
                WHERE we.exercise_id = ? AND w.status = 1 AND w.completed_at IS NOT NULL
                ORDER BY w.completed_at DESC, ws.sort_order ASC
                """
            return try Row.fetchAll(db, sql: sql, arguments: [exerciseId]).map { row in
                let startedAt: TimeInterval = row["startedAt"] ?? 0
                let completedAt: TimeInterval = row["completedAt"] ?? 0
                let isWarmUp: Bool? = (row["isWarmUp"] as Int?).map { $0 != 0 }
                return ExerciseHistorySetEntry(
                    id: row["id"],
                    workoutId: row["workoutId"],
                    workoutName: row["workoutName"],
                    startedAt: Date(timeIntervalSince1970: startedAt),
                    completedAt: Date(timeIntervalSince1970: completedAt),
                    sortOrder: row["sortOrder"],
                    weight: row["weight"],
                    reps: row["reps"],
                    rir: row["rir"],
                    isWarmUp: isWarmUp,
                    restTimerSeconds: row["restTimerSeconds"]
                )
            }
        }
    }

    func fetchLatestSetsForExercises(exerciseIds: [String]) throws -> [String:
        [(weight: Double?, reps: Int?)]]
    {
        guard !exerciseIds.isEmpty else { return [:] }

        return try dbQueue.read { db in
            let placeholders = exerciseIds.map { _ in "?" }.joined(separator: ",")
            let sql = """
                WITH LatestExerciseWorkouts AS (
                    SELECT 
                        we.exercise_id, 
                        we.id as workout_exercise_id, 
                        w.completed_at,
                        ROW_NUMBER() OVER (PARTITION BY we.exercise_id ORDER BY w.completed_at DESC) as rn
                    FROM workout_exercises we
                    JOIN workouts w ON w.id = we.workout_id
                    WHERE we.exercise_id IN (\(placeholders)) AND w.status = 1
                )
                SELECT lew.exercise_id, ws.weight, ws.reps
                FROM LatestExerciseWorkouts lew
                JOIN workout_sets ws ON ws.workout_exercise_id = lew.workout_exercise_id
                WHERE lew.rn = 1
                ORDER BY lew.exercise_id, ws.sort_order ASC
                """
            let rows = try Row.fetchAll(
                db, sql: sql, arguments: StatementArguments(exerciseIds))

            var result: [String: [(weight: Double?, reps: Int?)]] = [:]
            for row in rows {
                let exerciseId: String = row["exercise_id"]
                let weight: Double? = row["weight"]
                let reps: Int? = row["reps"]
                result[exerciseId, default: []].append((weight, reps))
            }
            return result
        }
    }

    /// Last completed sets per exercise (from most recent completed workout), for pre-filling new sets.
    func fetchLastCompletedSetsByExercise(exerciseIds: [String]) throws -> [String: [LastCompletedSetDetail]] {
        guard !exerciseIds.isEmpty else { return [:] }

        return try dbQueue.read { db in
            let placeholders = exerciseIds.map { _ in "?" }.joined(separator: ",")
            let sql = """
                WITH LatestExerciseWorkouts AS (
                    SELECT 
                        we.exercise_id, 
                        we.id as workout_exercise_id, 
                        w.completed_at,
                        ROW_NUMBER() OVER (PARTITION BY we.exercise_id ORDER BY w.completed_at DESC) as rn
                    FROM workout_exercises we
                    JOIN workouts w ON w.id = we.workout_id
                    WHERE we.exercise_id IN (\(placeholders)) AND w.status = 1
                )
                SELECT lew.exercise_id, ws.sort_order, ws.weight, ws.reps, ws.is_warm_up, ws.rir, ws.rest_timer_seconds
                FROM LatestExerciseWorkouts lew
                JOIN workout_sets ws ON ws.workout_exercise_id = lew.workout_exercise_id
                WHERE lew.rn = 1
                ORDER BY lew.exercise_id, ws.sort_order ASC
                """
            let rows = try Row.fetchAll(
                db, sql: sql, arguments: StatementArguments(exerciseIds))

            var result: [String: [LastCompletedSetDetail]] = [:]
            for row in rows {
                let exerciseId: String = row["exercise_id"]
                let isWarmUp: Bool? = (row["is_warm_up"] as Int?).map { $0 != 0 }
                let detail = LastCompletedSetDetail(
                    sortOrder: row["sort_order"] ?? 0,
                    weight: row["weight"],
                    reps: row["reps"],
                    isWarmUp: isWarmUp,
                    rir: row["rir"],
                    restTimerSeconds: row["rest_timer_seconds"]
                )
                result[exerciseId, default: []].append(detail)
            }
            return result
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

    func deleteAllWorkouts() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM workouts")
        }
        // Reset the CSV import flag so user can re-import if they want
        UserDefaults.standard.removeObject(forKey: "CSVImporter.didImportWorkouts")
    }
}

@MainActor
final class ExerciseStore: ObservableObject {
    @Published private(set) var exercises: [ExerciseRecord] = []
    @Published private(set) var exerciseFrequencies: [String: Int] = [:]

    private let dbQueue: DatabaseQueue

    init(db: AppDatabase) {
        self.dbQueue = db.dbQueue
    }

    func loadAll() async {
        do {
            let (allExercises, frequencies) = try await dbQueue.read { db in
                let exercises = try ExerciseRecord.order(ExerciseRecord.Columns.name.asc).fetchAll(db)
                
                let frequencyRows = try Row.fetchAll(db, sql: """
                    SELECT we.exercise_id, COUNT(DISTINCT we.workout_id) as frequency
                    FROM workout_exercises we
                    JOIN workouts w ON w.id = we.workout_id
                    WHERE w.status = 1
                    GROUP BY we.exercise_id
                    """)
                
                var freqMap: [String: Int] = [:]
                for row in frequencyRows {
                    let id: String = row["exercise_id"]
                    let count: Int = row["frequency"]
                    freqMap[id] = count
                }
                
                return (exercises, freqMap)
            }
            exercises = allExercises
            exerciseFrequencies = frequencies
        } catch {
            exercises = []
            exerciseFrequencies = [:]
        }
    }
}
