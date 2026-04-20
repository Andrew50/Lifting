//
//  WeightLogSheet.swift
//  Lifting
//

import SwiftUI

struct WeightLogSheet: View {
    @ObservedObject var bodyWeightStore: BodyWeightStore
    let existingEntry: BodyWeightEntryRecord?
    /// When opening from the Workout tab body-weight card, pre-fills the field (latest weight or empty).
    var prefilledWeightText: String?
    let onDismiss: () -> Void

    @State private var weightText: String = ""
    @State private var selectedDate: Date = Date()
    @FocusState private var isWeightFocused: Bool

    init(
        bodyWeightStore: BodyWeightStore,
        existingEntry: BodyWeightEntryRecord? = nil,
        prefilledWeightText: String? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.bodyWeightStore = bodyWeightStore
        self.existingEntry = existingEntry
        self.prefilledWeightText = prefilledWeightText
        self.onDismiss = onDismiss
    }

    private var parsedWeight: Double? {
        let normalized = weightText.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    HStack {
                        TextField("0.0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .focused($isWeightFocused)

                        Text("lbs")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(16)
                    .background(AppTheme.fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .padding(.horizontal, 20)

                Spacer()

                if existingEntry != nil {
                    Button(role: .destructive) {
                        if let entry = existingEntry {
                            try? bodyWeightStore.deleteEntry(id: entry.id)
                        }
                        onDismiss()
                    } label: {
                        Text("Delete Entry")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: "#DC2626"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#FEE2E2"))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle(existingEntry == nil ? "Log Weight" : "Edit Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let weight = parsedWeight, weight > 0 {
                            if let existing = existingEntry {
                                let newStr = BodyWeightStore.dateString(from: selectedDate)
                                if existing.date != newStr {
                                    try? bodyWeightStore.deleteEntry(id: existing.id)
                                }
                            }
                            try? bodyWeightStore.logWeight(weight, date: selectedDate)
                        }
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled((parsedWeight ?? 0) <= 0)
                }
            }
            .onAppear {
                if let entry = existingEntry {
                    weightText = String(format: "%.1f", entry.weight)
                    if let date = DateFormatter.yyyymmdd.date(from: entry.date) {
                        selectedDate = min(date, Date())
                    }
                } else if let pre = prefilledWeightText {
                    weightText = pre
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isWeightFocused = true
                }
            }
        }
    }
}

extension DateFormatter {
    static let yyyymmdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
