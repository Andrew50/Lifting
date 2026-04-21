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

    func updateTemplateNotes(templateId: String, notes: String?) throws {
        let now = Date().timeIntervalSince1970
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE templates SET notes = ?, updated_at = ? WHERE id = ?",
                arguments: [notes, now, templateId]
            )
        }
    }

    func replaceTemplateExercise(templateExerciseId: String, newExerciseId: String) throws {
        let now = Date().timeIntervalSince1970
        try dbQueue.write { db in
            let templateId: String? = try String.fetchOne(
                db,
                sql: "SELECT template_id FROM template_exercises WHERE id = ?",
                arguments: [templateExerciseId]
            )
            try db.execute(
                sql: "UPDATE template_exercises SET exercise_id = ?, planned_sets_count = 3 WHERE id = ?",
                arguments: [newExerciseId, templateExerciseId]
            )
            if let templateId {
                try db.execute(
                    sql: "UPDATE templates SET updated_at = ? WHERE id = ?",
                    arguments: [now, templateId]
                )
            }
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

            let placeholders = workoutIds.map { _ in "?" }.joined(separator: ",")

            let exercisesSql = """
                SELECT
                    we.workout_id,
                    we.id,
                    we.exercise_id,
                    e.name,
                    (SELECT COUNT(*) FROM workout_sets ws WHERE ws.workout_exercise_id = we.id) as setsCount,
                    (SELECT ws2.weight FROM workout_sets ws2
                     WHERE ws2.workout_exercise_id = we.id
                       AND ws2.weight IS NOT NULL
                     ORDER BY ws2.weight DESC LIMIT 1) as topWeight,
                    (SELECT ws3.reps FROM workout_sets ws3
                     WHERE ws3.workout_exercise_id = we.id
                       AND ws3.weight = (
                           SELECT MAX(ws4.weight) FROM workout_sets ws4
                           WHERE ws4.workout_exercise_id = we.id
                       )
                     ORDER BY ws3.reps DESC LIMIT 1) as topReps
                FROM workout_exercises we
                JOIN exercises e ON e.id = we.exercise_id
                WHERE we.workout_id IN (\(placeholders))
                ORDER BY we.sort_order ASC
                """
            let allExercises = try Row.fetchAll(
                db, sql: exercisesSql, arguments: StatementArguments(workoutIds))
            let exercisesByWorkoutId = Dictionary(grouping: allExercises, by: { $0["workout_id"] as String })

            let volumeSql = """
                SELECT we.workout_id,
                       COALESCE(SUM(ws.weight * ws.reps), 0) as volume
                FROM workout_sets ws
                JOIN workout_exercises we ON we.id = ws.workout_exercise_id
                WHERE we.workout_id IN (\(placeholders))
                  AND ws.weight IS NOT NULL AND ws.reps IS NOT NULL
                GROUP BY we.workout_id
                """
            let volumeRows = try Row.fetchAll(db, sql: volumeSql, arguments: StatementArguments(workoutIds))
            var volumeByWorkoutId: [String: Double] = [:]
            for row in volumeRows {
                let wid: String = row["workout_id"]
                let vol: Double = row["volume"]
                volumeByWorkoutId[wid] = vol
            }

            let prSql = """
                SELECT DISTINCT workout_id
                FROM personal_records
                WHERE workout_id IN (\(placeholders))
                """
            let prRows = try Row.fetchAll(db, sql: prSql, arguments: StatementArguments(workoutIds))
            let workoutIdsWithPR = Set(prRows.compactMap { $0["workout_id"] as String? })

            let summaries = records.compactMap { workout -> WorkoutSummary? in
                guard let completedAt = workout.completedAt else { return nil }

                let exercises = (exercisesByWorkoutId[workout.id] ?? []).map { row in
                    WorkoutExerciseSummary(
                        id: row["id"],
                        exerciseId: row["exercise_id"],
                        name: row["name"],
                        setsCount: row["setsCount"],
                        topWeight: row["topWeight"] as Double?,
                        topReps: row["topReps"] as Int?
                    )
                }

                return WorkoutSummary(
                    id: workout.id,
                    name: workout.name,
                    completedAt: completedAt,
                    duration: completedAt - workout.startedAt,
                    totalVolume: volumeByWorkoutId[workout.id] ?? 0,
                    hasPR: workoutIdsWithPR.contains(workout.id),
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
    @Published private(set) var stats: WorkoutStats = WorkoutStats(streak: 0, thisWeekCount: 0, weeklyVolume: 0)
    @Published var latestPR: PRResult? = nil

    /// Rest countdown end time for the active workout sheet (survives collapsing to the in-tab bar).
    @Published var activeRestTimerWorkoutId: String?
    @Published var activeRestTimerEndDate: Date?
    /// Last chosen rest-between-sets duration (seconds) for the active workout UI.
    @Published var activeWorkoutRestPresetSeconds: Int = 120

    private let dbQueue: DatabaseQueue
    private var statsCancellable: AnyCancellable?

    init(db: AppDatabase) {
        self.dbQueue = db.dbQueue
        startObservingStats()
    }

    func setActiveRestTimer(workoutId: String, endDate: Date?) {
        if let endDate {
            activeRestTimerWorkoutId = workoutId
            activeRestTimerEndDate = endDate
        } else if activeRestTimerWorkoutId == workoutId {
            activeRestTimerWorkoutId = nil
            activeRestTimerEndDate = nil
        }
    }

    private func startObservingStats() {
        let observation = ValueObservation.tracking { db in
            let streak = try Self.computeStreak(db: db)
            let thisWeekCount = try Self.computeThisWeekCount(db: db)
            let weeklyVolume = try Self.computeWeeklyVolume(db: db)
            return WorkoutStats(streak: streak, thisWeekCount: thisWeekCount, weeklyVolume: weeklyVolume)
        }
        statsCancellable = observation
            .publisher(in: dbQueue)
            .receive(on: DispatchQueue.main)
            .replaceError(with: WorkoutStats(streak: 0, thisWeekCount: 0, weeklyVolume: 0))
            .sink { [weak self] newStats in
                self?.stats = newStats
            }
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
    func startPendingWorkout(fromTemplate templateId: String, defaultRestTimerSeconds: Int? = nil) throws -> String {
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
                        isDropSet: prev?.isDropSet,
                        restTimerSeconds: prev?.restTimerSeconds ?? defaultRestTimerSeconds
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
                        isDropSet: s.isDropSet,
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
    func addWorkoutExercise(workoutId: String, exerciseId: String, defaultRestTimerSeconds: Int? = nil) throws {
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
                    isDropSet: nil,
                    restTimerSeconds: defaultRestTimerSeconds
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
                        isDropSet: prev.isDropSet,
                        restTimerSeconds: prev.restTimerSeconds ?? defaultRestTimerSeconds
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

    func addSet(workoutExerciseId: String, restTimerSeconds: Int? = nil) throws {
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
                isDropSet: nil,
                restTimerSeconds: restTimerSeconds
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
        isDropSet: Bool? = nil,
        isCompleted: Bool? = nil,
        restTimerSeconds: Int? = nil
    ) throws {
        var prResult: PRResult?
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
                if let isDropSet { set.isDropSet = isDropSet }
                if let isCompleted { set.isCompleted = isCompleted }
                if let restTimerSeconds { set.restTimerSeconds = restTimerSeconds }
                try set.update(db)
            }

            if let weight = weight, let reps = reps, weight > 0, reps > 0 {
                if let exerciseInfo = try Row.fetchOne(
                    db,
                    sql: """
                        SELECT we.exercise_id, e.name, we.workout_id
                        FROM workout_sets ws
                        JOIN workout_exercises we ON we.id = ws.workout_exercise_id
                        JOIN exercises e ON e.id = we.exercise_id
                        WHERE ws.id = ?
                        """,
                    arguments: [setId]
                ) {
                    let exerciseId: String = exerciseInfo["exercise_id"]
                    let exerciseName: String = exerciseInfo["name"]
                    let workoutId: String = exerciseInfo["workout_id"]

                    let todayStr = BodyWeightStore.dateString(from: Date())
                    let bodyWeight = try Double.fetchOne(
                        db,
                        sql: "SELECT weight FROM body_weight_entries WHERE date = ?",
                        arguments: [todayStr]
                    )

                    prResult = try PRDetectionService.checkForPR(
                        db: db,
                        setId: setId,
                        exerciseId: exerciseId,
                        exerciseName: exerciseName,
                        workoutId: workoutId,
                        weight: weight,
                        reps: reps,
                        bodyWeight: bodyWeight
                    )
                }
            }
        }

        if let pr = prResult {
            DispatchQueue.main.async {
                self.latestPR = pr
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
                  ws.is_drop_set AS isDropSet,
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
                let isDropSet: Bool? = (row["isDropSet"] as Int?).map { $0 != 0 }
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
                    isDropSet: isDropSet,
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
                SELECT lew.exercise_id, ws.sort_order, ws.weight, ws.reps, ws.is_warm_up, ws.is_drop_set, ws.rir, ws.rest_timer_seconds
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
                let isDropSet: Bool? = (row["is_drop_set"] as Int?).map { $0 != 0 }
                let detail = LastCompletedSetDetail(
                    sortOrder: row["sort_order"] ?? 0,
                    weight: row["weight"],
                    reps: row["reps"],
                    isWarmUp: isWarmUp,
                    isDropSet: isDropSet,
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

// MARK: - Body Weight Store

@MainActor
final class BodyWeightStore: ObservableObject {
    @Published private(set) var recentEntries: [BodyWeightEntryRecord] = []

    private let dbQueue: DatabaseQueue
    private var cancellable: AnyCancellable?

    init(db: AppDatabase) {
        self.dbQueue = db.dbQueue
        startObserving()
    }

    private func startObserving() {
        let observation = ValueObservation.tracking { db in
            try BodyWeightEntryRecord
                .order(BodyWeightEntryRecord.Columns.date.desc)
                .limit(30)
                .fetchAll(db)
        }
        cancellable = observation
            .publisher(in: dbQueue)
            .receive(on: DispatchQueue.main)
            .replaceError(with: [])
            .sink { [weak self] entries in
                self?.recentEntries = entries
            }
    }

    var latestEntry: BodyWeightEntryRecord? {
        recentEntries.first
    }

    var weeklyChange: Double? {
        guard recentEntries.count >= 2,
              let latest = recentEntries.first else { return nil }
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let weekAgoStr = Self.dateString(from: weekAgo)
        // Prefer an entry from ~7 days ago; fall back to the oldest entry we have
        let older = recentEntries.first { $0.date <= weekAgoStr }
            ?? recentEntries.last
        guard let older, older.id != latest.id else { return nil }
        return latest.weight - older.weight
    }

    /// Entries for the last 7 days, sorted chronologically (oldest first).
    var last7DaysEntries: [BodyWeightEntryRecord] {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let weekAgoStr = Self.dateString(from: weekAgo)
        return recentEntries
            .filter { $0.date >= weekAgoStr }
            .sorted { $0.date < $1.date }
    }

    func logWeight(_ weight: Double, unit: String = "lbs", date: Date = Date()) throws {
        let dateStr = Self.dateString(from: date)
        let now = Date().timeIntervalSince1970
        try dbQueue.write { db in
            let existing = try BodyWeightEntryRecord
                .filter(BodyWeightEntryRecord.Columns.date == dateStr)
                .fetchOne(db)
            if var entry = existing {
                entry.weight = weight
                entry.unit = unit
                try entry.update(db)
            } else {
                let entry = BodyWeightEntryRecord(
                    id: UUID().uuidString,
                    weight: weight,
                    unit: unit,
                    date: dateStr,
                    createdAt: now
                )
                try entry.insert(db)
            }
        }
    }

    func deleteEntry(id: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "DELETE FROM body_weight_entries WHERE id = ?",
                arguments: [id]
            )
        }
    }

    static func dateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Workout Stats

struct WorkoutStats {
    var streak: Int
    var thisWeekCount: Int
    var weeklyVolume: Double
}

extension WorkoutStore {
    private nonisolated static func computeStreak(db: Database) throws -> Int {
        let rows = try Row.fetchAll(db, sql: """
            SELECT DISTINCT date(completed_at, 'unixepoch', 'localtime') as d
            FROM workouts
            WHERE status = 1 AND completed_at IS NOT NULL
            ORDER BY d DESC
            """)
        let dates = rows.compactMap { $0["d"] as String? }
        guard !dates.isEmpty else { return 0 }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let cal = Calendar.current

        var streak = 0
        var checkDate = cal.startOfDay(for: Date())

        let todayStr = formatter.string(from: checkDate)
        if dates.first != todayStr {
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
        }

        for dateStr in dates {
            let expected = formatter.string(from: checkDate)
            if dateStr == expected {
                streak += 1
                checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
            } else if dateStr < expected {
                break
            }
        }
        return streak
    }

    private nonisolated static func computeThisWeekCount(db: Database) throws -> Int {
        let cal = Calendar.current
        let now = Date()
        let startOfWeek = cal.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: now).date!
        let startEpoch = startOfWeek.timeIntervalSince1970
        return try Int.fetchOne(db, sql: """
            SELECT COUNT(*) FROM workouts
            WHERE status = 1 AND completed_at >= ?
            """, arguments: [startEpoch]) ?? 0
    }

    private nonisolated static func computeWeeklyVolume(db: Database) throws -> Double {
        let cal = Calendar.current
        let now = Date()
        let startOfWeek = cal.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: now).date!
        let startEpoch = startOfWeek.timeIntervalSince1970
        return try Double.fetchOne(db, sql: """
            SELECT COALESCE(SUM(ws.weight * ws.reps), 0)
            FROM workout_sets ws
            JOIN workout_exercises we ON we.id = ws.workout_exercise_id
            JOIN workouts w ON w.id = we.workout_id
            WHERE w.status = 1 AND w.completed_at >= ?
              AND ws.weight IS NOT NULL AND ws.reps IS NOT NULL
            """, arguments: [startEpoch]) ?? 0
    }
}

// MARK: - PR queries

extension WorkoutStore {
    func fetchLatestPR() throws -> PersonalRecordRecord? {
        try dbQueue.read { db in
            try PersonalRecordRecord
                .order(Column("achieved_at").desc)
                .fetchOne(db)
        }
    }

    func fetchPRs(exerciseId: String) throws -> [PersonalRecordRecord] {
        try dbQueue.read { db in
            try PersonalRecordRecord
                .filter(Column("exercise_id") == exerciseId)
                .order(Column("achieved_at").desc)
                .fetchAll(db)
        }
    }

    func fetchStrengthSnapshots(exerciseId: String) throws -> [StrengthSnapshotRecord] {
        try dbQueue.read { db in
            try StrengthSnapshotRecord
                .filter(Column("exercise_id") == exerciseId)
                .order(Column("recorded_at").asc)
                .fetchAll(db)
        }
    }

    func fetchExerciseName(exerciseId: String) throws -> String {
        try dbQueue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT name FROM exercises WHERE id = ?",
                arguments: [exerciseId]
            )
        } ?? "Unknown"
    }

    func fetchKeyLiftsData() throws -> [KeyLiftCardData] {
        try dbQueue.read { db in
            var results: [KeyLiftCardData] = []
            let candidates = KeyLifts.primary + KeyLifts.secondary

            for lift in candidates {
                guard
                    let exerciseRow = try Row.fetchOne(
                        db,
                        sql: "SELECT id, name FROM exercises WHERE name = ? LIMIT 1",
                        arguments: [lift.id]
                    )
                else {
                    if lift.isPrimary {
                        results.append(
                            KeyLiftCardData(
                                id: lift.id,
                                displayName: lift.displayName,
                                exerciseName: lift.id,
                                currentOneRM: nil,
                                previousOneRM: nil,
                                lastTrainedAt: nil
                            ))
                    }
                    continue
                }

                let exerciseId: String = exerciseRow["id"]
                let exerciseName: String = exerciseRow["name"]

                let snapshots = try Row.fetchAll(
                    db,
                    sql: """
                        SELECT estimated_1rm, recorded_at
                        FROM strength_snapshots
                        WHERE exercise_id = ?
                        ORDER BY recorded_at DESC
                        LIMIT 10
                        """,
                    arguments: [exerciseId]
                )

                if snapshots.isEmpty {
                    if lift.isPrimary {
                        results.append(
                            KeyLiftCardData(
                                id: exerciseId,
                                displayName: lift.displayName,
                                exerciseName: exerciseName,
                                currentOneRM: nil,
                                previousOneRM: nil,
                                lastTrainedAt: nil
                            ))
                    }
                    continue
                }

                let currentOneRM: Double = snapshots[0]["estimated_1rm"]
                let lastTrainedAt: Double = snapshots[0]["recorded_at"]
                let previousOneRM: Double? =
                    snapshots.count > 1 ? snapshots[1]["estimated_1rm"] : nil

                results.append(
                    KeyLiftCardData(
                        id: exerciseId,
                        displayName: lift.displayName,
                        exerciseName: exerciseName,
                        currentOneRM: currentOneRM,
                        previousOneRM: previousOneRM,
                        lastTrainedAt: lastTrainedAt
                    ))
            }

            return results
        }
    }

    func fetchRecentPRs(limit: Int = 20) throws -> [PRFeedItem] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT pr.id, pr.exercise_id, pr.weight, pr.reps, pr.estimated_1rm, pr.achieved_at, e.name AS exercise_name
                    FROM personal_records pr
                    JOIN exercises e ON e.id = pr.exercise_id
                    ORDER BY pr.achieved_at DESC
                    LIMIT 200
                    """
            )

            var seenKeys = Set<String>()
            var items: [PRFeedItem] = []
            items.reserveCapacity(limit)

            for row in rows {
                let exerciseId: String = row["exercise_id"]
                let weight: Double = row["weight"]
                let reps: Int = row["reps"]
                let key = "\(exerciseId)|\(weight)|\(reps)"
                if seenKeys.contains(key) { continue }
                seenKeys.insert(key)

                items.append(
                    PRFeedItem(
                        id: row["id"],
                        exerciseName: row["exercise_name"],
                        weight: weight,
                        reps: reps,
                        estimatedOneRM: row["estimated_1rm"],
                        achievedAt: row["achieved_at"]
                    ))

                if items.count >= limit { break }
            }

            return items
        }
    }
}
