//
//  GymStackApp.swift
//  GymStack
//
//  Created by Rohan Kewalramani on 9/6/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct GymStackApp: App {
    init() {
        // Initialize local notifications as early as possible
        _ = NotificationManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WorkoutSession.self, LoggedExercise.self, ExerciseSet.self])
    }
}
