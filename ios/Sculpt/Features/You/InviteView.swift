import SwiftUI

/// Admin invite — email someone a sign-in code via the `invite-user` Edge
/// Function. Mirrors the web /admin screen: the account is created and an email
/// is sent; a copyable message is always offered as a fallback.
struct InviteView: View {
    @Environment(\.palette) private var palette
    @State private var email = ""
    @State private var busy = false
    @State private var message: String?
    @State private var isError = false
    @State private var lastInvited: String?

    private var siteHint: String { "the Sculpt app" }

    var body: some View {
        ZStack {
            SculptBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow("Admin")
                        Text("Invite someone").font(.sans(26, weight: .light)).tracking(0.5)
                        Text("Creates their account (no password) and emails a 6-digit sign-in code. Invite-only — this is the only way new members join.")
                            .font(.sans(14, weight: .light)).foregroundStyle(palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Eyebrow("Their email")
                            TextField("friend@example.com", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .fieldStyle(palette)
                            PillButton(title: busy ? "Inviting…" : "Send invite") { Task { await send() } }
                                .disabled(busy || email.isEmpty)
                            if let message {
                                Text(message)
                                    .font(.sans(13, weight: .light))
                                    .foregroundStyle(isError ? palette.blushDeep : palette.sageDeep)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(18)
                    }

                    if let invited = lastInvited {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Eyebrow("Copyable message")
                                Text(copyText(for: invited))
                                    .font(.sans(13, weight: .light))
                                    .foregroundStyle(palette.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                                PillButton(title: "Copy", kind: .ghost, icon: "doc.on.doc") {
                                    UIPasteboard.general.string = copyText(for: invited)
                                }
                            }
                            .padding(18)
                        }
                    }
                }
                .padding(20)
            }
        }
        .foregroundStyle(palette.ink)
        .navigationTitle("Invite")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func copyText(for invited: String) -> String {
        "You're invited to Sculpt. Open \(siteHint) and sign in with \(invited) — a 6-digit code lands in your inbox. No password, ever."
    }

    private func send() async {
        busy = true; message = nil; isError = false
        let addr = email.trimmingCharacters(in: .whitespaces).lowercased()
        let res = await Repository.shared.inviteUser(email: addr)
        if res.ok {
            lastInvited = addr
            message = res.emailSent
                ? "Invited \(addr) — a sign-in code is on the way."
                : "Account ready for \(addr), but the email didn't send. Share the message below."
            isError = !res.emailSent
            email = ""
        } else {
            isError = true
            message = friendly(res.error)
        }
        busy = false
    }

    private func friendly(_ code: String?) -> String {
        switch code {
        case "Not allowed.": return "Only admins can invite."
        case "not_configured", "network": return "Invites aren't enabled on the server yet."
        case let s?: return s
        default: return "Couldn't send that invite."
        }
    }
}
