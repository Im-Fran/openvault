import AppKit
import SwiftUI

struct LockView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var password = ""
    @State private var confirmation = ""
    @State private var failures = 0
    @State private var showError = false
    @State private var working = false
    @FocusState private var focused: Bool

    private var isSetup: Bool { store.state == .setup }

    var body: some View {
        VStack(spacing: 22) {
            Image(.brandMark)
                .resizable()
                .frame(width: 56, height: 56)
                .foregroundStyle(Brand.gradient)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(isSetup ? "Crea tu vault" : "OpenVault está bloqueado")
                    .font(.title2.weight(.semibold))
                Text(isSetup
                     ? "La contraseña maestra cifra todos tus secretos. No se puede recuperar si la olvidas."
                     : "Ingresa tu contraseña maestra.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                SecureField("Contraseña maestra", text: $password)
                    .focused($focused)
                    .onSubmit(submit)
                if isSetup {
                    SecureField("Confirmar contraseña", text: $confirmation)
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
                Text("Contraseña incorrecta").font(.callout).foregroundStyle(.red).transition(.opacity)
            }

            if let hint = setupHint {
                Text(hint).font(.caption).foregroundStyle(.secondary).transition(.opacity)
            }

            HStack(spacing: 10) {
                if !isSetup, store.biometricsEnrolled {
                    Button {
                        Task { await store.unlockWithBiometrics() }
                    } label: {
                        Image(systemName: "touchid")
                    }
                    .controlSize(.large)
                    .help("Desbloquear con Touch ID")
                    .accessibilityLabel("Desbloquear con Touch ID")
                }
                Button(action: submit) {
                    Text(isSetup ? "Crear vault" : "Desbloquear")
                        .frame(maxWidth: .infinity)
                        .opacity(working ? 0 : 1)
                        .overlay { if working { ProgressView().controlSize(.small) } }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(!canSubmit || working)
            }
        }
        .padding(32)
        .frame(width: 380)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(colors: [Color(.brandStart).opacity(0.22), .clear, Color(.brandEnd).opacity(0.18)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
        .animation(Motion.standard, value: isSetup)
        .onAppear {
            focused = true
            if !isSetup, store.biometricsEnrolled { Task { await store.unlockWithBiometrics() } }
        }
        .onChange(of: password) { withAnimation(Motion.standard) { showError = false } }
    }

    private var setupHint: String? {
        guard isSetup, !confirmation.isEmpty, confirmation != password else {
            return isSetup && !password.isEmpty && password.count < 8 ? "Mínimo 8 caracteres." : nil
        }
        return "Las contraseñas no coinciden."
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
                // Visual + haptic on the same frame (harmony).
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
                failures += 1
                withAnimation(Motion.standard) { showError = true }
                AccessibilityNotification.Announcement("Contraseña incorrecta").post()
                password = ""
                focused = true
            }
        }
    }
}

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
    private var label: String { ["", "Débil", "Aceptable", "Buena", "Fuerte"][score] }

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
        .accessibilityLabel("Fortaleza: \(label.isEmpty ? "sin contraseña" : label)")
    }
}
