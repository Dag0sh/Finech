import SwiftUI

enum PINMode {
    case setup      // первый запуск — задать PIN
    case confirm    // подтвердить PIN при setup
    case unlock     // ввести PIN для входа
}

struct PINView: View {
    let mode: PINMode
    let onSuccess: () -> Void

    @State private var entered = ""
    @State private var firstEntry = ""   // при setup — хранит первый ввод
    @State private var shake = false
    @State private var showConfirm = false
    @State private var errorMessage: String?

    private let pinLength = 4

    private var title: String {
        switch mode {
        case .setup:    return showConfirm ? "Подтвердите PIN" : "Создайте PIN"
        case .confirm:  return "Подтвердите PIN"
        case .unlock:   return "Введите PIN"
        }
    }

    private var subtitle: String {
        switch mode {
        case .setup:    return showConfirm ? "Введите PIN ещё раз" : "Придумайте 4-значный PIN"
        case .confirm:  return "Введите PIN ещё раз"
        case .unlock:   return "Добро пожаловать в Finech"
        }
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

            VStack(spacing: 40) {
                Spacer()

                // Header
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

                // Dots
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

                // Numpad
                numpad
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
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
                Color.clear.frame(width: 72, height: 72)
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
                // Первый ввод — переходим к подтверждению
                firstEntry = entered
                entered = ""
                showConfirm = true
            } else {
                // Подтверждение
                if entered == firstEntry {
                    KeychainService.save(entered, forKey: KeychainService.Key.userPin)
                    onSuccess()
                } else {
                    triggerError("PIN не совпадает. Попробуйте снова")
                    showConfirm = false
                    firstEntry = ""
                }
            }
        case .confirm:
            if entered == firstEntry {
                KeychainService.save(entered, forKey: KeychainService.Key.userPin)
                onSuccess()
            } else {
                triggerError("PIN не совпадает")
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

    private func triggerError(_ message: String) {
        errorMessage = message
        withAnimation(.default) { shake = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            shake = false
            entered = ""
        }
    }
}

// MARK: - NumpadButton

private struct NumpadButton: View {
    let label: String
    var isDelete = false
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: isDelete ? 22 : 28, weight: .medium, design: .rounded))
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

// MARK: - Shake animation

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
