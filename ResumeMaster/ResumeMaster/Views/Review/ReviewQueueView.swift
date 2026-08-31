import SwiftUI

/// The review queue: the product's promise, and the only place an application can be sent.
///
/// It has two sections because the queue genuinely has two halves, and collapsing them would hide
/// where the money goes:
///
///  * **Waiting** — swiped, stored on this device, costs nothing. Preparing them is an explicit,
///    counted tap.
///  * **Ready to send** — the server has generated a resume and previewed the form. These show the
///    resolved answers with their provenance, and only these can be approved.
struct ReviewQueueView: View {
    @ObservedObject private var localQueue = LocalApplyQueue.shared
    @ObservedObject private var apply = ApplyService.shared

    @State private var selectedForPrepare = Set<String>()
    @State private var confirmingPrepare = false

    var body: some View {
        NavigationStack {
            List {
                if let notice = apply.notice { noticeRow(notice, tone: DS.ColorToken.success) }
                if let error = apply.errorMessage { noticeRow(error, tone: DS.ColorToken.warning) }

                readyToSendSection
                waitingSection

                if localQueue.entries.isEmpty && apply.pending.isEmpty { emptyState }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await apply.loadPending()
                await apply.loadReadiness()
            }
            .task {
                await apply.loadPending()
                await apply.loadReadiness()
            }
            .safeAreaInset(edge: .bottom) { prepareBar }
            .confirmationDialog(
                "Prepare \(selectedForPrepare.count) application\(selectedForPrepare.count == 1 ? "" : "s")?",
                isPresented: $confirmingPrepare,
                titleVisibility: .visible
            ) {
                Button("Prepare \(selectedForPrepare.count)") {
                    let ids = Array(selectedForPrepare)
                    Task {
                        let accepted = await apply.prepare(jobIds: ids)
                        // Only clear what the server actually accepted. Anything refused stays in
                        // the local queue, which is where the user can see it and try again.
                        localQueue.remove(accepted)
                        selectedForPrepare.subtract(accepted)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This generates a tailored resume for each one. Nothing is sent to an "
                     + "employer — you will review and approve each application after.")
            }
        }
    }

    // MARK: - Ready to send

    @ViewBuilder private var readyToSendSection: some View {
        if !apply.pending.isEmpty {
            Section {
                ForEach(apply.pending) { item in
                    NavigationLink {
                        ReviewDetailView(item: item)
                    } label: {
                        pendingRow(item)
                    }
                }
            } header: {
                Text("Ready to send — \(apply.pending.count)")
            } footer: {
                Text("Reviewed and approved by you, one at a time. Nothing here has been sent.")
            }
        }
    }

    private func pendingRow(_ item: PendingItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.displayTitle).font(DS.FontToken.body)
            Text(item.displayCompany)
                .font(DS.FontToken.caption)
                .foregroundStyle(DS.ColorToken.textMuted)

            HStack(spacing: 10) {
                if let score = item.resume?.atsScore {
                    Label("ATS \(Int(score))", systemImage: "doc.text")
                        .font(DS.FontToken.caption)
                        .foregroundStyle(DS.ColorToken.textMuted)
                }
                // Surfaced at list level so a reviewer can see which applications need attention
                // without opening every one.
                if item.needsAttention {
                    Label("\(item.guessCount ?? 0) guessed", systemImage: "questionmark.circle")
                        .font(DS.FontToken.caption)
                        .foregroundStyle(DS.ColorToken.warning)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Waiting

    @ViewBuilder private var waitingSection: some View {
        if !localQueue.entries.isEmpty {
            Section {
                ForEach(localQueue.entries) { entry in
                    Button {
                        toggle(entry.jobId)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: selectedForPrepare.contains(entry.jobId)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedForPrepare.contains(entry.jobId)
                                                 ? DS.ColorToken.primary : DS.ColorToken.textFaint)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title)
                                    .font(DS.FontToken.body)
                                    .foregroundStyle(DS.ColorToken.text)
                                Text(entry.company)
                                    .font(DS.FontToken.caption)
                                    .foregroundStyle(DS.ColorToken.textMuted)
                            }
                            Spacer()
                            if entry.prioritised {
                                Image(systemName: "arrow.up.to.line")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DS.ColorToken.primary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    localQueue.remove(offsets.map { localQueue.entries[$0].jobId })
                }
            } header: {
                HStack {
                    Text("Waiting — \(localQueue.entries.count)")
                    Spacer()
                    Button(selectedForPrepare.count == localQueue.entries.count
                           ? "Deselect all" : "Select all") {
                        selectedForPrepare = selectedForPrepare.count == localQueue.entries.count
                            ? []
                            : Set(localQueue.entries.map(\.jobId))
                    }
                    .font(DS.FontToken.caption)
                    .textCase(nil)
                }
            } footer: {
                capFooter
            }
        }
    }

    /// The cap, stated before the user hits it. The server refuses at 40 queued per 24 hours
    /// because each one generates a resume; discovering that by being refused is a worse
    /// experience than being told, and "failed silently at the cap" is the outcome to avoid.
    @ViewBuilder private var capFooter: some View {
        if let cap = apply.queueCap, let limit = cap.limit, let remaining = cap.remaining {
            Text("Each one generates a tailored resume. \(remaining) of \(limit) left in your "
                 + "24-hour limit.")
                .foregroundStyle(remaining == 0 ? DS.ColorToken.warning : DS.ColorToken.textMuted)
        } else {
            Text("Swiped on this device. Preparing generates a tailored resume for each — "
                 + "up to 40 per 24 hours.")
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder private var prepareBar: some View {
        if !selectedForPrepare.isEmpty {
            VStack(spacing: 6) {
                Button {
                    confirmingPrepare = true
                } label: {
                    HStack {
                        if apply.isWorking { ProgressView().tint(.white) }
                        Text("Prepare \(selectedForPrepare.count) for review")
                            .font(DS.FontToken.body.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(DS.ColorToken.primary))
                    .foregroundStyle(.white)
                }
                .disabled(apply.isWorking)

                Text("This does not send anything.")
                    .font(DS.FontToken.caption)
                    .foregroundStyle(DS.ColorToken.textMuted)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }

    // MARK: -

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 30))
                .foregroundStyle(DS.ColorToken.textFaint)
            Text("Nothing waiting")
                .font(DS.FontToken.body)
                .foregroundStyle(DS.ColorToken.textMuted)
            Text("Jobs you swipe right on land here. Nothing is generated or sent until you say so.")
                .font(DS.FontToken.caption)
                .foregroundStyle(DS.ColorToken.textFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .listRowBackground(Color.clear)
    }

    private func noticeRow(_ text: String, tone: Color) -> some View {
        Text(text)
            .font(DS.FontToken.caption)
            .foregroundStyle(tone)
            .listRowBackground(tone.opacity(0.08))
    }

    private func toggle(_ jobId: String) {
        if selectedForPrepare.contains(jobId) { selectedForPrepare.remove(jobId) }
        else { selectedForPrepare.insert(jobId) }
    }
}
