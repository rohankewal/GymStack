//
//  ContentView.swift
//  GymStack
//
//  Created by Rohan Kewalramani on 9/6/25.
//

import SwiftUI
import SwiftData
import Combine
import UserNotifications
import AudioToolbox

// MARK: - Theme
private struct ColorTheme {
    // Core brand colors
    static let primary = Color.teal
    static let accent = Color.indigo

    // Surfaces
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)

    // Semantic accents
    static let success = Color.green
    static let warning = Color.orange
    static let info = Color.blue

    // Text
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
}

private struct ThemedProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(ColorTheme.primary.opacity(configuration.isPressed ? 0.85 : 1.0))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct ThemedBorderedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(ColorTheme.accent.opacity(configuration.isPressed ? 0.6 : 1.0), lineWidth: 1)
            )
            .foregroundStyle(ColorTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - 1. Data Models

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
    var notes: String
    @Relationship(deleteRule: .cascade) var sets: [ExerciseSet] = []
    var session: WorkoutSession?
    
    init(id: UUID = UUID(), name: String, notes: String = "", sets: [ExerciseSet] = []) {
        self.id = id
        self.name = name
        self.notes = notes
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

enum WeightUnit: String, CaseIterable, Identifiable {
    case lbs, kg
    var id: Self { self }
}

// --- TIMER REPLACEMENT: Notification Manager ---
// This class handles asking for permission and scheduling the rest timer notifications.
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager() // Singleton for easy access

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // Call this early in app lifecycle to prompt for permission
    func configure() {
        requestAuthorization()
    }

    private func requestAuthorization() {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .timeSensitive]
        UNUserNotificationCenter.current().requestAuthorization(options: options) { (granted, error) in
            if let error = error {
                print("[NotificationManager] Error requesting authorization: \(error.localizedDescription)")
            }
        }
    }

    func scheduleRestNotification(duration: Int) {
        let duration = max(1, duration)
        let content = UNMutableNotificationContent()
        content.title = "Rest Over!"
        content.body = "Time for your next set."
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(duration), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule rest notification: \(error.localizedDescription)")
            }
        }
    }

    // Public entry point used by UI when a new set is added
    func startRestTimer(duration: Int) {
        let duration = max(1, duration)
        // Schedule local notification
        scheduleRestNotification(duration: duration)
        // Also start a foreground fallback haptic + sound so the user gets feedback even if notifications are suppressed
        startFallbackHapticTimer(duration: duration)
    }

    private func startFallbackHapticTimer(duration: Int) {
        let deadline = DispatchTime.now() + .seconds(duration)
        DispatchQueue.main.asyncAfter(deadline: deadline) {
            if #available(iOS 13.0, *) {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                generator.impactOccurred()
            }
            // Try an alternate system sound ID that is commonly audible
            AudioServicesPlaySystemSound(1005)
        }
    }

    // Foreground presentation: show alert/sound and provide a light haptic buzz
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Light haptic when the rest ends while app is in foreground
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        // Present banner/sound/list in foreground as well
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .list])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}


// MARK: - 3. Main View with TabBar
struct ContentView: View {
    var body: some View {
        TabView {
            WorkoutHistoryView()
                .tabItem { Label("History", systemImage: "list.bullet") }
            
            WorkoutCalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
            
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .tint(ColorTheme.primary)
    }
}


// MARK: - 4. Tab Views

struct WorkoutHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    
    @State private var isShowingNewWorkoutSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTheme.background.edgesIgnoringSafeArea(.all)
                
                if workoutSessions.isEmpty {
                    ContentUnavailableView("No Workouts Logged", systemImage: "figure.run.circle", description: Text("Tap the '+' button to start your first workout."))
                } else {
                    List {
                        ForEach(workoutSessions) { session in
                            NavigationLink(destination: WorkoutDetailView(session: session)) {
                                WorkoutRow(session: session)
                            }
                            .contextMenu {
                                Button(action: { duplicate(session: session) }) {
                                    Label("Duplicate Workout", systemImage: "plus.square.on.square")
                                }
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
                        Image(systemName: "plus.circle.fill").font(.headline)
                    }
                }
            }
            .sheet(isPresented: $isShowingNewWorkoutSheet) {
                StartWorkoutView()
                    .environment(\.modelContext, modelContext)
            }
        }
    }
    
    private func deleteWorkouts(offsets: IndexSet) {
        withAnimation {
            for index in offsets { modelContext.delete(workoutSessions[index]) }
        }
    }
    
    private func duplicate(session: WorkoutSession) {
        let newSession = WorkoutSession(name: session.name, date: .now)
        
        for exercise in session.exercises {
            let newExercise = LoggedExercise(name: exercise.name, notes: exercise.notes)
            newSession.exercises.append(newExercise)
            
            for exerciseSet in exercise.sets {
                let newSet = ExerciseSet(reps: exerciseSet.reps, weight: exerciseSet.weight)
                newExercise.sets.append(newSet)
            }
        }
        
        withAnimation {
            modelContext.insert(newSession)
            try? modelContext.save()
        }
    }
}

