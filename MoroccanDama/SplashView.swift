import SwiftUI

/// The front door: a drawn café scene — two men in djellaba over a dama
/// board, mint tea at hand — shown for a breath at launch, then fading
/// into the game.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color(red: 0.85, green: 0.62, blue: 0.47).ignoresSafeArea()

            Image("SplashArt")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            VStack {
                Spacer()
                VStack(spacing: 4) {
                    Text("Dama")
                        .font(.system(size: 54, weight: .heavy, design: .serif))
                        .foregroundStyle(Color(red: 0.23, green: 0.13, blue: 0.08))
                    Text("ضامة")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color(red: 0.36, green: 0.22, blue: 0.12))
                    Text("The café game of Morocco")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(red: 0.42, green: 0.28, blue: 0.17))
                        .padding(.top, 2)
                }
                .padding(.bottom, 64)
            }
        }
    }
}

/// Shows the splash INSTEAD of the game for a moment at launch — not
/// stacked over it: as the window's root view the splash gets the same
/// full-bleed layout the game's own background uses, while a stacked
/// overlay was laid out inside an inset frame and left a strip of the
/// game showing at the top. `-splashHold` keeps the splash up
/// indefinitely for visual QA (screenshots workflow).
struct RootView: View {
    @State private var showSplash = true

    var body: some View {
        Group {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else {
                ContentView()
                    .transition(.opacity)
            }
        }
        .onAppear {
            guard !ProcessInfo.processInfo.arguments.contains("-splashHold") else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showSplash = false
                }
            }
        }
    }
}
