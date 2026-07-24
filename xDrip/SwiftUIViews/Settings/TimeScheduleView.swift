//
//  TimeScheduleView.swift
//  xdrip
//
//  Created by Paul Plant on 22/6/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

// Schedule editor used by Settings options that store one or more daily times.
final class TimeScheduleViewModel: ObservableObject {
    @Published var schedule: [Int]
    @Published var datePicker: SettingsDatePickerContent?
    @Published var deleteConfirmation: TimeScheduleDeleteConfirmation?

    let serviceName: String

    private let timeSchedule: TimeSchedule

    /// Loads the stored schedule and adds the generated midnight row that is shown
    /// in the UI but is not written back to storage.
    init(timeSchedule: TimeSchedule) {
        self.timeSchedule = timeSchedule
        self.schedule = [0] + timeSchedule.getSchedule()
        self.serviceName = timeSchedule.serviceName()
    }

    /// Starts the add flow at the end of the current schedule.
    /// The first possible time is one minute after the last stored transition.
    func addScheduleEntry() {
        guard let minimumStart = schedule.last else { return }

        showTimePicker(
            minimumStart: minimumStart,
            maximumStart: 1440,
            indexInSchedule: nil
        )
    }

    /// Opens the pushed time picker for an existing transition.
    /// The neighbouring schedule entries define the allowed time range so the
    /// schedule stays ordered and valid.
    func editScheduleEntry(at index: Int) {
        guard index > 0, index < schedule.count else { return }

        showTimePicker(
            minimumStart: schedule[index - 1],
            maximumStart: index == schedule.count - 1 ? 1440 : schedule[index + 1],
            indexInSchedule: index
        )
    }

    /// Deletes a transition and immediately stores the updated schedule.
    /// The midnight entry is generated for display and is never deleted.
    func deleteScheduleEntry(at index: Int) {
        guard index > 0, index < schedule.count else { return }

        schedule.remove(at: index)
        storeSchedule()
    }

    /// Builds the shared pushed date picker content for adding or editing a
    /// schedule transition with the required limits and save/delete behavior.
    private func showTimePicker(minimumStart: Int, maximumStart: Int, indexInSchedule: Int?) {
        let midnight = Date().toMidnight()
        let selectedMinutes = indexInSchedule.map { schedule[$0] } ?? minimumStart + 1
        let indexNewOrUpdatedSchedule = indexInSchedule ?? schedule.count
        let subtitle = Texts_SettingsView.editScheduleTimePickerSubtitle + " " +
            (indexNewOrUpdatedSchedule % 2 == 0
                ? Texts_Common.off + " -> " + Texts_Common.on
                : Texts_Common.on + " -> " + Texts_Common.off)

        datePicker = SettingsDatePickerContent(
            title: nil,
            subtitle: subtitle,
            mode: .time,
            date: Date(timeInterval: TimeInterval(Double(selectedMinutes) * 60.0), since: midnight),
            minimumDate: Date(timeInterval: TimeInterval(Double(minimumStart + 1) * 60.0), since: midnight),
            maximumDate: Date(timeInterval: TimeInterval(Double(maximumStart - 1) * 60.0), since: midnight),
            okTitle: Texts_Common.Ok,
            cancelTitle: indexInSchedule == nil ? Texts_Common.Cancel : Texts_Common.delete,
            ok: { [weak self] newDate in
                self?.store(newDate: newDate, at: indexInSchedule)
            },
            cancel: { [weak self] in
                guard let indexInSchedule else { return }

                self?.deleteConfirmation = TimeScheduleDeleteConfirmation(index: indexInSchedule)
            }
        )
    }

    /// Inserts or updates the selected transition time before writing the schedule
    /// back through the existing TimeSchedule object.
    private func store(newDate: Date, at indexInSchedule: Int?) {
        if let indexInSchedule {
            schedule[indexInSchedule] = newDate.minutesSinceMidNightLocalTime()
        } else {
            schedule.append(newDate.minutesSinceMidNightLocalTime())
        }

        storeSchedule()
    }

