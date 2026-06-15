import SwiftUI

/// Email + 6-digit code sign-in (invite-only). Mirrors the web /login flow:
/// signInWithOTP(shouldCreateUser: false) then verifyOTP. No passwords, ever.
struct LoginView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.palette) private var palette
    private let client = Supa.shared.client

    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ZStack {
            SculptBackground()
            VStack(spacing: 0) {
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Eyebrow("Training tracker")
                    Text("SCULPT").font(.sans(40, weight: .light)).tracking(8)
                        .foregroundStyle(palette.ink)
                }
                .padding(.bottom, 36)

                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        if !codeSent {
                            Text("Sign in with your invited email — a 6-digit code lands in your inbox.")
                                .font(.sans(15, weight: .light)).foregroundStyle(palette.inkSoft)
                            TextField("you@example.com", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .fieldStyle(palette)
                            PillButton(title: busy ? "Sending…" : "Send code") { Task { await sendCode() } }
                                .disabled(busy || email.isEmpty)
                        } else {
                            Text("Enter the 6-digit code sent to \(email).")
                                .font(.sans(15, weight: .light)).foregroundStyle(palette.inkSoft)
                            TextField("000000", text: $code)
                                .keyboardType(.numberPad)
                                .font(.mono(24, weight: .medium))
                                .multilineTextAlignment(.center)
                                .fieldStyle(palette)
                            PillButton(title: busy ? "Verifying…" : "Verify") { Task { await verify() } }
                                .disabled(busy || code.count < 6)
                            Button("Use a different email") { codeSent = false; code = "" }
                                .font(.sans(13, weight: .light)).foregroundStyle(palette.inkSoft)
                        }
                        if let error {
                            Text(error).font(.sans(13)).foregroundStyle(palette.blushDeep)
                        }
                    }
                    .padding(20)
                }
                Spacer(); Spacer()
            }
            .padding(24)
        }
    }

    private func sendCode() async {
        busy = true; error = nil
        do {
            try await client.auth.signInWithOTP(
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                shouldCreateUser: false
            )
            codeSent = true
        } catch {
            self.error = "Couldn't send a code. Check the address, or ask for an invite."
        }
        busy = false
    }

    private func verify() async {
        busy = true; error = nil
        do {
            try await client.auth.verifyOTP(
                email: email.trimmingCharacters(in: .whitespaces).lowercased(),
                token: code.trimmingCharacters(in: .whitespaces),
                type: .email
            )
            await session.refresh()
        } catch {
            self.error = "That code didn't work. Try again."
        }
        busy = false
    }
}

extension View {
    /// Shared text-field chrome — a soft surface pill.
    func fieldStyle(_ palette: Palette) -> some View {
        self
            .padding(.vertical, 12).padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(palette.edge))
            .foregroundStyle(palette.ink)
    }
}
