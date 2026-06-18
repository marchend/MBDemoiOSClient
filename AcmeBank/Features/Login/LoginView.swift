import SwiftUI

/// Root login screen view.
///
/// Composes `OktaHeaderView`, scrollable form content, and `OktaFooterView`
/// into the full sign-in layout. All navigation is delegated to closure
/// injection points on the `LoginViewModel` so the view itself has no
/// knowledge of coordinators or routing.
struct LoginView: View {

    // MARK: - ViewModel

    @StateObject private var viewModel: LoginViewModel

    /// Designated init accepting an externally created ViewModel — used by
    /// coordinators and unit / UI tests for dependency injection.
    init(viewModel: LoginViewModel = LoginViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    // MARK: - Local state

    @State private var isNeedHelpSheetPresented = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                OktaHeaderView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        logoAndTitle
                        usernameField
                        passwordField
                        ErrorBannerView(message: viewModel.errorMessage)
                        keepSignedInRow
                        signInButton
                        openOneRow
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }

                OktaFooterView()
            }
            .background(Color.acmeBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $isNeedHelpSheetPresented) {
            NeedHelpSheet()
        }
    }

    // MARK: - Subcomponents

    private var logoAndTitle: some View {
        VStack(alignment: .center, spacing: 16) {
            AcmeBankLogoView()
                .frame(maxWidth: .infinity, alignment: .center)

            Text("Sign in to AcmeBank")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.acmeNavy)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityAddTraits(.isHeader)

            Text("Enter your username and password to continue.")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Username")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.primary)

            TextField("name@acmebank.com", text: $viewModel.username)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textContentType(.username)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.acmeBorder, lineWidth: 1)
                )
                .accessibilityLabel("Username")
                .accessibilityIdentifier("usernameField")
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Password")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.primary)

            HStack(spacing: 0) {
                // Both fields stay in the hierarchy simultaneously; only opacity
                // and interaction are toggled. This prevents the keyboard from
                // dismissing and typed text from being lost when the user taps
                // the eye icon (SwiftUI would otherwise destroy and re-create
                // the underlying UITextField on every if/else branch swap).
                Group {
                    TextField("Enter your password", text: $viewModel.password)
                        .textContentType(.password)
                        .opacity(viewModel.isPasswordVisible ? 1 : 0)
                        .disabled(!viewModel.isPasswordVisible)
                        .overlay(
                            SecureField("Enter your password", text: $viewModel.password)
                                .textContentType(.password)
                                .opacity(viewModel.isPasswordVisible ? 0 : 1)
                                .disabled(viewModel.isPasswordVisible)
                        )
                }
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(.leading, 12)
                .padding(.vertical, 12)
                .accessibilityIdentifier("passwordField")

                Button {
                    viewModel.togglePasswordVisibility()
                } label: {
                    Image(
                        systemName: viewModel.isPasswordVisible
                            ? "eye.slash"
                            : "eye"
                    )
                    .foregroundStyle(Color.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(
                    viewModel.isPasswordVisible
                        ? "Hide password"
                        : "Show password"
                )
                .accessibilityIdentifier("passwordVisibilityToggle")
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.acmeBorder, lineWidth: 1)
            )
        }
    }

    private var keepSignedInRow: some View {
        HStack(alignment: .center) {
            Button {
                viewModel.keepSignedIn.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(
                        systemName: viewModel.keepSignedIn
                            ? "checkmark.square.fill"
                            : "square"
                    )
                    .foregroundStyle(
                        viewModel.keepSignedIn
                            ? Color.acmeNavy
                            : Color.secondary
                    )
                    .font(.body)

                    Text("Keep me signed in")
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                }
                .frame(minHeight: 44)
            }
            .accessibilityLabel("Keep me signed in")
            .accessibilityValue(viewModel.keepSignedIn ? "checked" : "unchecked")
            .accessibilityIdentifier("keepSignedInToggle")

            Spacer()

            // The view owns the Help sheet presentation entirely.
            // onNeedHelp() is intentionally not called here so that when
            // the coordinator is wired in a future PR it cannot cause a
            // double-presentation conflict.
            Button("Need help?") {
                isNeedHelpSheetPresented = true
            }
            .font(.subheadline)
            .foregroundStyle(Color.acmeNavy)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("needHelpButton")
        }
    }

    private var signInButton: some View {
        Button {
            viewModel.signInTapped()
        } label: {
            Text("Sign in")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.vertical, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    viewModel.isSignInEnabled
                        ? Color.acmeNavy
                        : Color.acmeNavy.opacity(0.4)
                )
        )
        .disabled(!viewModel.isSignInEnabled)
        .accessibilityLabel("Sign in")
        .accessibilityIdentifier("signInButton")
    }

    private var openOneRow: some View {
        HStack(spacing: 4) {
            Text("Don't have an account?")
                .font(.subheadline)
                .foregroundStyle(Color.secondary)

            NavigationLink(destination: OpenAccountPlaceholderView()) {
                Text("Open one")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.acmeNavy)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityIdentifier("openAccountLink")
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Need Help sheet

private struct NeedHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.acmeNavy)

                Text("Need Help?")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.acmeNavy)

                Text("Visit the Okta Help Center for account recovery, password resets, and more.")
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let supportURL = URL(string: "https://support.okta.com") {
                    Link("Visit Okta Support", destination: supportURL)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.acmeNavy)
                        .frame(minHeight: 44)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .accessibilityIdentifier("closeHelpSheet")
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Empty state") {
    LoginView()
}

#Preview("Filled state") {
    let vm = LoginViewModel()
    vm.username = "user@acmebank.com"
    vm.password = "password123"
    return LoginView(viewModel: vm)
}

#Preview("Error banner") {
    let vm = LoginViewModel()
    vm.username = "user@acmebank.com"
    vm.password = "wrongpassword"
    vm.errorMessage = "Your username or password is incorrect. Please try again."
    return LoginView(viewModel: vm)
}

#Preview("Password revealed") {
    let vm = LoginViewModel()
    vm.username = "user@acmebank.com"
    vm.password = "password123"
    vm.isPasswordVisible = true
    return LoginView(viewModel: vm)
}
