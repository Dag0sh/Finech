import SwiftUI
import LocalAuthentication

enum PINMode {
    case setup
    case unlock
}

struct PINView: View {
    let mode: PINMode
    let onSuccess: () -> Void

    @State private var entered = ""
    @State private var firstEntry = ""
    @State private var shake = false
    @State private var showConfirm = false
    @State private var errorMessage: String?

    private let pinLength = 4

    // MARK: - Biometric

    private var biometricType: LABiometryType {
        let ctx = LAContext()
        ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType
    }

    private var biometricAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    private var biometricEnabled: Bool {
        KeychainService.load(forKey: KeychainService.Key.biometricEnabled) == "true"
    }

    private var biometricIcon: String {
        biometricType == .faceID ? "faceid" : "touchid"
    }

    // MARK: - Titles

    private var title: String {
        switch mode {
        case .setup:   return showConfirm ? "Подтвердите PIN" : "Создайте PIN"
        case .unlock:  return "Введите PIN"
        }
    }

    private var subtitle: String {
        switch mode {
        case .setup:   return showConfirm ? "Введите PIN ещё раз" : "Придумайте 4-значный PIN"
        case .unlock:  return "Добро пожаловать в Finech"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.20),
                    Color(red: 0.05, green: 0.18, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "rublesign.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.white)
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }

                HStack(spacing: 20) {
                    ForEach(0..<pinLength, id: \.self) { i in
                        Circle()
                            .fill(i < entered.count ? Color.white : Color.white.opacity(0.25))
                            .frame(width: 16, height: 16)
                    }
                }
                .modifier(ShakeModifier(trigger: shake))

                if let msg = errorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.9))
                }

                Spacer()

                numpad
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            // При разблокировке с включённой биометрией — запрашиваем сразу
            if mode == .unlock && biometricEnabled {
                triggerBiometric()
            }
        }
    }

    // MARK: - Numpad

    private var numpad: some View {
        VStack(spacing: 16) {
            ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { digit in
                        NumpadButton(label: "\(digit)") { append(String(digit)) }
                    }
                }
            }
            HStack(spacing: 24) {
                // Биометрия — только на экране разблокировки
                if mode == .unlock && biometricEnabled && biometricAvailable {
                    NumpadButton(icon: biometricIcon) { triggerBiometric() }
                } else {
                    Color.clear.frame(width: 72, height: 72)
                }
                NumpadButton(label: "0") { append("0") }
                NumpadButton(label: "⌫", isDelete: true) { deleteLast() }
            }
        }
    }

    // MARK: - Logic

    private func append(_ digit: String) {
        guard entered.count < pinLength else { return }
        entered += digit
        errorMessage = nil
        if entered.count == pinLength { handleComplete() }
    }

    private func deleteLast() {
        guard !entered.isEmpty else { return }
        entered.removeLast()
        errorMessage = nil
    }

    private func handleComplete() {
        switch mode {
        case .setup:
            if !showConfirm {
                firstEntry = entered
                entered = ""
                showConfirm = true
            } else {
                if entered == firstEntry {
                    KeychainService.save(entered, forKey: KeychainService.Key.userPin)
                    onSuccess()
                } else {
                    triggerError("PIN не совпадает. Попробуйте снова")
                    showConfirm = false
                    firstEntry = ""
                }
            }
        case .unlock:
            let saved = KeychainService.load(forKey: KeychainService.Key.userPin)
            if entered == saved {
                onSuccess()
            } else {
                triggerError("Неверный PIN")
            }
        }
    }

    private func triggerBiometric() {
        let ctx = LAContext()
        let reason = "Войдите в Finech"
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
                if success { onSuccess() }
                // При ошибке или отмене — ничего не делаем, пользователь вводит PIN
            }
        }
    }

    private func triggerError(_ message: String) {
        errorMessage = message
        withAnimation(.default) { shake = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shake = false
            entered = ""
        }
    }
}

// MARK: - BiometricSetupView

struct BiometricSetupView: View {
    let onComplete: () -> Void

    @State private var biometricType: LABiometryType = .none

    private var icon: String {
        biometricType == .faceID ? "faceid" : "touchid"
    }

    private var typeName: String {
        biometricType == .faceID ? "Face ID" : "Touch ID"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.07, green: 0.07, blue: 0.20),
                    Color(red: 0.05, green: 0.18, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 36) {
                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 72))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse)

                VStack(spacing: 10) {
                    Text("Использовать \(typeName)?")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Входите в Finech быстро и безопасно\nбез ввода PIN")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button {
                        enableBiometric()
                    } label: {
                        Label("Включить \(typeName)", systemImage: icon)
                            .font(.headline)
                            .foregroundStyle(Color(red: 0.07, green: 0.07, blue: 0.20))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16))
                    }

                    Button("Пропустить") {
                        onComplete()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            let ctx = LAContext()
            ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            biometricType = ctx.biometryType
        }
    }

    private func enableBiometric() {
        let ctx = LAContext()
        ctx.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Подтвердите включение \(typeName)"
        ) { success, _ in
            DispatchQueue.main.async {
                if success {
                    KeychainService.save("true", forKey: KeychainService.Key.biometricEnabled)
                }
                onComplete()
            }
        }
    }
}

// MARK: - NumpadButton

private struct NumpadButton: View {
    var label: String?
    var icon: String?
    var isDelete = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Group {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .light))
                } else {
                    Text(label ?? "")
                        .font(.system(size: isDelete ? 22 : 28, weight: .medium, design: .rounded))
                }
            }
            .foregroundStyle(.white)
            .frame(width: 72, height: 72)
            .background(.white.opacity(pressed ? 0.35 : 0.15), in: Circle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressed = true }
                .onEnded { _ in pressed = false }
        )
    }
}

// MARK: - ShakeModifier

private struct ShakeModifier: ViewModifier {
    let trigger: Bool
    func body(content: Content) -> some View {
        content
            .offset(x: trigger ? -8 : 0)
            .animation(
                trigger
                    ? .spring(response: 0.1, dampingFraction: 0.2).repeatCount(4, autoreverses: true)
                    : .default,
                value: trigger
            )
    }
}
