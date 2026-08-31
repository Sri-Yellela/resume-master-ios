import SwiftUI

struct CardStackView: View {
    @ObservedObject private var feed = JobFeedService.shared
    @ObservedObject private var localQueue = LocalApplyQueue.shared

    @Binding var actionRequest: SwipeAction?
    @Binding var badgeAction: SwipeAction?
    /// Set when a job cannot be finished on this device, so the user is told rather than left
    /// with a card that silently vanished behind a "queued" badge that was not true.
    @Binding var desktopOnly: Job?

    var body: some View {
        ZStack {
            ForEach(Array(feed.jobs.prefix(4).enumerated()).reversed(), id: \.element.id) { index, job in
                JobCardView(job: job)
                    .scaleEffect(1 - CGFloat(index) * SwipeThresholds.stackScaleFactor)
                    .offset(y: -CGFloat(index) * SwipeThresholds.stackOffsetFactor)
                    .opacity(pow(0.9, Double(index)))
                    .zIndex(Double(4 - index))
                    .swipeCard(enabled: index == 0) { complete($0, job: job) }
            }
        }
        .animation(.cardPeel, value: feed.jobs)
        .onChange(of: actionRequest) { _, request in
            if let request, let front = feed.jobs.first {
                complete(request, job: front)
                actionRequest = nil
            }
        }
    }

    private func complete(_ action: SwipeAction, job: Job) {
        switch action {
        case .queue, .priorityQueue:
            // Costs nothing. The row goes to the local queue; the resume is generated later, from
            // an explicit tap in the review queue.
            //
            // The feed already asks the server for completable tiers only, so a refusal here
            // means an unclassifiable row slipped through. Say so and put the card back rather
            // than confirming a queue that did not happen.
            guard localQueue.add(job, prioritised: action == .priorityQueue) else {
                desktopOnly = job
                return
            }
        case .star, .dislike, .skip:
            break
        }

        badgeAction = action
        feed.remove(job)

        Task {
            await feed.recordInteraction(job, action: action)
            await feed.loadMoreIfNeeded(remaining: feed.jobs.count)
        }
    }
}