struct WorkoutCalendarView: View {
    @Query(sort: \WorkoutSession.date, order: .reverse) private var workoutSessions: [WorkoutSession]
    
    var body: some View {
        NavigationStack {
            CalendarView { date in
                VStack(spacing: 4) {
                    Text(dayString(from: date)).font(.headline).frame(maxWidth: .infinity, alignment: .center)
                    let workoutsForDay = workouts(for: date)
                    if !workoutsForDay.isEmpty {
                        ForEach(workoutsForDay) { session in
                            Text(session.name).font(.caption2).lineLimit(1).padding(4).background(ColorTheme.primary.opacity(0.18)).cornerRadius(4)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Workout Calendar")
        }
    }
    
    private func dayString(from date: Date) -> String { Calendar.current.component(.day, from: date).formatted() }
    private func workouts(for date: Date) -> [WorkoutSession] { workoutSessions.filter { Calendar.current.isDate($0.date, inSameDayAs: date) } }
}

struct SettingsView: View {
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .lbs
    @AppStorage("restDuration") private var restDuration: Int = 90
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Workout Settings")) {
                    Picker("Weight Units", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.rawValue.uppercased()).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Stepper("Rest Timer: \(restDuration) seconds", value: $restDuration, in: 30...300, step: 15)
                }
            }
            .navigationTitle("Settings")
            .tint(ColorTheme.accent)
        }
    }
}


// MARK: - 5. Supporting Views

struct CalendarView<DayContent: View>: View {
    let dayContent: (Date) -> DayContent
    @State private var monthOffset: Int = 0
    init(@ViewBuilder dayContent: @escaping (Date) -> DayContent) { self.dayContent = dayContent }
    private var displayedMonth: Date { Calendar.current.date(byAdding: .month, value: monthOffset, to: startOfMonth(for: .now)) ?? .now }
    var body: some View { VStack(spacing: 8) { header; weekdayHeader; monthGrid }.padding() }
    private var header: some View { HStack { Button { monthOffset -= 1 } label: { Image(systemName: "chevron.left") }; Spacer(); Text(monthTitle(for: displayedMonth)).font(.headline); Spacer(); Button { monthOffset += 1 } label: { Image(systemName: "chevron.right") } } }
    private var weekdayHeader: some View { let symbols = Calendar.current.shortWeekdaySymbols; return HStack { ForEach(symbols, id: \.self) { symbol in Text(symbol).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity) } } }
    private var monthGrid: some View { let dates = datesForMonth(displayedMonth); return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) { ForEach(dates, id: \.self) { date in if Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month) { dayContent(date).frame(maxWidth: .infinity, minHeight: 44).background(RoundedRectangle(cornerRadius: 6).fill(ColorTheme.surface)) } else { Text("").frame(maxWidth: .infinity, minHeight: 44) } } } }
    private func monthTitle(for date: Date) -> String { date.formatted(.dateTime.year().month(.wide)) }
    private func startOfMonth(for date: Date) -> Date { let comps = Calendar.current.dateComponents([.year, .month], from: date); return Calendar.current.date(from: comps) ?? date }
    private func datesForMonth(_ month: Date) -> [Date] { let cal = Calendar.current; let start = startOfMonth(for: month); guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }; let firstWeekdayIndex = cal.component(.weekday, from: start); let leadingEmpty = (firstWeekdayIndex - cal.firstWeekday + 7) % 7; var dates: [Date] = []; if leadingEmpty > 0 { for i in stride(from: leadingEmpty, to: 0, by: -1) { if let d = cal.date(byAdding: .day, value: -i, to: start) { dates.append(d) } } }; for day in range { if let d = cal.date(byAdding: .day, value: day - 1, to: start) { dates.append(d) } }; let remainder = dates.count % 7; if remainder != 0 { let needed = 7 - remainder; if let last = dates.last { for i in 1...needed { if let d = cal.date(byAdding: .day, value: i, to: last) { dates.append(d) } } } }; return dates }
}

