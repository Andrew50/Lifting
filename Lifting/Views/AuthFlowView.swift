//
//  AuthFlowView.swift
//  Lifting
//
//  Wraps Create Account and Log in in a NavigationStack so you can
//  present this view (e.g. as root when not logged in, or from a tab).
//

import SwiftUI

struct AuthFlowView: View {
    @ObservedObject var authStore: AuthStore

    var body: some View {
        NavigationStack {
            CreateAccountView(authStore: authStore)
        }
    }
}

#Preview {
    AuthFlowView(authStore: AppContainer().authStore)
}
