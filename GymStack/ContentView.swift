//
//  ContentView.swift
//  GymStack
//
//  Created by Rohan Kewalramani on 9/6/25.
//

import SwiftUI
import SwiftData
import Combine

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
        .tint(.cyan)
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
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                
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
                            Text(session.name).font(.caption2).lineLimit(1).padding(4).background(Color.cyan.opacity(0.2)).cornerRadius(4)
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
    private var monthGrid: some View { let dates = datesForMonth(displayedMonth); return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) { ForEach(dates, id: \.self) { date in if Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month) { dayContent(date).frame(maxWidth: .infinity, minHeight: 44).background(RoundedRectangle(cornerRadius: 6).fill(Color(.secondarySystemBackground))) } else { Text("").frame(maxWidth: .infinity, minHeight: 44) } } } }
    private func monthTitle(for date: Date) -> String { date.formatted(.dateTime.year().month(.wide)) }
    private func startOfMonth(for date: Date) -> Date { let comps = Calendar.current.dateComponents([.year, .month], from: date); return Calendar.current.date(from: comps) ?? date }
    private func datesForMonth(_ month: Date) -> [Date] { let cal = Calendar.current; let start = startOfMonth(for: month); guard let range = cal.range(of: .day, in: .month, for: start) else { return [] }; let firstWeekdayIndex = cal.component(.weekday, from: start); let leadingEmpty = (firstWeekdayIndex - cal.firstWeekday + 7) % 7; var dates: [Date] = []; if leadingEmpty > 0 { for i in stride(from: leadingEmpty, to: 0, by: -1) { if let d = cal.date(byAdding: .day, value: -i, to: start) { dates.append(d) } } }; for day in range { if let d = cal.date(byAdding: .day, value: day - 1, to: start) { dates.append(d) } }; let remainder = dates.count % 7; if remainder != 0 { let needed = 7 - remainder; if let last = dates.last { for i in 1...needed { if let d = cal.date(byAdding: .day, value: i, to: last) { dates.append(d) } } } }; return dates }
}

struct WorkoutRow: View {
    let session: WorkoutSession
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.name).font(.headline).foregroundColor(.primary)
            HStack { Image(systemName: "calendar"); Text(session.date, style: .date) }.font(.subheadline).foregroundStyle(Color(.systemOrange))
            HStack { Image(systemName: "number"); Text("\(session.exercises.count) exercises") }.font(.subheadline).foregroundStyle(Color(.systemGreen))
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
    
    @State private var isTimerActive = false
    @State private var timerKey = UUID()
    @AppStorage("restDuration") private var restDuration: Int = 90
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                if session.exercises.isEmpty {
                     ContentUnavailableView("Empty Workout", systemImage: "figure.strengthtraining.traditional", description: Text("Tap 'Add Exercise' to log your first exercise."))
                } else {
                    List {
                        ForEach(session.exercises) { exercise in
                            ExerciseSectionView(exercise: exercise, onAddSet: startTimer)
                        }
                        .onDelete(perform: deleteExercise)
                    }
                    .listStyle(.insetGrouped)
                }
                
                VStack(spacing: 12) {
                    Button(action: { isShowingAddExerciseSheet = true }) { Label("Add Exercise", systemImage: "plus").font(.headline).frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).controlSize(.large).tint(.cyan)
                    Button(action: finishWorkout) { Text("Finish Workout").font(.headline).frame(maxWidth: .infinity) }.buttonStyle(.bordered).controlSize(.large)
                }.padding()
            }
            
            if isTimerActive {
                RestTimerView(duration: restDuration, onFinish: { isTimerActive = false })
                    .id(timerKey)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(session.name)
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $isShowingAddExerciseSheet) {
            AddExerciseView(session: session)
                .environment(\.modelContext, modelContext)
        }
    }
    
    private func startTimer() {
        withAnimation { isTimerActive = true }
        timerKey = UUID()
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
    var onAddSet: () -> Void
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .lbs
    
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
                onAddSet()
            }
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
    // --- FIX: Add state for exercise notes ---
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
                
                // --- FIX: Add section for notes input ---
                Section(header: Text("Notes (Optional)")) {
                    TextField("e.g., focus on form, go slow", text: $exerciseNotes, axis: .vertical)
                        .lineLimit(3...)
                }
                
                Section(header: Text("Sets")) {
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
        // --- FIX: Pass notes into the initializer ---
        let newExercise = LoggedExercise(name: exerciseName, notes: exerciseNotes, sets: sets)
        session.exercises.append(newExercise)
        try? modelContext.save()
        dismiss()
    }
}

struct WorkoutDetailView: View {
    @Bindable var session: WorkoutSession
    @State private var isEditingSession = false
    
    @State private var editingExercise: LoggedExercise?
    @State private var editingSet: ExerciseSet?
    
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .lbs

    var body: some View {
        List {
            Section(header: Text("Details")) {
                HStack { Image(systemName: "text.badge.checkmark").foregroundStyle(Color(.systemGreen)); Text(session.name) }
                HStack { Image(systemName: "calendar").foregroundStyle(Color(.systemOrange)); Text(session.date, style: .date) }
            }
            Section(header: Text("Exercises")) {
                if session.exercises.isEmpty {
                    Text("No exercises were logged.").foregroundColor(.secondary)
                } else {
                    ForEach(session.exercises) { exercise in
                        DisclosureGroup(exercise.name) {
                            VStack(alignment: .leading, spacing: 10) {
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
    }
}

struct SetRowView: View {
    let set: ExerciseSet
    let setNumber: Int
    let unit: String
    var body: some View {
        HStack {
            Text("Set \(setNumber)").fontWeight(.medium).frame(width: 60, alignment: .leading)
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

struct RestTimerView: View {
    let duration: Int
    var onFinish: () -> Void
    
    @State private var remainingTime: Int
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(duration: Int, onFinish: @escaping () -> Void) {
        self.duration = duration
        self._remainingTime = State(initialValue: duration)
        self.onFinish = onFinish
    }
    
    var body: some View {
        HStack {
            Image(systemName: "timer")
                .font(.headline)
            Text("Rest: \(remainingTime)s")
                .font(.headline.monospacedDigit())
            
            ProgressView(value: Double(remainingTime), total: Double(duration))
                .progressViewStyle(.linear)
                .tint(.cyan)

            Button(action: onFinish) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onReceive(timer) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                timer.upstream.connect().cancel()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onFinish()
            }
        }
        .onDisappear {
            timer.upstream.connect().cancel()
        }
    }
}


// MARK: - Previews
#Preview {
    ContentView()
        .modelContainer(for: [WorkoutSession.self, LoggedExercise.self, ExerciseSet.self], inMemory: true)
}

