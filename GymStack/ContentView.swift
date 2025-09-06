//
//  ContentView.swift
//  GymStack
//
//  Created by Rohan Kewalramani on 9/6/25.
//

import SwiftUI
import SwiftData

// MARK: - 1. Data Models
// In a larger project, each of these models would be in its own file (e.g., Models/WorkoutSession.swift)

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var name: String
    var date: Date
    // Relationship: A workout session can have many exercises. If a session is deleted, its exercises are also deleted.
    @Relationship(deleteRule: .cascade) var exercises: [LoggedExercise] = []
    
    init(id: UUID = UUID(), name: String, date: Date, exercises: [LoggedExercise] = []) {
        self.id = id
        self.name = name
        self.date = date
        self.exercises = exercises
    }
}

@Model
final class LoggedExercise {
    @Attribute(.unique) var id: UUID
    var name: String
    // Relationship: An exercise consists of multiple sets. If an exercise is deleted, its sets are also deleted.
    @Relationship(deleteRule: .cascade) var sets: [ExerciseSet] = []
    
    // Back-reference to the parent WorkoutSession
    var session: WorkoutSession?
    
    init(id: UUID = UUID(), name: String, sets: [ExerciseSet] = []) {
        self.id = id
        self.name = name
        self.sets = sets
    }
}

@Model
final class ExerciseSet: Identifiable {
    @Attribute(.unique) var id: UUID
    var reps: Int
    var weight: Double
    
    // Back-reference to the parent LoggedExercise
    var exercise: LoggedExercise?
    
    init(id: UUID = UUID(), reps: Int, weight: Double) {
        self.id = id
        self.reps = reps
        self.weight = weight
    }
}

// MARK: - 3. Views
// The original ContentView is now the main view of our app.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Fetch all workout sessions, sorted by date descending
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    
    @State private var isShowingNewWorkoutSheet = false
    @State private var newWorkoutName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                // Background Styling
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                
                if workoutSessions.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Logged",
                        systemImage: "figure.run.circle",
                        description: Text("Tap the '+' button to start your first workout.")
                    )
                } else {
                    List {
                        ForEach(workoutSessions) { session in
                            NavigationLink(destination: WorkoutDetailView(session: session)) {
                                WorkoutRow(session: session)
                            }
                        }
                        .onDelete(perform: deleteWorkouts)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("GymStack")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isShowingNewWorkoutSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.headline)
                    }
                }
            }
            .sheet(isPresented: $isShowingNewWorkoutSheet) {
                StartWorkoutView()
            }
        }
        .tint(.cyan) // Modern accent color
    }
    
    private func deleteWorkouts(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(workoutSessions[index])
            }
        }
    }
}

// --- Row View for the Workout List ---
struct WorkoutRow: View {
    let session: WorkoutSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Image(systemName: "calendar")
                Text(session.date, style: .date)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "number")
                Text("\(session.exercises.count) exercises")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}


// --- View to Start a New Workout ---
struct StartWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var workoutName: String = ""
    @State private var newWorkoutSession: WorkoutSession?

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Workout Details")) {
                    TextField("Workout Name (e.g., Push Day)", text: $workoutName)
                }
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Start", action: startWorkout)
                        .disabled(workoutName.isEmpty)
                }
            }
            // When newWorkoutSession is set, navigate to the ActiveWorkoutView
            .navigationDestination(item: $newWorkoutSession) { session in
                 ActiveWorkoutView(session: session, onFinish: {
                    // This closure is called when the workout is finished
                    newWorkoutSession = nil // This will pop the ActiveWorkoutView
                    dismiss() // Dismiss the sheet
                 })
            }
        }
    }
    
    private func startWorkout() {
        // Create the new session and add it to the context
        let newSession = WorkoutSession(name: workoutName, date: .now)
        modelContext.insert(newSession)
        
        // Save the context to persist the new session
        try? modelContext.save()
        
        // Set the state to trigger navigation
        self.newWorkoutSession = newSession
    }
}

