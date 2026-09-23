import SwiftUI

struct LoginView: View {
    @ObservedObject private var auth = AuthService.shared

    @State private var username = ""
    @State private var password = ""
    @FocusState private var focused: Field?

    private enum Field { case username, password }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()

            VStack(spacing: DS.Spacing.sm) {
                Text(APIConfig.brand)
                    .font(DS.FontToken.display(28))
                    .foregroundStyle(DS.ColorToken.text)
                Text("Sign in to see jobs matched to your profile.")
                    .font(DS.FontToken.caption)
                    .foregroundStyle(DS.ColorToken.textMuted)
            }

            VStack(spacing: 12) {
                TextField("Username", text: $username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused, equals: .username)
                    .submitLabel(.next)
                    .onSubmit { focused = .password }

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focused, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { submit() }
            }
            .textFieldStyle(.plain)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: DS.Radius.md).fill(DS.ColorToken.surface))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.ColorToken.border, lineWidth: 1))

            if let error = auth.errorMessage {
                Text(error)
                    .font(DS.FontToken.caption)
                    .foregroundStyle(DS.ColorToken.warning)
                    .multilineTextAlignment(.center)
            }

            Button(action: submit) {
                HStack {
                    if auth.isWorking { ProgressView().tint(.white) }
                    Text("Sign in").font(DS.FontToken.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(canSubmit ? DS.ColorToken.primary : DS.ColorToken.textFaint))
                .foregroundStyle(.white)
            }
            .disabled(!canSubmit)

            Spacer()

            Text("Your sign-in is stored in the device Keychain and never leaves this device.")
                .font(DS.FontToken.caption)
                .foregroundStyle(DS.ColorToken.textFaint)
                .multilineTextAlignment(.center)
        }
        .padding(DS.Spacing.lg)
        .background(DS.ColorToken.background.ignoresSafeArea())
    }

    private var canSubmit: Bool {
        !username.isEmpty && !password.isEmpty && !auth.isWorking
    }

    private func submit() {
        guard canSubmit else { return }
        focused = nil
        Task { await auth.signIn(username: username, password: password) }
    }
}
