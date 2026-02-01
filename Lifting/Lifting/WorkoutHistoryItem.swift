//
//  WorkoutHistoryItem.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import Foundation

struct WorkoutHistoryItem: Identifiable, Hashable {
    let id: UUID
    var name: String
    var date: Date

    init(id: UUID = UUID(), name: String, date: Date) {
        self.id = id
        self.name = name
        self.date = date
    }
}