struct WorkoutRow: View {
    let session: WorkoutSession
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.name).font(.headline).foregroundColor(.primary)
            HStack { Image(systemName: "calendar"); Text(session.date, style: .date) }.font(.subheadline).foregroundStyle(ColorTheme.info)
            HStack { Image(systemName: "number"); Text("\(session.exercises.count) exercises") }.font(.subheadline).foregroundStyle(ColorTheme.success)
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
                Section(header: Text("Workout Details")) { TextField("Workout Name (e.g., Push Day)", text: $workoutName) }
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Start", action: startWorkout).disabled(workoutName.isEmpty) }
            }
            .navigationDestination(item: $newWorkoutSession) { session in
                 ActiveWorkoutView(session: session, onFinish: { newWorkoutSession = nil; dismiss() })
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
            if session.exercises.isEmpty {
                 ContentUnavailableView("Empty Workout", systemImage: "figure.strengthtraining.traditional", description: Text("Tap 'Add Exercise' to log your first exercise."))
            } else {
                List {
                    ForEach(session.exercises) { exercise in
                        ExerciseSectionView(exercise: exercise)
                    }
                    .onDelete(perform: deleteExercise)
                }
                .listStyle(.insetGrouped)
            }
            
            VStack(spacing: 12) {
                Button(action: { isShowingAddExerciseSheet = true }) { Label("Add Exercise", systemImage: "plus").font(.headline).frame(maxWidth: .infinity) }
                    .buttonStyle(ThemedProminentButtonStyle())
                    .controlSize(.large)
                Button(action: finishWorkout) { Text("Finish Workout").font(.headline).frame(maxWidth: .infinity) }
                    .buttonStyle(ThemedBorderedButtonStyle())
                    .controlSize(.large)
            }.padding()
        }
        .navigationTitle(session.name)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isShowingAddExerciseSheet) {
            AddExerciseView(session: session)
                .environment(\.modelContext, modelContext)
        }
    }
    
    private func finishWorkout() {
        try? modelContext.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onFinish()
    }

    private func deleteExercise(at offsets: IndexSet) {
        session.exercises.remove(atOffsets: offsets)
        try? modelContext.save()
    }
}

struct ExerciseSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var exercise: LoggedExercise
    
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .lbs
    @AppStorage("restDuration") private var restDuration: Int = 90
    
    var body: some View {
        Section {
            ForEach(exercise.sets.indices, id: \.self) { index in
                 SetRowView(set: exercise.sets[index], setNumber: index + 1, unit: weightUnit.rawValue)
            }
            .onDelete { indices in
                exercise.sets.remove(atOffsets: indices)
                try? modelContext.save()
            }
            
            Button("Add Set", systemImage: "plus") {
                let lastSet = exercise.sets.last ?? ExerciseSet(reps: 8, weight: 100)
                let newSet = ExerciseSet(reps: lastSet.reps, weight: lastSet.weight)
                exercise.sets.append(newSet)
                try? modelContext.save()
                // --- NOTIFICATION TIMER ---
                // This now schedules a local notification and fallback timer.
                NotificationManager.shared.startRestTimer(duration: restDuration)
            }
            .tint(ColorTheme.accent)
        } header: {
            Text(exercise.name).font(.headline)
        }
    }
}

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    
    @State private var exerciseName = ""
    @State private var exerciseNotes = ""
    @State private var sets: [ExerciseSet] = [ExerciseSet(reps: 8, weight: 100.0)]
    
    @Query(sort: \LoggedExercise.name) private var allExercises: [LoggedExercise]
    private var uniqueExerciseNames: [String] {
        Array(Set(allExercises.map { $0.name })).sorted()
    }
    private var filteredNames: [String] {
        guard !exerciseName.isEmpty else { return [] }
        return uniqueExerciseNames.filter { $0.lowercased().contains(exerciseName.lowercased()) }
    }
    
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .lbs
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Exercise Name")) {
                    TextField("e.g., Barbell Bench Press", text: $exerciseName)
                    if !filteredNames.isEmpty {
                        ForEach(filteredNames.prefix(3), id: \.self) { name in
                            Button(name) {
                                exerciseName = name
                            }
                        }
                    }
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextField("e.g., focus on form, go slow", text: $exerciseNotes, axis: .vertical)
                        .lineLimit(3...)
                }
                
                Section(header: Text("Sets"), footer: Text("After you add sets and save, a rest timer will start to match the in-workout Add Set button behavior.")) {
                    ForEach($sets) { $set in
                        HStack(spacing: 15) {
                            Text("Reps:").frame(width: 45)
                            TextField("Reps", value: $set.reps, formatter: NumberFormatter()).keyboardType(.numberPad)
                            Text("Weight:").frame(width: 55)
                            TextField("Weight", value: $set.weight, formatter: NumberFormatter()).keyboardType(.decimalPad)
                            Text(weightUnit.rawValue)
                        }
                    }.onDelete { indices in sets.remove(atOffsets: indices) }
                    Button("Add Set", systemImage: "plus") { sets.append(ExerciseSet(reps: 8, weight: 100.0)) }
                        .tint(ColorTheme.accent)
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
        let newExercise = LoggedExercise(name: exerciseName, notes: exerciseNotes, sets: sets)
        session.exercises.append(newExercise)
        try? modelContext.save()
        // Start a rest timer when sets are added from this flow to match in-workout behavior
        if !sets.isEmpty {
            // Use the same rest duration as settings
            let duration = UserDefaults.standard.integer(forKey: "restDuration")
            let resolved = duration > 0 ? duration : 90
            NotificationManager.shared.startRestTimer(duration: resolved)
        }
        dismiss()
    }
}

