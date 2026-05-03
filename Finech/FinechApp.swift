import SwiftUI

@main
struct FinechApp: App {
    @State private var transactionVM = TransactionViewModel()
    @State private var exchangeRateVM = ExchangeRateViewModel()

    // Три шага запуска: splash → pin → main
    @State private var appPhase: AppPhase = .splash

    private enum AppPhase { case splash, pin, main }

    private var pinMode: PINMode {
        KeychainService.load(forKey: KeychainService.Key.userPin) == nil ? .setup : .unlock
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch appPhase {
                case .splash:
                    SplashView()
                        .transition(.opacity)
                case .pin:
                    PINView(mode: pinMode) {
                        withAnimation(.easeInOut(duration: 0.4)) { appPhase = .main }
                    }
                    .transition(.opacity)
                case .main:
                    MainTabView()
                        .environment(transactionVM)
                        .environment(exchangeRateVM)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: appPhase)
            .task {
                exchangeRateVM.load()
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation { appPhase = .pin }
            }
        }
    }
}

struct SplashView: View {
    @State private var scale = 0.75
    @State private var opacity = 0.0

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

            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 110, height: 110)
                    Circle()
                        .fill(.white.opacity(0.07))
                        .frame(width: 130, height: 130)
                    Image(systemName: "rublesign.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                        .symbolEffect(.pulse)
                }

                VStack(spacing: 6) {
                    Text("Finech")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Личные финансы")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    scale = 1
                    opacity = 1
                }
            }
        }
    }
}
