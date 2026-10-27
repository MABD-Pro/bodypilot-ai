import SwiftUI

/// Prolonge l'écran de lancement (même fond, même logo) par une courte animation,
/// le temps que la base locale et le plan du jour soient prêts.
struct SplashView: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()
            RadialGradient(
                colors: [Theme.nutrition.opacity(appeared ? 0.35 : 0), .clear],
                center: .center,
                startRadius: 10,
                endRadius: appeared ? 340 : 120
            )
            .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.l) {
                Image("LaunchLogo")
                    .shadow(color: Theme.nutrition.opacity(appeared ? 0.6 : 0), radius: 30)
                    .scaleEffect(appeared ? 1.06 : 1)
                VStack(spacing: Theme.Spacing.xs) {
                    Text("BodyPilot")
                        .font(.display(30))
                    Text("Ton coach, chaque jour")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .foregroundStyle(.white)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
            }
            // Le logo du lancement est centré : on le garde au centre pendant la transition.
            .offset(y: 38)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { appeared = true }
        }
    }
}

#Preview {
    SplashView()
}
