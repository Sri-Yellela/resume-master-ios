import SwiftUI

struct ResumeBuilderView: View {
    @EnvironmentObject private var appState: AppState
    @State private var editingSectionID: UUID?
    @StateObject private var linkedInAuth = LinkedInAuthService.shared
    @State private var importNotice: String?

    private var isEditing: Binding<Bool> {
        Binding(get: { editingSectionID != nil }, set: { if !$0 { editingSectionID = nil } })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        linkedInAuth.startImport { fields in
                            guard let fields else { return }
                            applyLinkedInFields(fields)
                            importNotice = "Name and email imported from LinkedIn"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importNotice = nil }
                        }
                    } label: {
                        Label("Import from LinkedIn", systemImage: "arrow.up.circle")
                    }
                    .disabled(linkedInAuth.isImporting)

                    Text("Import your name and email from LinkedIn")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let importNotice {
                        Text(importNotice)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.ColorToken.primary)
                    }

                    if let error = linkedInAuth.importError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                ForEach(appState.activeResume.sections.sorted(by: { $0.order < $1.order })) { section in
                    SectionRowView(section: section)
                        .contentShape(Rectangle())
                        .onTapGesture { editingSectionID = section.id }
                        .swipeActions(edge: .leading) {
                            Button { editingSectionID = section.id } label: { Label("Edit", systemImage: "pencil") }
                                .tint(DS.ColorToken.primary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button { mutate(section.id) { $0.isVisible.toggle() } } label: { Label("Hide", systemImage: "eye.slash") }
                                .tint(DS.ColorToken.surfaceOffset)
                            Button(role: .destructive) {
                                appState.activeResume.sections.removeAll { $0.id == section.id }
                                appState.saveResume()
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                }
                .onMove(perform: move)
            }
            .navigationTitle("Resume")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: isEditing) {
                if let binding = editingBinding {
                    SectionEditorView(section: binding) { appState.saveResume() }
                }
            }
        }
    }

    private var editingBinding: Binding<ResumeSection>? {
        guard let id = editingSectionID,
              let index = appState.activeResume.sections.firstIndex(where: { $0.id == id }) else { return nil }
        return $appState.activeResume.sections[index]
    }

    private func applyLinkedInFields(_ fields: LinkedInResumeFields) {
        if !fields.name.isEmpty { appState.activeResume.name = fields.name }
        if let index = appState.activeResume.sections.firstIndex(where: { $0.title.localizedCaseInsensitiveContains("summary") }) {
            if let fieldIndex = appState.activeResume.sections[index].fields.firstIndex(where: { $0.label.localizedCaseInsensitiveContains("email") }) {
                appState.activeResume.sections[index].fields[fieldIndex].value = fields.email
            } else if !fields.email.isEmpty {
                appState.activeResume.sections[index].fields.insert(ResumeField(label: "Email", value: fields.email), at: 0)
            }
        } else if !fields.email.isEmpty {
            appState.activeResume.sections.insert(
                ResumeSection(title: "Contact", fields: [ResumeField(label: "Email", value: fields.email)], order: 0),
                at: 0
            )
        }
        appState.saveResume()
    }

    private func mutate(_ id: UUID, change: (inout ResumeSection) -> Void) {
        if let index = appState.activeResume.sections.firstIndex(where: { $0.id == id }) {
            change(&appState.activeResume.sections[index])
            appState.saveResume()
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        appState.activeResume.sections.move(fromOffsets: source, toOffset: destination)
        for index in appState.activeResume.sections.indices { appState.activeResume.sections[index].order = index }
        appState.saveResume()
    }
}
