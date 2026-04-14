//
//  PRDetectionService.swift
//  Lifting
//

import Foundation
import GRDB

struct PRResult: Equatable {
    let exerciseId: String
    let exerciseName: String
    let workoutId: String
    let setId: String
    let weight: Double
    let reps: Int
    let estimated1RM: Double
    let previousBest1RM: Double?
    let improvement: Double?
    let improvementPercent: Double?
}

final class PRDetectionService {

    // MARK: - 1RM estimation

    static func epley(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        if reps == 1 { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    static func brzycki(weight: Double, reps: Int) -> Double {
        guard reps > 0, reps < 37 else { return weight }
        return weight * (36.0 / (37.0 - Double(reps)))
    }

    static func lombardi(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        return weight * pow(Double(reps), 0.1)
    }

    static func estimated1RM(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        let e = epley(weight: weight, reps: reps)
        let b = brzycki(weight: weight, reps: reps)
        let l = lombardi(weight: weight, reps: reps)
        return (e + b + l) / 3.0
    }

    // MARK: - PR check

    static func checkForPR(
        db: Database,
        setId: String,
        exerciseId: String,
        exerciseName: String,
        workoutId: String,
        weight: Double,
        reps: Int,
        bodyWeight: Double?
    ) throws -> PRResult? {
        guard weight > 0, reps > 0 else { return nil }

        let new1RM = estimated1RM(weight: weight, reps: reps)
        guard new1RM > 0 else { return nil }

        let historical1RM = try Double.fetchOne(
            db,
            sql: """
                SELECT MAX(ss.estimated_1rm)
                FROM strength_snapshots ss
                WHERE ss.exercise_id = ?
                  AND ss.workout_id != ?
                """,
            arguments: [exerciseId, workoutId]
        ) ?? 0.0

        let snapshot = StrengthSnapshotRecord(
            id: UUID().uuidString,
            exerciseId: exerciseId,
            workoutId: workoutId,
            estimatedOneRM: new1RM,
            weight: weight,
            reps: reps,
            recordedAt: Date().timeIntervalSince1970
        )
        try snapshot.insert(db)

        let buffer = 0.001
        guard new1RM > historical1RM + buffer else { return nil }

        let improvement = historical1RM > 0 ? new1RM - historical1RM : nil
        let improvementPercent = (historical1RM > 0 && improvement != nil)
            ? (improvement! / historical1RM) * 100.0
            : nil

        let pr = PersonalRecordRecord(
            id: UUID().uuidString,
            exerciseId: exerciseId,
            workoutId: workoutId,
            setId: setId,
            type: "estimated_1rm",
            weight: weight,
            reps: reps,
            estimated1RM: new1RM,
            previousBest1RM: historical1RM > 0 ? historical1RM : nil,
            improvement: improvement,
            improvementPercent: improvementPercent,
            bodyWeight: bodyWeight,
            achievedAt: Date().timeIntervalSince1970
        )
        try pr.insert(db)

        return PRResult(
            exerciseId: exerciseId,
            exerciseName: exerciseName,
            workoutId: workoutId,
            setId: setId,
            weight: weight,
            reps: reps,
            estimated1RM: new1RM,
            previousBest1RM: historical1RM > 0 ? historical1RM : nil,
            improvement: improvement,
            improvementPercent: improvementPercent
        )
    }
}