struct WorkoutDetailView: View {
    @Bindable var session: WorkoutSession
    @State private var isEditingSession = false
    
    @State private var editingExercise: LoggedExercise?
    @State private var editingSet: ExerciseSet?
    @State private var editingNotesExercise: LoggedExercise?
    
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .lbs

    var body: some View {
        List {
            Section(header: Text("Details")) {
                HStack { Image(systemName: "text.badge.checkmark").foregroundStyle(ColorTheme.primary); Text(session.name) }
                HStack { Image(systemName: "calendar").foregroundStyle(ColorTheme.info); Text(session.date, style: .date) }
            }
            Section(header: Text("Exercises")) {
                if session.exercises.isEmpty {
                    Text("No exercises were logged.").foregroundColor(.secondary)
                } else {
                    ForEach(session.exercises) { exercise in
                        DisclosureGroup(exercise.name) {
                            VStack(alignment: .leading, spacing: 10) {
                                Button(action: { editingNotesExercise = exercise }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: exercise.notes.isEmpty ? "plus.bubble" : "pencil.and.outline")
                                        Text(exercise.notes.isEmpty ? "Add Note" : "Edit Note")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                
                                if !exercise.notes.isEmpty {
                                    Text(exercise.notes).font(.caption).foregroundStyle(.secondary).padding(.bottom, 5)
                                }
                                ForEach(exercise.sets) { set in
                                    SetRowView(set: set, setNumber: (exercise.sets.firstIndex(of: set) ?? 0) + 1, unit: weightUnit.rawValue)
                                        .onTapGesture { editingSet = set }
                                }
                            }
                        }
                        .font(.headline)
                        .contextMenu {
                            Button("Edit Exercise", systemImage: "pencil") {
                                editingExercise = exercise
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                editingNotesExercise = exercise
                            } label: {
                                Label("Notes", systemImage: "pencil")
                            }.tint(ColorTheme.accent)
                        }
                    }
                }
            }
        }
        .navigationTitle("Workout Summary")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { isEditingSession = true }
            }
        }
        .sheet(isPresented: $isEditingSession) { EditSessionView(session: session) }
        .sheet(item: $editingExercise) { exercise in EditExerciseView(exercise: exercise) }
        .sheet(item: $editingSet) { set in EditSetView(set: set) }
        .sheet(item: $editingNotesExercise) { exercise in
            EditNotesView(exercise: exercise)
        }
    }
}

struct SetRowView: View {
    let set: ExerciseSet
    let setNumber: Int
    let unit: String
    var body: some View {
        HStack {
            Text("Set \(setNumber)").fontWeight(.semibold).foregroundStyle(ColorTheme.primary).frame(width: 60, alignment: .leading)
            Spacer()
            Text("\(set.reps)").frame(width: 50)
            Text("reps").foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.1f", set.weight)).frame(width: 60)
            Text(unit).foregroundColor(.secondary)
        }.font(.body)
    }
}

struct EditSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: WorkoutSession
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Workout Name") { TextField("Name", text: $session.name) }
                Section("Workout Date") { DatePicker("Date", selection: $session.date, displayedComponents: .date) }
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

struct EditExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: LoggedExercise
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") { TextField("Name", text: $exercise.name) }
                Section("Notes") { TextField("Notes (e.g. 'Felt strong')", text: $exercise.notes, axis: .vertical) }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

struct EditNotesView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: LoggedExercise

    var body: some View {
        NavigationStack {
            Form {
                Section("Notes") {
                    TextField("Notes (e.g. 'Felt strong, focus on tempo')", text: $exercise.notes, axis: .vertical)
                        .lineLimit(3...)
                }
            }
            .navigationTitle("Edit Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

struct EditSetView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var set: ExerciseSet
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .lbs
    
    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    Text("Reps:")
                    TextField("Reps", value: $set.reps, formatter: NumberFormatter()).keyboardType(.numberPad)
                }
                HStack {
                    Text("Weight (\(weightUnit.rawValue)):")
                    TextField("Weight", value: $set.weight, formatter: NumberFormatter()).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Previews
#Preview {
    ContentView()
        .modelContainer(for: [WorkoutSession.self, LoggedExercise.self, ExerciseSet.self], inMemory: true)
        .tint(ColorTheme.primary)
}

