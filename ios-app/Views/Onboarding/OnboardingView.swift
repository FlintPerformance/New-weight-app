import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var currentPage = 0

    private let pages: [(icon: String, title: String, body: String, hint: String?)] = [
        ("scalemass.fill", "Welcome to subtle", "A smarter way to track your weight. Log daily, see your trend, and stay on track — all in one place.", nil),
        ("plus.circle.fill", "Log with one tap", "Hit the + button anytime to log your weight. Toggle morning weigh-in for the most accurate trend line.", "Pro tip: Same time each morning = best results!"),
        ("house.fill", "Home is your dashboard", "See your current weight, 7-day trend chart, streak, consistency score, and goal progress at a glance.", nil),
        ("chart.xyaxis.line", "Track your progress", "Dive deeper with charts, milestones, body composition, and weekly check-ins on the Progress tab.", "Focus on the trend, not daily fluctuations!"),
        ("person.3.fill", "Squad up", "Start or join a squad to share weigh-ins with friends. React with emoji, drop comments, and compare trends.", nil),
        ("heart.text.square.fill", "Health in one place", "Connect Apple Health to see steps, heart rate, sleep, calories, BMI, and body fat alongside your weight journey.", nil),
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
