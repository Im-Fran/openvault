import LocalAuthentication
import SwiftUI
#if os(macOS)
import LocalAuthenticationEmbeddedUI
#endif

struct LockView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(macOS)
    @Environment(\.appearsActive) private var appearsActive
    #else
    @Environment(\.scenePhase) private var scenePhase
    /// Face ID is offered once each time the app comes to the front, so cancelling it doesn't loop.
    @State private var autoPrompted = false
    #endif

    @State private var password = ""
    @State private var confirmation = ""
    @State private var failures = 0
    @State private var showError = false
    @State private var working = false
    @FocusState private var focused: Bool
    @FocusState private var confirmationFocused: Bool
    /// One context per attempt: an evaluated or invalidated LAContext can't be reused.
    @State private var authContext = LAContext()

    private var isSetup: Bool { store.state == .setup }
    private var showsTouchID: Bool { !isSetup && store.biometricsEnrolled }

    var body: some View {
        VStack(spacing: 22) {
            Image(.brandMark)
                .resizable()
                .frame(width: 56, height: 56)
                .foregroundStyle(Brand.gradient)
                .accessibilityHidden(true)
                #if os(macOS)
                .overlay(alignment: .bottomTrailing) {
                    if showsTouchID {
                        // Inline Touch ID badge, like Passwords: no system dialog, just the sensor glyph.
                        EmbeddedTouchID(context: authContext, onAttach: evaluateTouchID)
                            .id(ObjectIdentifier(authContext))
                            .padding(3)
                            .background(.white, in: .circle) // the glyph is drawn for a light backdrop, as in Passwords
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                            .offset(x: 10, y: 8)
                            .help("Unlock with Touch ID")
                            .accessibilityLabel("Unlock with Touch ID")
                    }
                }
                #endif

            VStack(spacing: 6) {
                Text(isSetup ? "Create Your Vault" : "OpenVault Is Locked")
                    .font(.title2.weight(.semibold))
                Text(isSetup
                     ? "Your master password encrypts all your secrets. It can’t be recovered if you forget it."
                     : showsTouchID ? "Use \(Biometrics.name) or enter your master password." : "Enter your master password.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                SecureField("Master Password", text: $password)
                    .focused($focused)
                    .onSubmit { if isSetup && confirmation.isEmpty { confirmationFocused = true } else { submit() } }
                if isSetup {
                    SecureField("Confirm Password", text: $confirmation)
                        .focused($confirmationFocused)
                        .onSubmit(submit)
                    StrengthMeter(password: password)
                }
            }
            .textFieldStyle(.roundedBorder)
            .controlSize(.large)
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(.red, lineWidth: 1.5)
                    .opacity(showError ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .keyframeAnimator(initialValue: 0.0, trigger: failures) { [reduceMotion] content, x in
                content.offset(x: reduceMotion ? 0 : x)
            } keyframes: { _ in
                // Error shake: the one place we allow overshoot — it *is* the feedback.
                KeyframeTrack {
                    LinearKeyframe(-9, duration: 0.06)
                    LinearKeyframe(8, duration: 0.08)
                    LinearKeyframe(-5, duration: 0.08)
                    SpringKeyframe(0, duration: 0.25, spring: .bouncy)
                }
            }

            if showError {
                Text("Incorrect password").font(.callout).foregroundStyle(.red).transition(.opacity)
            }

            if let hint = setupHint {
                Text(hint).font(.caption).foregroundStyle(.secondary).transition(.opacity)
            }

            Button(action: submit) {
                Text(isSetup ? "Create Vault" : "Unlock")
                    .frame(maxWidth: .infinity)
                    .opacity(working ? 0 : 1)
                    .overlay { if working { ProgressView().controlSize(.small) } }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .disabled(!canSubmit || working)

            #if os(iOS)
            if showsTouchID {
                Button("Unlock with \(Biometrics.name)", systemImage: Biometrics.symbol) {
                    Task { await store.unlockWithBiometrics() }
                }
                .controlSize(.large)
            }
            #endif
        }
        .padding(32)
        .frame(maxWidth: 380)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(colors: [Color(.brandStart).opacity(0.22), .clear, Color(.brandEnd).opacity(0.18)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
        .animation(Motion.standard, value: isSetup)
        .sensoryFeedback(.error, trigger: failures)
        #if os(iOS)
        .onAppear { focused = !showsTouchID } // the keyboard would cover the Face ID prompt
        .task(id: scenePhase) {
            if scenePhase == .background { autoPrompted = false }
            guard scenePhase == .active, showsTouchID, !autoPrompted else { return }
            autoPrompted = true
            await store.unlockWithBiometrics()
        }
        #else
        .onAppear { focused = true }
        // Only ask for Touch ID while the window is frontmost; going to the background cancels it.
        // A fresh context swaps in a fresh badge, which starts the evaluation once it's in the window.
        .onChange(of: appearsActive) { appearsActive ? authContext = LAContext() : authContext.invalidate() }
        .onDisappear { authContext.invalidate() }
        #endif
        .onChange(of: password) { withAnimation(Motion.standard) { showError = false } }
    }

    #if os(macOS)
    /// Called by the badge once it's in a window: evaluating earlier leaves it blank.
    private func evaluateTouchID(_ context: LAContext) {
        guard appearsActive, context === authContext else { return }
        Task { await store.unlockWithBiometrics(context: context) }
    }
    #endif

    private var setupHint: String? {
        guard isSetup, !confirmation.isEmpty, confirmation != password else {
            return isSetup && !password.isEmpty && password.count < 8 ? String(localized: "At least 8 characters.") : nil
        }
        return String(localized: "Passwords don’t match.")
    }

    private var canSubmit: Bool {
        isSetup ? password.count >= 8 && password == confirmation : !password.isEmpty
    }

    private func submit() {
        guard canSubmit, !working else { return }
        working = true
        Task {
            defer { working = false }
            if isSetup {
                do { try await store.create(password: password) } catch { store.errorMessage = error.localizedDescription }
            } else if await !store.unlock(password: password) {
                failures += 1 // shake + haptic (sensoryFeedback) on the same frame
                withAnimation(Motion.standard) { showError = true }
                AccessibilityNotification.Announcement(String(localized: "Incorrect password")).post()
                password = ""
                focused = true
            }
        }
    }
}

#if os(macOS)
private struct EmbeddedTouchID: NSViewRepresentable {
    let context: LAContext
    let onAttach: (LAContext) -> Void

    func makeNSView(context: Context) -> AuthView {
        let view = AuthView(context: self.context, controlSize: .small)
        view.onAttach = { [onAttach, authContext = self.context] in onAttach(authContext) }
        return view
    }

    func updateNSView(_ nsView: AuthView, context: Context) {}

    // The view sizes itself from its control size; SwiftUI's proposal would stretch it.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: AuthView, context: Context) -> CGSize? {
        nsView.fittingSize
    }

    final class AuthView: LAAuthenticationView {
        var onAttach: (() -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil, let onAttach else { return }
            self.onAttach = nil // once per context
            onAttach()
        }
    }
}
#endif

private struct StrengthMeter: View {
    let password: String

    private var score: Int {
        guard !password.isEmpty else { return 0 }
        var s = password.count >= 12 ? 2 : password.count >= 8 ? 1 : 0
        let classes: [(Character) -> Bool] = [\.isLowercase, \.isUppercase, \.isNumber, { !$0.isLetter && !$0.isNumber }]
        s += classes.filter { test in password.contains(where: test) }.count >= 3 ? 1 : 0
        s += password.count >= 16 ? 1 : 0
        return min(s, 4)
    }

    private var color: Color { [.red, .red, .orange, .yellow, .green][score] }
    private var label: String { ["", String(localized: "Weak"), String(localized: "Fair"), String(localized: "Good"), String(localized: "Strong")][score] }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<4) { i in
                    Capsule().fill(i < score ? color : Color.secondary.opacity(0.2)).frame(height: 4)
                }
            }
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 64, alignment: .trailing)
        }
        .animation(Motion.standard, value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Strength: \(label.isEmpty ? String(localized: "no password") : label)")
    }
}
