//
//  EditDisplayNameSheet.swift
//  Lifting
//

import SwiftUI

struct EditDisplayNameSheet: View {
    @ObservedObject var authStore: AuthStore
    let onDismiss: () -> Void

    @State private var nameText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    TextField("Your name", text: $nameText)
                        .font(.system(size: 17))
                        .foregroundStyle(AppTheme.textPrimary)
                        .focused($isFocused)
                        .padding(14)
                        .background(AppTheme.fieldBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Text("This is how your name appears on the home screen and throughout the app.")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 20)

                Spacer()
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        authStore.setDisplayName(nameText)
                        onDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                nameText = authStore.displayName == "there" ? "" : authStore.displayName
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isFocused = true
                }
            }
        }
    }
}
