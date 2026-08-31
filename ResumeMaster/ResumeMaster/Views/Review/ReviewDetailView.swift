import SwiftUI

/// One application, before it is sent — and the only screen in the app that can send one.
///
/// The point of this screen is the provenance column. Every field the automation filled is shown
/// with the rule that produced it: a `label_fuzzy` answer is a guess, `handler_exact` /
/// `field_map_exact` / `custom_answer` are not. Flattening that distinction away turns a review
/// into a rubber stamp, so guesses are listed first and marked.
struct ReviewDetailView: View {
    let item: PendingItem

    @ObservedObject private var apply = ApplyService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var detail: RunJobReviewResponse?
    @State private var loadError: String?
    @State private var confirmingSubmit = false

    var body: some View {
        List {
            headerSection

            if let detail {
                if !detail.missingRequired.isEmpty { missingSection(detail) }
                if !detail.guesses.isEmpty { answersSection(detail.guesses, title: "Needs your eye", isGuess: true) }
                if !detail.confirmed.isEmpty { answersSection(detail.confirmed, title: "Filled from your profile", isGuess: false) }
                eligibilityNote
            } else if loadError == nil {
                HStack { ProgressView(); Text("Loading the filled form…") }
            }

            if let loadError {
                Text(loadError)
                    .font(DS.FontToken.caption)
                    .foregroundStyle(DS.ColorToken.warning)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Before sending")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { decisionBar }
        .task { await load() }
        .confirmationDialog(
            "Send this application to \(item.displayCompany)?",
            isPresented: $confirmingSubmit,
            titleVisibility: .visible
        ) {
            Button("Send application", role: .destructive) {
                Task {
                    await apply.approve(runJobIds: [item.runJobId])
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            // The last honest warning, because this genuinely cannot be undone.
            Text("This submits to the employer under your name. It cannot be recalled.")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayTitle).font(.system(size: 18, weight: .semibold))
                Text(item.displayCompany)
                    .font(DS.FontToken.body)
                    .foregroundStyle(DS.ColorToken.textMuted)
                if item.title == nil {
                    // The posting expired after the application was created. The row still names
                    // a jobId, so this is a warning rather than a mystery.
                    Label("This posting is no longer listed", systemImage: "clock.badge.exclamationmark")
                        .font(DS.FontToken.caption)
                        .foregroundStyle(DS.ColorToken.warning)
                }
                if let score = detail?.resume?.atsScore ?? item.resume?.atsScore {
                    Label("Tailored resume attached — ATS score \(Int(score))", systemImage: "doc.text")
                        .font(DS.FontToken.caption)
                        .foregroundStyle(DS.ColorToken.textMuted)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func missingSection(_ detail: RunJobReviewResponse) -> some View {
        Section {
            ForEach(detail.missingRequired, id: \.self) { label in
                Label(label, systemImage: "exclamationmark.circle")
                    .font(DS.FontToken.body)
                    .foregroundStyle(DS.ColorToken.warning)
            }
        } header: {
            Text("Required fields left empty")
        } footer: {
            Text("These are named rather than counted, because a hold you cannot act on is not a "
                 + "review. Finish these on desktop, or discard this application.")
        }
    }

    private func answersSection(_ answers: [ResolvedAnswer], title: String, isGuess: Bool) -> some View {
        Section {
            ForEach(answers) { answer in
                VStack(alignment: .leading, spacing: 4) {
                    Text(answer.field ?? "Unnamed field")
                        .font(DS.FontToken.label)
                        .foregroundStyle(DS.ColorToken.textMuted)
                    Text(answer.skipped == true ? "— left blank —" : (answer.value ?? "—"))
                        .font(DS.FontToken.body)
                        .foregroundStyle(DS.ColorToken.text)
                    HStack(spacing: 6) {
                        Image(systemName: isGuess ? "questionmark.circle.fill" : "checkmark.seal")
                            .font(.system(size: 10))
                        Text(answer.provenanceLabel)
                        if let confidence = answer.confidence {
                            Text("· \(Int(confidence * 100))%")
                        }
                    }
                    .font(DS.FontToken.caption)
                    .foregroundStyle(isGuess ? DS.ColorToken.warning : DS.ColorToken.textFaint)
                }
                .padding(.vertical, 3)
            }
        } header: {
            Text("\(title) — \(answers.count)")
        } footer: {
            if isGuess {
                Text("These came from a fuzzy label match, not an exact one. Read them before "
                     + "sending.")
            }
        }
    }

    /// Eligibility answers are never gestured and never inferred here. They come from the stored
    /// profile, which is where an attestation belongs — this screen shows what will be sent, and
    /// the place to change it is the profile, not a swipe.
    private var eligibilityNote: some View {
        Section {
            Label("Work authorisation, sponsorship and years of experience come from your saved "
                  + "profile. Edit them there.", systemImage: "lock.shield")
                .font(DS.FontToken.caption)
                .foregroundStyle(DS.ColorToken.textMuted)
        }
    }

    // MARK: - Decision

    private var decisionBar: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await apply.reject(runJobIds: [item.runJobId])
                    dismiss()
                }
            } label: {
                Text("Discard")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(DS.ColorToken.border, lineWidth: 1))
            }
            .foregroundStyle(DS.ColorToken.textMuted)

            Button {
                confirmingSubmit = true
            } label: {
                HStack {
                    if apply.isWorking { ProgressView().tint(.white) }
                    Text("Send").font(DS.FontToken.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(DS.ColorToken.success))
                .foregroundStyle(.white)
            }
            .disabled(apply.isWorking)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private func load() async {
        do {
            detail = try await apply.review(runJobId: item.runJobId)
        } catch let error as APIError {
            loadError = error.userMessage
        } catch {
            loadError = "Could not load this application."
        }
    }
}
