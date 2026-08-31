import SwiftUI

struct JobsView: View {
    @ObservedObject private var feed = JobFeedService.shared
    @ObservedObject private var localQueue = LocalApplyQueue.shared
    @ObservedObject private var apply = ApplyService.shared

    @State private var requestedAction: SwipeAction?
    @State private var badgeAction: SwipeAction?
    @State private var desktopOnly: Job?

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                queueBanner

                Group {
                    if feed.isEmpty && feed.isLoading {
                        ProgressView("Loading jobs…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let message = feed.errorMessage, feed.isEmpty {
                        errorState(message)
                    } else if feed.isEmpty {
                        emptyState
                    } else {
                        CardStackView(actionRequest: $requestedAction,
                                      badgeAction: $badgeAction,
                                      desktopOnly: $desktopOnly)
                    }
                }
                .frame(maxHeight: .infinity)

                ActionBadgeView(action: badgeAction) { badgeAction = nil }
                    .frame(height: 34)

                HStack(spacing: 28) {
                    actionButton("xmark", .dislike, DS.ColorToken.textMuted)
                    actionButton("star.fill", .star, DS.ColorToken.gold)
                    actionButton("tray.and.arrow.down", .queue, DS.ColorToken.primary)
                }
                .padding(.bottom, 10)
                .disabled(feed.isEmpty)
                .opacity(feed.isEmpty ? 0.4 : 1)
            }
            .background(DS.ColorToken.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Jobs").font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.shared.softTap()
                        Task { await feed.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                if feed.isEmpty { await feed.refresh() }
                await apply.loadReadiness()
            }
            .alert("Finish this one on desktop",
                   isPresented: Binding(get: { desktopOnly != nil },
                                        set: { if !$0 { desktopOnly = nil } }),
                   presenting: desktopOnly) { _ in
                Button("OK") { desktopOnly = nil }
            } message: { job in
                Text(job.automationTier.desktopOnlyReason
                     ?? "This employer's application cannot be completed on a phone.")
            }
        }
    }

    /// The queue is the product's promise, so its size is always on screen. A user who swipes 40
    /// and reviews 0 has spent nothing yet — but they have also applied to nothing, and a count
    /// they never see is a count they never act on.
    @ViewBuilder private var queueBanner: some View {
        if localQueue.count > 0 {
            HStack(spacing: 8) {
                Image(systemName: "tray.full")
                Text("\(localQueue.count) waiting for review")
                    .font(DS.FontToken.label)
                Spacer()
                Text("Review")
                    .font(DS.FontToken.caption.weight(.semibold))
                    .foregroundStyle(DS.ColorToken.primary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(DS.ColorToken.primary.opacity(0.10)))
            .padding(.horizontal, DS.Spacing.md)
        }

        if let readiness = apply.readiness, !readiness.available {
            // A 503 from readiness is a state, not an error: say what it is and let the user keep
            // swiping, because queueing locally still costs nothing and still works.
            Text(readiness.reason ?? "Auto-apply is paused right now.")
                .font(DS.FontToken.caption)
                .foregroundStyle(DS.ColorToken.warning)
                .padding(.horizontal, DS.Spacing.md)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "briefcase")
                .font(.system(size: 34))
                .foregroundStyle(DS.ColorToken.textFaint)
            Text("No more jobs right now")
                .font(DS.FontToken.body)
                .foregroundStyle(DS.ColorToken.textMuted)
            // Being explicit about the filter, because a feed that silently hides most of the
            // board looks like an empty board.
            Text("Only jobs that can be completed on a phone are shown here. Workday, Meta and "
                 + "other portal applications need a desktop browser.")
                .font(DS.FontToken.caption)
                .foregroundStyle(DS.ColorToken.textFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Refresh") { Task { await feed.refresh() } }
                .buttonStyle(.bordered)
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 30))
                .foregroundStyle(DS.ColorToken.warning)
            Text(message)
                .font(DS.FontToken.body)
                .foregroundStyle(DS.ColorToken.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Try again") { Task { await feed.refresh() } }
                .buttonStyle(.bordered)
        }
    }

    private func actionButton(_ image: String, _ action: SwipeAction, _ color: Color) -> some View {
        Button {
            switch action {
            case .star: HapticManager.shared.star()
            case .dislike, .skip: HapticManager.shared.dismiss()
            default: HapticManager.shared.trigger()
            }
            requestedAction = action
        } label: {
            Image(systemName: image).font(.system(size: 18, weight: .semibold))
        }
        .buttonStyle(MinimalButton(foreground: color))
    }
}