    /// Stores the user-editable schedule without the generated midnight row.
    /// TimeSchedule owns the actual UserDefaults key and formatting.
    private func storeSchedule() {
        if schedule.count > 1 {
            timeSchedule.storeSchedule(schedule: Array(schedule[1..<schedule.count]))
        } else {
            timeSchedule.storeSchedule(schedule: [])
        }
    }
}

struct TimeScheduleDeleteConfirmation: Identifiable {
    let id = UUID()
    let index: Int
}

struct TimeScheduleView: View {
    @StateObject private var viewModel: TimeScheduleViewModel

    /// Owns the schedule view model for the lifetime of the pushed editor screen.
    init(timeSchedule: TimeSchedule) {
        _viewModel = StateObject(wrappedValue: TimeScheduleViewModel(timeSchedule: timeSchedule))
    }

    var body: some View {
        List {
            Section {
                ForEach(viewModel.schedule.indices, id: \.self) { index in
                    SettingsStaticRowView(
                        title: viewModel.schedule[index].convertMinutesToTimeAsString(),
                        detail: index % 2 == 0 ? Texts_Common.on : Texts_Common.off,
                        isEnabled: index != 0,
                        showsDisclosure: index != 0,
                        action: { viewModel.editScheduleEntry(at: index) }
                    )
                }
            }
        }
        .settingsListStyle(title: Texts_SettingsView.timeScheduleViewTitle, titleDisplayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: viewModel.addScheduleEntry) {
                    Image(systemName: "plus")
                }
            }
        }
        .settingsPushPresentation(datePicker: $viewModel.datePicker)
        .alert(item: $viewModel.deleteConfirmation) { confirmation in
            Alert(
                title: Text(Texts_Common.delete + " ?"),
                primaryButton: .destructive(Text(Texts_Common.delete)) {
                    viewModel.deleteScheduleEntry(at: confirmation.index)
                },
                secondaryButton: .cancel()
            )
        }
    }
}

struct SettingsDatePickerView: View {
    @State private var selectedDate: Date
    @State private var didComplete = false

    let datePicker: SettingsDatePickerContent
    let close: () -> Void
    private let initialDate: Date

    /// Starts the picker on the date supplied by the calling Settings row.
    init(datePicker: SettingsDatePickerContent, close: @escaping () -> Void) {
        self.datePicker = datePicker
        self.close = close
        self.initialDate = datePicker.date
        _selectedDate = State(initialValue: datePicker.date)
    }

    var body: some View {
        Form {
            if let subtitle = datePicker.subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .foregroundStyle(Color(.colorSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            DatePicker(
                datePicker.title ?? "",
                selection: selectionBinding,
                displayedComponents: datePicker.mode == .time ? .hourAndMinute : .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
        .scrollContentBackground(.hidden)
        .background(ConstantsUI.listBackGroundColor)
        .navigationTitle(datePicker.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if datePicker.cancelTitle != Texts_Common.Cancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button(datePicker.cancelTitle) {
                        didComplete = true
                        datePicker.cancel?()
                        close()
                    }
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(datePicker.okTitle) {
                    didComplete = true
                    datePicker.ok(selectedDate)
                    close()
                }
                .disabled(selectedDate == initialDate)
            }
        }
        .onDisappear {
            guard !didComplete, datePicker.cancelTitle == Texts_Common.Cancel else { return }

            datePicker.cancel?()
        }
        .colorScheme(.dark)
    }

    /// Clamps the picker selection to the valid range supplied by the calling row.
    /// SwiftUI's wheel picker can briefly move outside the requested limits, so the
    /// binding corrects that before the value is stored.
    private var selectionBinding: Binding<Date> {
        Binding {
            selectedDate
        } set: { newDate in
            if let minimumDate = datePicker.minimumDate, newDate < minimumDate {
                selectedDate = minimumDate
            } else if let maximumDate = datePicker.maximumDate, newDate > maximumDate {
                selectedDate = maximumDate
            } else {
                selectedDate = newDate
            }
        }
    }
}
