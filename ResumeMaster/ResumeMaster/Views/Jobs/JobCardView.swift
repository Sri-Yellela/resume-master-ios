import SwiftUI

struct JobCardView: View {
    let job: Job
    @State private var expanded = false

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                top.frame(height: expanded ? proxy.size.height * 0.20 : proxy.size.height * 0.34)
                middle.frame(height: expanded ? proxy.size.height * 0.30 : proxy.size.height * 0.42)
                bottom.frame(maxHeight: .infinity, alignment: .top)
            }
            .padding(22)
            .frame(maxWidth: .infinity,
                   maxHeight: expanded ? proxy.size.height : proxy.size.height * 0.72)
            .background(RoundedRectangle(cornerRadius: DS.Radius.xl).fill(DS.ColorToken.surface))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(DS.ColorToken.border.opacity(0.55), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 12)
            .onTapGesture { withAnimation(.cardPeel) { expanded.toggle() } }
        }
        .padding(.horizontal, DS.Spacing.md)
    }

    private var top: some View {
        HStack(alignment: .top) {
            Circle()
                .fill(DS.ColorToken.surfaceOffset)
                .frame(width: 44, height: 44)
                .overlay(Text(job.company.prefix(1).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DS.ColorToken.textMuted))
            Spacer()
            if let match = job.matchPercent {
                Text("\(match)% match")
                    .font(DS.FontToken.caption)
                    .foregroundStyle(DS.ColorToken.primary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Capsule().fill(DS.ColorToken.primary.opacity(0.12)))
            }
        }
    }

    private var middle: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(job.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(DS.ColorToken.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(job.company)
                .font(DS.FontToken.body)
                .foregroundStyle(DS.ColorToken.textMuted)
            Text([job.location, job.salaryText].compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: "  •  "))
                .font(DS.FontToken.caption)
                .foregroundStyle(DS.ColorToken.textFaint)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(job.chips, id: \.self) { chip in
                        Text(chip)
                            .font(DS.FontToken.caption)
                            .foregroundStyle(DS.ColorToken.textMuted)
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: DS.Radius.sm)
                                .fill(DS.ColorToken.surfaceOffset))
                    }
                }
            }
        }
    }

    private var bottom: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().overlay(DS.ColorToken.border)

            Text(job.summary ?? job.description ?? "No description provided.")
                .font(DS.FontToken.body)
                .foregroundStyle(DS.ColorToken.text)
                .lineLimit(expanded ? nil : 2)

            if expanded {
                eligibilityNotes
            }

            Text(expanded ? "Tap to collapse" : "Tap to expand")
                .font(DS.FontToken.caption)
                .foregroundStyle(DS.ColorToken.textFaint)
        }
    }

    /// Eligibility signals are shown ONLY when the posting actually carries them.
    ///
    /// All three are tri-state and a null means "no signal yet". Rendering a null as "does not
    /// sponsor" would invent a fact about an employer, so an absent signal produces no row at all.
    /// These are read-only here by design: work authorisation and sponsorship are attestations
    /// made from the stored profile, never something a swipe can answer.
    @ViewBuilder private var eligibilityNotes: some View {
        let notes: [String] = [
            job.isH1bSponsor == true ? "Employer states it sponsors H-1B" : nil,
            job.requiresWorkAuth == true ? "Requires existing work authorisation" : nil,
            job.isClearanceRequired == true ? "Requires a security clearance" : nil,
        ].compactMap { $0 }

        if !notes.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(notes, id: \.self) { note in
                    Label(note, systemImage: "info.circle")
                        .font(DS.FontToken.caption)
                        .foregroundStyle(DS.ColorToken.textMuted)
                }
            }
        }
    }
}
