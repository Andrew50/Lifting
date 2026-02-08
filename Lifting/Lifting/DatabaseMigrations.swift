//
//  DatabaseMigrations.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import Foundation
import GRDB

enum DatabaseMigrations {
    static let migrator: DatabaseMigrator = {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "exercises", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull().unique()
            }

            try db.create(table: "templates", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("created_at", .double).notNull()
                t.column("updated_at", .double).notNull()
            }

            try db.create(table: "template_exercises", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("template_id", .text)
                    .notNull()
                    .indexed()
                    .references("templates", onDelete: .cascade)
                t.column("exercise_id", .text)
                    .notNull()
                    .indexed()
                    .references("exercises", onDelete: .restrict)
                t.column("sort_order", .integer).notNull()
                t.column("planned_sets_count", .integer).notNull().defaults(to: 3)
            }

            try db.create(table: "workouts", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("status", .integer).notNull() // 0=pending, 1=completed
                t.column("source_template_id", .text)
                    .references("templates", onDelete: .setNull)
                t.column("started_at", .double).notNull()
                t.column("completed_at", .double)
                t.column("created_at", .double).notNull()
                t.column("updated_at", .double).notNull()
            }

            // Ensure only one pending workout can exist.
            try db.execute(sql: """
                CREATE UNIQUE INDEX IF NOT EXISTS workouts_unique_pending
                ON workouts(status)
                WHERE status = 0
                """)

            try db.create(table: "workout_exercises", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("workout_id", .text)
                    .notNull()
                    .indexed()
                    .references("workouts", onDelete: .cascade)
                t.column("exercise_id", .text)
                    .notNull()
                    .indexed()
                    .references("exercises", onDelete: .restrict)
                t.column("sort_order", .integer).notNull()
            }

            try db.create(table: "workout_sets", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("workout_exercise_id", .text)
                    .notNull()
                    .indexed()
                    .references("workout_exercises", onDelete: .cascade)
                t.column("sort_order", .integer).notNull()
                t.column("weight", .double)
                t.column("reps", .integer)
                t.column("rir", .double)
            }
        }

        migrator.registerMigration("v2_add_workout_set_is_warm_up") { db in
            try db.alter(table: "workout_sets") { t in
                t.add(column: "is_warm_up", .integer)
            }
        }

        migrator.registerMigration("v3_add_users_table") { db in
            try db.create(table: "users", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("email", .text).notNull().unique()
                t.column("password_hash", .text).notNull()
                t.column("created_at", .double).notNull()
            }
        }

        migrator.registerMigration("v4_add_workout_notes") { db in
            try db.alter(table: "workouts") { t in
                t.add(column: "notes", .text)
            }
        }

        return migrator
    }()
}

