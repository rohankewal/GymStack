# GymStack Workout Logger

GymStack is a modern, lightweight workout logging application for iOS, built entirely with SwiftUI and SwiftData. It's designed with a clean, futuristic "iOS 26" aesthetic, focusing on an intuitive and efficient user experience for logging strength training workouts.

## ✨ Features

* **Workout History:** View all your past workout sessions in a clean, chronological list.
* **Start & Log Workouts:** Easily start a new workout session and log your exercises in real-time.
* **Track Sets, Reps, and Weight:** Add multiple sets for each exercise, tracking the number of reps and the weight used.
* **Detailed Summaries:** Tap on any past workout to see a detailed summary of all the exercises and sets you completed.
* **Persistent Storage:** Your workout data is automatically saved on your device using SwiftData, ensuring your log is always there when you need it.
* **Modern UI/UX:** A sleek interface that feels right at home on the latest versions of iOS, with smooth animations and haptic feedback.

## 🛠️ Technology Stack

* **UI Framework:** SwiftUI
* **Persistence:** SwiftData
* **Language:** Swift
* **Platform:** iOS

## 🚀 How to Run

1.  Make sure you have Xcode installed on your Mac.
2.  Clone or download the project.
3.  Open the `.xcodeproj` or `.swiftpm` file in Xcode.
4.  Select a simulator or a physical device.
5.  Click the "Run" button (or press `Cmd + R`).

## 📂 Project Structure

For simplicity and ease of sharing, the entire application—including all data models, views, and the main app entry point—is contained within a single file: `ContentView.swift`.

In a larger, production-level project, this would be broken down into a more conventional file structure:

` ` `
GymStack/
├── Models/
│   ├── WorkoutSession.swift
│   ├── LoggedExercise.swift
│   └── ExerciseSet.swift
├── Views/
│   ├── WorkoutListView.swift
│   ├── ActiveWorkoutView.swift
│   └── ... (etc.)
└── GymStackApp.swift
` ` `

---
