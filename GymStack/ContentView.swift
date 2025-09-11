//
//  ContentView.swift
//  GymStack
//
//  Created by Rohan Kewalramani on 9/6/25.
//

import SwiftUI
import SwiftData

// MARK: - 1. Data Models
// (These remain unchanged from the previous version)

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var name: String
    var date: Date
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
    @Relationship(deleteRule: .cascade) var sets: [ExerciseSet] = []
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
    var exercise: LoggedExercise?
    
    init(id: UUID = UUID(), reps: Int, weight: Double) {
        self.id = id
        self.reps = reps
        self.weight = weight
    }
}

// MARK: - 3. Main View with TabBar
// ContentView now acts as the root view containing our TabView.

struct ContentView: View {
    var body: some View {
        TabView {
            // --- First Tab: Workout History ---
            WorkoutHistoryView()
                .tabItem {
                    Label("History", systemImage: "list.bullet")
                }
            
            // --- Second Tab: Workout Calendar ---
            WorkoutCalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
        }
        .tint(.cyan) // Sets the accent color for the selected tab item
    }
}


// MARK: - 4. Tab Views

// --- The original list view, now renamed to WorkoutHistoryView ---
struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    
    @State private var isShowingNewWorkoutSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
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
            .navigationTitle("Workout History")
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
    }
    
    private func deleteWorkouts(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(workoutSessions[index])
            }
        }
    }
}

// --- NEW: The Calendar View for the second tab ---
struct WorkoutCalendarView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    
    var body: some View {
        NavigationStack {
            CalendarView { date in
                // This closure is called for each day in the calendar
                VStack(spacing: 4) {
                    Text(dayString(from: date))
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Find workouts for this specific day
                    let workoutsForDay = workouts(for: date)
                    
                    if !workoutsForDay.isEmpty {
                        ForEach(workoutsForDay) { session in
                            Text(session.name)
                                .font(.caption2)
                                .lineLimit(1)
                                .padding(4)
                                .background(Color.cyan.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Workout Calendar")
        }
    }
    
    // Helper function to get the day number as a string
    private func dayString(from date: Date) -> String {
        let calendar = Calendar.current
        return String(calendar.component(.day, from: date))
    }
    
    // Helper function to filter workouts for a specific date
    private func workouts(for date: Date) -> [WorkoutSession] {
        workoutSessions.filter { session in
            Calendar.current.isDate(session.date, inSameDayAs: date)
        }
    }
}


// MARK: - 5. Supporting Views
// (These are the same views as before, no changes needed)

// A minimal, self-contained calendar grid view that renders the current month
// and invokes a content closure for each day. This is not locale-perfect but
// is sufficient for showing daily workout badges.
struct CalendarView<DayContent: View>: View {
    let dayContent: (Date) -> DayContent

    @State private var monthOffset: Int = 0 // 0 = current month

    init(@ViewBuilder dayContent: @escaping (Date) -> DayContent) {
        self.dayContent = dayContent
    }

    var body: some View {
        VStack(spacing: 8) {
            header
            weekdayHeader
            monthGrid
        }
        .padding()
    }

    private var header: some View {
        HStack {
            Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(monthTitle(for: displayedMonth))
                .font(.headline)
            Spacer()
            Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") }
        }
    }

    private var weekdayHeader: some View {
        let symbols = Calendar.current.shortWeekdaySymbols // Sun, Mon, ... (depends on locale)
        return HStack {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let dates = datesForMonth(displayedMonth)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
            ForEach(dates, id: \.self) { date in
                if Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
                    dayContent(date)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.secondarySystemBackground))
                        )
                } else {
                    // Placeholder for preceding/following month days
                    Text("")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
    }

    // MARK: - Date helpers

    private var displayedMonth: Date {
        let calendar = Calendar.current
        let now = Date()
        return calendar.date(byAdding: .month, value: monthOffset, to: startOfMonth(for: now)) ?? now
    }

    private func monthTitle(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "LLLL yyyy" // e.g., September 2025
        return fmt.string(from: date)
    }

    private func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? date
    }

    private func datesForMonth(_ month: Date) -> [Date] {
        let calendar = Calendar.current
        let start = startOfMonth(for: month)
        guard let range = calendar.range(of: .day, in: .month, for: start) else { return [] }

        // Determine the weekday offset for the first day (so grid starts on the locale's firstWeekday)
        let firstWeekdayIndex = calendar.component(.weekday, from: start) // 1..7 where 1 = Sunday (locale dependent)
        let leadingEmpty = (firstWeekdayIndex - calendar.firstWeekday + 7) % 7

        // Build array with leading placeholders from previous month, then actual days, then trailing placeholders
        var dates: [Date] = []

        // Leading placeholders (previous month days, but we render them empty)
        if leadingEmpty > 0 {
            for i in stride(from: leadingEmpty, to: 0, by: -1) {
                if let d = calendar.date(byAdding: .day, value: -i, to: start) {
                    dates.append(d)
                }
            }
        }

        // Actual month days
        for day in range {
            if let d = calendar.date(byAdding: .day, value: day - 1, to: start) {
                dates.append(d)
            }
        }

        // Trailing placeholders to complete the final week row to 7 columns
        let remainder = dates.count % 7
        if remainder != 0 {
            let needed = 7 - remainder
            if let last = dates.last {
                for i in 1...needed {
                    if let d = calendar.date(byAdding: .day, value: i, to: last) {
                        dates.append(d)
                    }
                }
            }
        }

        return dates
    }
}

struct WorkoutRow: View {
    let session: WorkoutSession
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.name).font(.headline).foregroundColor(.primary)
            HStack {
                Image(systemName: "calendar")
                Text(session.date, style: .date)
            }.font(.subheadline).foregroundStyle(Color(.systemOrange))
            HStack {
                Image(systemName: "number")
                Text("\(session.exercises.count) exercises")
            }.font(.subheadline).foregroundStyle(Color(.systemGreen))
        }.padding(.vertical, 8)
    }
}

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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Start", action: startWorkout).disabled(workoutName.isEmpty) }
            }
            .navigationDestination(item: $newWorkoutSession) { session in
                 ActiveWorkoutView(session: session, onFinish: {
                    newWorkoutSession = nil
                    dismiss()
                 })
            }
        }
    }
    
    private func startWorkout() {
        let newSession = WorkoutSession(name: workoutName, date: .now)
        modelContext.insert(newSession)
        try? modelContext.save()
        self.newWorkoutSession = newSession
    }
}

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
                    Label("Add Exercise", systemImage: "plus").font(.headline).frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).controlSize(.large).tint(.cyan)
                Button(action: finishWorkout) {
                    Text("Finish Workout").font(.headline).frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).controlSize(.large)
            }.padding()
        }
        .navigationTitle(session.name)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isShowingAddExerciseSheet) { AddExerciseView(session: session) }
    }
    
    private func finishWorkout() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onFinish()
    }

    private func deleteExercise(at offsets: IndexSet) {
        session.exercises.remove(atOffsets: offsets)
    }
}

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: WorkoutSession
    @State private var exerciseName = ""
    @State private var sets: [ExerciseSet] = [ExerciseSet(reps: 8, weight: 100.0)]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Exercise Name")) { TextField("e.g., Barbell Bench Press", text: $exerciseName) }
                Section(header: Text("Sets")) {
                    ForEach($sets) { $set in
                        HStack(spacing: 15) {
                            Text("Reps:")
                            TextField("Reps", value: $set.reps, formatter: NumberFormatter()).keyboardType(.numberPad)
                            Text("Weight:")
                            TextField("Weight", value: $set.weight, formatter: NumberFormatter()).keyboardType(.decimalPad)
                            Text("lbs")
                        }
                    }.onDelete { indices in sets.remove(atOffsets: indices) }
                    Button("Add Set", systemImage: "plus") { sets.append(ExerciseSet(reps: 8, weight: 100.0)) }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Save", action: saveExercise).disabled(exerciseName.isEmpty || sets.isEmpty) }
            }
        }
    }
    
    private func saveExercise() {
        let newExercise = LoggedExercise(name: exerciseName, sets: sets)
        session.exercises.append(newExercise)
        dismiss()
    }
}

