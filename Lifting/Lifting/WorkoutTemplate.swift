//
//  WorkoutTemplate.swift
//  Lifting
//
//  Created by Andrew Billings on 1/31/26.
//

import Foundation

struct WorkoutTemplate: Identifiable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

