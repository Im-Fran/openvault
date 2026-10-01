import OpenVaultCore
import SwiftUI

enum SidebarSelection: Hashable {
    case all
    case kind(Item.Kind)
    case project(String)
    case folder(String)
}

struct ContentView: View {
    @Environment(VaultStore.self) private var store
    @State private var sidebar: SidebarSelection? = .all
    @State private var selection: Item.ID?
    @State private var search = ""
    @State private var dropTargeted = false
    @AppStorage("groupByProject") private var groupByProject = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var filtered: [Item] {
        store.vault.items
            .filter { item in
                switch sidebar ?? .all {
                case .all: true
                case .kind(let kind): item.kind == kind
                case .project(let project): item.project == project
                case .folder(let folder): item.folder == folder
                }
            }
            .searched(search)
    }

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $sidebar)
        } content: {
            ItemList(items: filtered, groupByProject: groupByProject && !showsOneProject, selection: $selection)
                .searchable(text: $search, placement: .sidebar, prompt: "Search")
                .navigationTitle(title)
        } detail: {
            if let item = store.vault.items.first(where: { $0.id == selection }) {
                ItemDetailView(item: item)
                    .id(item.id)
            } else {
                ContentUnavailableView("Select an Item", systemImage: "key.viewfinder",
                                       description: Text("Or drag a .env file, an SSH or GPG key, or any file into the window."))
            }
        }
        .toolbar {
            ToolbarItem {
                Toggle("Group by Project", systemImage: "square.stack.3d.up", isOn: $groupByProject.animation(reduceMotion ? nil : Motion.standard))
                    .help("Group by Project")
                    .disabled(showsOneProject)
            }
            ToolbarItem {
                Button("New Item", systemImage: "plus") { newItem() }
                    .help("New Item (⌘N)")
            }
            ToolbarItem {
                Button("Lock", systemImage: "lock") { store.lock() }
                    .help("Lock (⌘L)")
            }
        }
        .sheet(item: Bindable(store).editorDraft) { draft in
            ItemEditorView(draft: draft) { saved in
                store.save(saved)
                withAnimation(Motion.standard) { selection = saved.id }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            importFile(urls.first)
        } isTargeted: { dropTargeted = $0 }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: .init(lineWidth: 3, dash: [8, 6]))
                    .padding(6)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(Motion.standard, value: dropTargeted)
    }

    /// Grouping a single project's items would only repeat the title.
    private var showsOneProject: Bool {
        if case .project = sidebar { true } else { false }
    }

    private var title: String {
        switch sidebar ?? .all {
        case .all: String(localized: "All")
        case .kind(let kind): kind.title
        case .project(let project): project
        case .folder(let folder): folder
        }
    }

    /// New items inherit the current sidebar context (kind, project or folder).
    private func newItem() {
        var item = Item(name: "", kind: .secret, content: "")
        if case .kind(let kind) = sidebar { item.kind = kind }
        if case .project(let project) = sidebar { item.project = project }
        if case .folder(let folder) = sidebar { item.folder = folder }
        store.editorDraft = EditorDraft(item: item, isNew: true)
    }

    private func importFile(_ url: URL?) -> Bool {
        guard let url else { return false }
        let name = url.lastPathComponent
        var item: Item
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            item = Item(name: name, kind: .detect(fileName: name, content: content), content: content)
        } else if let file = Item.file(at: url) { // not text: keep the raw bytes
            item = file
        } else {
            return false
        }
        if case .project(let project) = sidebar { item.project = project }
        if case .folder(let folder) = sidebar { item.folder = folder }
        store.editorDraft = EditorDraft(item: item, isNew: true)
        return true
    }
}

private struct Sidebar: View {
    @Environment(VaultStore.self) private var store
    @Binding var selection: SidebarSelection?

    var body: some View {
        List(selection: $selection) {
            row(String(localized: "All"), symbol: "tray.full", tint: .accentColor, count: store.vault.items.count)
                .tag(SidebarSelection.all)

            Section("Types") {
                ForEach(Item.Kind.allCases, id: \.self) { kind in
                    row(kind.title, symbol: kind.symbol, tint: kind.tint,
                        count: store.vault.items.count { $0.kind == kind })
                        .tag(SidebarSelection.kind(kind))
                }
            }

            if !store.vault.projects.isEmpty {
                Section("Projects") {
                    ForEach(store.vault.projects, id: \.self) { project in
                        row(project, symbol: "square.stack.3d.up", tint: .secondary,
                            count: store.vault.items.count { $0.project == project })
                            .tag(SidebarSelection.project(project))
                    }
                }
            }

            if !store.vault.folders.isEmpty {
                Section("Folders") {
                    ForEach(store.vault.folders, id: \.self) { folder in
                        row(folder, symbol: "folder", tint: .secondary,
                            count: store.vault.items.count { $0.folder == folder })
                            .tag(SidebarSelection.folder(folder))
                    }
                }
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 210)
    }

    private func row(_ title: String, symbol: String, tint: Color, count: Int) -> some View {
        Label { Text(title) } icon: { Image(systemName: symbol).foregroundStyle(tint) }
            .badge(count)
    }
}

/// Kind icon, name, project and last change. Shared by the main list and the menu bar.
struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.kind.symbol)
                .foregroundStyle(item.kind.tint)
                .accessibilityLabel(item.kind.singular)
                .frame(width: 28, height: 28)
                .background(item.kind.tint.opacity(0.14), in: .rect(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).font(.body.weight(.medium)).lineLimit(1)
                HStack(spacing: 4) {
                    if let project = item.project { Text(project) ; Text(verbatim: "·") }
                    if let folder = item.folder { Label(folder, systemImage: "folder").labelStyle(.titleAndIcon) ; Text(verbatim: "·") }
                    Text(item.updatedAt, format: .relative(presentation: .named))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ItemList: View {
    let items: [Item]
    let groupByProject: Bool
    @Binding var selection: Item.ID?
    @Environment(VaultStore.self) private var store
    @State private var pendingDelete: Item?

    /// One section per project (by name), items without one last.
    private var groups: [(project: String?, items: [Item])] {
        Dictionary(grouping: items, by: \.project)
            .map { ($0.key, $0.value) }
            .sorted { a, b in
                guard let pa = a.project else { return false }
                guard let pb = b.project else { return true }
                return pa.localizedStandardCompare(pb) == .orderedAscending
            }
    }

    var body: some View {
        List(selection: $selection) {
            if groupByProject {
                ForEach(groups, id: \.project) { group in
                    Section(group.project ?? String(localized: "No Project")) { rows(group.items) }
                }
            } else {
                rows(items)
            }
        }
        .animation(Motion.standard, value: items)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("No Items", systemImage: "tray",
                                       description: Text("Create one with ⌘N or drag a file here."))
            }
        }
        .onDeleteCommand {
            pendingDelete = items.first { $0.id == selection }
        }
        .confirmationDialog("Delete “\(pendingDelete?.name ?? "")”?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let item = pendingDelete { store.delete(item) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("This action can’t be undone.")
        }
        .navigationSplitViewColumnWidth(min: 240, ideal: 280)
    }

    private func rows(_ items: [Item]) -> some View {
        ForEach(items) { item in
            ItemRow(item: item)
                .contextMenu {
                    Button("Edit") { store.editorDraft = EditorDraft(item: item, isNew: false) }
                    Button("Delete", role: .destructive) { pendingDelete = item }
                }
        }
    }
}
