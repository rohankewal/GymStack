//
//  GymStackApp.swift
//  GymStack
//
//  Created by Rohan Kewalramani on 9/6/25.
//

import SwiftUI
import SwiftData

@main
struct GymStackApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WorkoutSession.self, LoggedExercise.self, ExerciseSet.self])
    }
}