struct WorkoutDetailView: View {
    let session: WorkoutSession
    var body: some View {
        List {
            Section(header: Text("Details")) {
                HStack { Image(systemName: "text.badge.checkmark").foregroundStyle(Color(.systemGreen)); Text(session.name) }
                HStack { Image(systemName: "calendar").foregroundStyle(Color(.systemOrange)); Text(session.date, style: .date) }
            }
            Section(header: Text("Exercises")) {
                if session.exercises.isEmpty {
                    Text("No exercises were logged for this session.").foregroundColor(.secondary)
                } else {
                    ForEach(session.exercises) { exercise in
                        DisclosureGroup(exercise.name) {
                            VStack(alignment: .leading) {
                                ForEach(exercise.sets.indices, id: \.self) { index in
                                    SetRowView(set: exercise.sets[index], setNumber: index + 1).padding(.vertical, 4)
                                }
                            }
                        }.font(.headline)
                    }
                }
            }
        }.navigationTitle("Workout Summary")
    }
}

struct SetRowView: View {
    let set: ExerciseSet
    let setNumber: Int
    var body: some View {
        HStack {
            Text("Set \(setNumber)").fontWeight(.medium).frame(width: 60, alignment: .leading)
            Spacer()
            Text("\(set.reps)").frame(width: 50)
            Text("reps").foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.1f", set.weight)).frame(width: 60)
            Text("lbs").foregroundColor(.secondary)
        }.font(.body)
    }
}

// MARK: - Previews

#Preview {
    ContentView()
        .modelContainer(for: WorkoutSession.self, inMemory: true)
}
