import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, body: String, hint: String?)] = [
        ("iphone.badge.plus", "Make It Yours", "Add this app to your home screen for the best experience. It works just like a native app!", "Pro tip: Tap Share → Add to Home Screen"),
        ("scalemass.fill", "Step On, Log In", "Tap the + button to enter your weight. Toggle morning weight for the most accurate trend tracking.", "Pro tip: Same time each morning = best results!"),
        ("chart.xyaxis.line", "Watch Your Progress", "Your dashboard shows your 7-day trend. Switch to candlestick mode for detailed daily ranges.", "Remember: focus on the trend, not daily ups and downs!"),
        ("target", "Dream Big", "Set a target weight and date. We'll track your pace, celebrate milestones, and keep you on track.", nil),
        ("person.3.fill", "Better Together", "Start or join a squad. Share wins, react to entries, and cheer each other on!", nil),
    ]

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("Skip") { onComplete() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()
                }

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 24) {
                            Spacer()

                            // Icon
                            Image(systemName: page.icon)
                                .font(.system(size: 56))
                                .foregroundStyle(AppColors.accent)
                                .padding(24)
                                .background(AppColors.accent.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 24))

                            // Title
                            Text(page.title)
                                .font(.title)
                                .fontWeight(.bold)

                            // Body
                            Text(page.body)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            // Hint
                            if let hint = page.hint {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(AppColors.warning)
                                        .font(.caption)
                                    Text(hint)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(AppColors.warning.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation { currentPage -= 1 }
                        }
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if currentPage < pages.count - 1 {
                        Button {
                            withAnimation { currentPage += 1 }
                        } label: {
                            Text("Next")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(AppColors.accent)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    } else {
                        Button {
                            onComplete()
                        } label: {
                            Text("Let's Go!")
                                .fontWeight(.bold)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(AppColors.accent)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}