// --- View for an Active, In-Progress Workout ---
struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    var onFinish: () -> Void
    
    @State private var isShowingAddExerciseSheet = false
    
    var body: some View {
        VStack {
            List {
                ForEach(session.exercises) { exercise in
                    Section(header: Text(exercise.name).font(.headline)) {
                        ForEach(exercise.sets.indices, id: \.self) { index in
                             SetRowView(set: exercise.sets[index], setNumber: index + 1)
                        }
                    }
                }
                .onDelete(perform: deleteExercise)
            }
            .listStyle(.insetGrouped)

            VStack(spacing: 12) {
                Button(action: { isShowingAddExerciseSheet = true }) {
                    Label("Add Exercise", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.cyan)

                Button(action: finishWorkout) {
                    Text("Finish Workout")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
        }
        .navigationTitle(session.name)
        .navigationBarBackButtonHidden(true) // Prevent going back without finishing
        .sheet(isPresented: $isShowingAddExerciseSheet) {
            AddExerciseView(session: session)
        }
    }
    
    private func finishWorkout() {
        // Perform haptic feedback for a satisfying finish
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onFinish()
    }

    private func deleteExercise(at offsets: IndexSet) {
        session.exercises.remove(atOffsets: offsets)
        // Note: SwiftData automatically handles deleting the associated LoggedExercise object
        // when it's removed from the session's exercises array due to the cascade rule.
    }
}


// --- View to Add a New Exercise to the Active Workout ---
struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: WorkoutSession
    
    @State private var exerciseName = ""
    @State private var sets: [ExerciseSet] = [ExerciseSet(reps: 8, weight: 100.0)]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Exercise Name")) {
                    TextField("e.g., Barbell Bench Press", text: $exerciseName)
                }
                
                Section(header: Text("Sets")) {
                    ForEach($sets) { $set in
                        HStack(spacing: 15) {
                            Text("Reps:")
                            TextField("Reps", value: $set.reps, formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                            
                            Text("Weight:")
                            TextField("Weight", value: $set.weight, formatter: NumberFormatter())
                                .keyboardType(.decimalPad)
                            
                            Text("lbs") // Or kg, could be a user setting
                        }
                    }
                    .onDelete { indices in
                        sets.remove(atOffsets: indices)
                    }
                    
                    Button("Add Set", systemImage: "plus") {
                        let newSet = ExerciseSet(reps: 8, weight: 100.0)
                        sets.append(newSet)
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save", action: saveExercise)
                        .disabled(exerciseName.isEmpty || sets.isEmpty)
                }
            }
        }
    }
    
    private func saveExercise() {
        let newExercise = LoggedExercise(name: exerciseName, sets: sets)
        // Append the new exercise to the session's exercise list.
        // SwiftData automatically handles saving this relationship.
        session.exercises.append(newExercise)
        dismiss()
    }
}

// --- Detail View: Shows a summary of a completed workout ---
struct WorkoutDetailView: View {
    let session: WorkoutSession

    var body: some View {
        List {
            Section(header: Text("Details")) {
                HStack {
                    Image(systemName: "text.badge.checkmark")
                    Text(session.name)
                }
                HStack {
                    Image(systemName: "calendar")
                    Text(session.date, style: .date)
                }
            }
            
            Section(header: Text("Exercises")) {
                if session.exercises.isEmpty {
                    Text("No exercises were logged for this session.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(session.exercises) { exercise in
                        DisclosureGroup(exercise.name) {
                            VStack(alignment: .leading) {
                                ForEach(exercise.sets.indices, id: \.self) { index in
                                    SetRowView(set: exercise.sets[index], setNumber: index + 1)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        .font(.headline)
                    }
                }
            }
        }
        .navigationTitle("Workout Summary")
    }
}

// --- Reusable View for Displaying a Single Set ---
struct SetRowView: View {
    let set: ExerciseSet
    let setNumber: Int
    
    var body: some View {
        HStack {
            Text("Set \(setNumber)")
                .fontWeight(.medium)
                .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            Text("\(set.reps)")
                .frame(width: 50)
            Text("reps")
                .foregroundColor(.secondary)
            
            Spacer()

            Text(String(format: "%.1f", set.weight))
                .frame(width: 60)
            Text("lbs") // Unit can be a setting
                .foregroundColor(.secondary)
        }
        .font(.body)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
}

