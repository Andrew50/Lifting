//
//  DBModels.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import Foundation
import GRDB

// MARK: - User

struct UserRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Hashable {
    static let databaseTableName = "users"

    var id: String
    var name: String
    var email: String
    var passwordHash: String
    var createdAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id, name, email
        case passwordHash = "password_hash"
        case createdAt = "created_at"
    }

    enum Columns: String, ColumnExpression {
        case id, name, email
        case passwordHash = "password_hash"
        case createdAt = "created_at"
    }
}

// MARK: - Exercise

struct ExerciseRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Hashable {
    static let databaseTableName = "exercises"

    var id: String
    var name: String

    enum Columns: String, ColumnExpression {
        case id, name
    }
}

// MARK: - Templates

struct TemplateRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Hashable {
    static let databaseTableName = "templates"

    var id: String
    var name: String
    var createdAt: TimeInterval
    var updatedAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id, name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum Columns: String, ColumnExpression {
        case id, name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct TemplateExerciseRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Hashable {
    static let databaseTableName = "template_exercises"

    var id: String
    var templateId: String
    var exerciseId: String
    var sortOrder: Int
    var plannedSetsCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case templateId = "template_id"
        case exerciseId = "exercise_id"
        case sortOrder = "sort_order"
        case plannedSetsCount = "planned_sets_count"
    }

    enum Columns: String, ColumnExpression {
        case id
        case templateId = "template_id"
        case exerciseId = "exercise_id"
        case sortOrder = "sort_order"
        case plannedSetsCount = "planned_sets_count"
    }
}

// MARK: - Workouts

enum WorkoutStatus: Int, Codable {
    case pending = 0
    case completed = 1
}

struct WorkoutRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Hashable {
    static let databaseTableName = "workouts"

    var id: String
    var name: String
    var status: WorkoutStatus
    var sourceTemplateId: String?
    var startedAt: TimeInterval
    var completedAt: TimeInterval?
    var notes: String?
    var createdAt: TimeInterval
    var updatedAt: TimeInterval

    enum CodingKeys: String, CodingKey {
        case id, name, status, notes
        case sourceTemplateId = "source_template_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    enum Columns: String, ColumnExpression {
        case id, name, status, notes
        case sourceTemplateId = "source_template_id"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WorkoutExerciseRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Hashable {
    static let databaseTableName = "workout_exercises"

    var id: String
    var workoutId: String
    var exerciseId: String
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case workoutId = "workout_id"
        case exerciseId = "exercise_id"
        case sortOrder = "sort_order"
    }

    enum Columns: String, ColumnExpression {
        case id
        case workoutId = "workout_id"
        case exerciseId = "exercise_id"
        case sortOrder = "sort_order"
    }
}

struct WorkoutSetRecord: Codable, FetchableRecord, PersistableRecord, TableRecord, Identifiable, Hashable {
    static let databaseTableName = "workout_sets"

    var id: String
    var workoutExerciseId: String
    var sortOrder: Int
    var weight: Double?
    var reps: Int?
    var distance: Double?
    var seconds: Double?
    var notes: String?
    var rpe: Double?
    var rir: Double?
    var isWarmUp: Bool?
    var restTimerSeconds: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case workoutExerciseId = "workout_exercise_id"
        case sortOrder = "sort_order"
        case weight, reps, distance, seconds, notes, rpe, rir
        case isWarmUp = "is_warm_up"
        case restTimerSeconds = "rest_timer_seconds"
    }

    enum Columns: String, ColumnExpression {
        case id
        case workoutExerciseId = "workout_exercise_id"
        case sortOrder = "sort_order"
        case weight, reps, distance, seconds, notes, rpe, rir
        case isWarmUp = "is_warm_up"
        case restTimerSeconds = "rest_timer_seconds"
    }
}

// MARK: - Convenience types for UI

struct TemplateSummary: Identifiable, Hashable {
    var id: String
    var name: String
}

struct WorkoutSummary: Identifiable, Hashable {
    var id: String
    var name: String
    var completedAt: Date
    var duration: TimeInterval
    var exercises: [WorkoutExerciseSummary]
}

struct WorkoutExerciseSummary: Identifiable, Hashable {
    var id: String
    var name: String
    var setsCount: Int
}

struct TemplateExerciseDetail: Identifiable, Hashable {
    var id: String
    var exerciseId: String
    var exerciseName: String
    var sortOrder: Int
    var plannedSetsCount: Int
}

struct WorkoutSetDetail: Identifiable, Hashable {
    var id: String
    var sortOrder: Int
    var weight: Double?
    var reps: Int?
    var rir: Double?
    var isWarmUp: Bool?
    var restTimerSeconds: Int?
}

/// One performed set for an exercise, with workout context (for history).
struct ExerciseHistorySetEntry: Identifiable, Hashable {
    var id: String
    var workoutId: String
    var workoutName: String
    var completedAt: Date
    var sortOrder: Int
    var weight: Double?
    var reps: Int?
    var rir: Double?
    var isWarmUp: Bool?
    var restTimerSeconds: Int?
}

struct WorkoutExerciseDetail: Identifiable, Hashable {
    var id: String
    var exerciseId: String
    var exerciseName: String
    var sortOrder: Int
    var sets: [WorkoutSetDetail]
}

