//
//  LiftingTests.swift
//  LiftingTests
//
//  Created by Andrew Billings on 1/31/26.
//

import XCTest
@testable import Lifting
import GRDB

final class LiftingTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    @MainActor
    func testCreateTemplateAndStartWorkoutFromTemplate() throws {
        var config = Configuration()
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }

        let queue = try DatabaseQueue(path: ":memory:", configuration: config)
        let appDB = try AppDatabase(dbQueue: queue, seedExercises: false)

        // Seed one exercise
        try queue.write { db in
            try db.execute(
                sql: "INSERT INTO exercises (id, name) VALUES (?, ?)",
                arguments: ["ex1", "Bench Press"]
            )
        }

        let templateStore = TemplateStore(db: appDB)
        let workoutStore = WorkoutStore(db: appDB)

        let templateId = try templateStore.createTemplate(name: "Push Day")
        try templateStore.addTemplateExercise(templateId: templateId, exerciseId: "ex1")

        // Set planned sets to 2 so we can verify set creation
        let templateExercises = try templateStore.fetchTemplateExercises(templateId: templateId)
        XCTAssertEqual(templateExercises.count, 1)
        try templateStore.updatePlannedSets(templateExerciseId: templateExercises[0].id, plannedSetsCount: 2)

        let workoutId = try workoutStore.startPendingWorkout(fromTemplate: templateId)
        let workout = try XCTUnwrap(workoutStore.fetchWorkout(workoutId: workoutId))
        XCTAssertEqual(workout.status, .pending)
        XCTAssertEqual(workout.sourceTemplateId, templateId)

        let workoutExercises = try workoutStore.fetchWorkoutExercises(workoutId: workoutId)
        XCTAssertEqual(workoutExercises.count, 1)
        XCTAssertEqual(workoutExercises[0].sets.count, 2)

        // Starting again should return the same pending workout (single pending enforcement)
        let workoutId2 = try workoutStore.startPendingWorkout(fromTemplate: templateId)
        XCTAssertEqual(workoutId2, workoutId)

        try workoutStore.completeWorkout(workoutId: workoutId)
        let completed = try XCTUnwrap(workoutStore.fetchWorkout(workoutId: workoutId))
        XCTAssertEqual(completed.status, .completed)
        XCTAssertNotNil(completed.completedAt)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
