//
//  AuthTheme.swift
//  Lifting
//

import SwiftUI

enum AuthTheme {
    static let primary = Color(red: 106 / 255, green: 90 / 255, blue: 205 / 255)  // #6A5ACD
    static let socialButtonBackground = Color(red: 253 / 255, green: 216 / 255, blue: 53 / 255)  // #FDD835
    static let labelGray = Color(red: 0.35, green: 0.35, blue: 0.38)
    static let subtitleGray = Color(red: 0.45, green: 0.45, blue: 0.5)
    static let fieldBackground = Color(red: 0.94, green: 0.94, blue: 0.94)  // #F0F0F0
    static let fieldText = Color(red: 0.2, green: 0.2, blue: 0.2)
}

struct AuthLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(AuthTheme.labelGray)
            .textCase(.uppercase)
    }
}

struct AuthTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AuthTheme.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .foregroundStyle(AuthTheme.fieldText)
    }
}

struct PrimaryAuthButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AuthTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

struct SocialAuthButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(AuthTheme.fieldText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(AuthTheme.socialButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}
