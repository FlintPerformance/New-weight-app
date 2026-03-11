import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: MainTabView.Tab
    let onWeighIn: () -> Void

    private let tabs: [(tab: MainTabView.Tab, icon: String, label: String)] = [
        (.home, "house.fill", "Home"),
        (.progress, "chart.xyaxis.line", "Progress"),
        (.friends, "person.3.fill", "Friends"),
        (.profile, "person.crop.circle", "Profile"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            // First two tabs
            ForEach(tabs.prefix(2), id: \.tab) { item in
                tabButton(item.tab, icon: item.icon, label: item.label)
            }

            // FAB in center
            fabButton

            // Last two tabs
            ForEach(tabs.suffix(2), id: \.tab) { item in
                tabButton(item.tab, icon: item.icon, label: item.label)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(.separator),
            alignment: .top
        )
    }

    private func tabButton(_ tab: MainTabView.Tab, icon: String, label: String) -> some View {
        Button {
            guard selectedTab != tab else { return }
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            withAnimation(.snappy(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedTab)
                Text(label)
                    .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .regular))
            }
            .foregroundStyle(selectedTab == tab ? AppColors.accent : .secondary)
            .frame(maxWidth: .infinity)
        }
    }

    private var fabButton: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            onWeighIn()
        } label: {
            ZStack {
                SwiftUI.Circle()
                    .fill(AppColors.accent)
                    .frame(width: 52, height: 52)
                    .shadow(color: AppColors.accent.opacity(0.3), radius: 8, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .offset(y: -16)
        .frame(maxWidth: .infinity)
    }
}
