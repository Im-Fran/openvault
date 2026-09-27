import OpenVaultCore
import SwiftUI

enum SidebarSelection: Hashable {
    case all
    case kind(Item.Kind)
    case project(String)
}

struct ContentView: View {
    @Environment(VaultStore.self) private var store
    @State private var sidebar: SidebarSelection? = .all
    @State private var selection: Item.ID?
    @State private var search = ""
    @State private var dropTargeted = false

    private var filtered: [Item] {
        store.vault.items
            .filter { item in
                switch sidebar ?? .all {
                case .all: true
                case .kind(let kind): item.kind == kind
                case .project(let project): item.project == project
                }
            }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || ($0.project ?? "").localizedCaseInsensitiveContains(search) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $sidebar)
        } content: {
            ItemList(items: filtered, selection: $selection)
                .searchable(text: $search, placement: .sidebar, prompt: "Buscar")
                .navigationTitle(title)
        } detail: {
            if let item = store.vault.items.first(where: { $0.id == selection }) {
                ItemDetailView(item: item)
                    .id(item.id)
            } else {
                ContentUnavailableView("Selecciona un item", systemImage: "key.viewfinder",
                                       description: Text("O arrastra un .env, una clave SSH o GPG a la ventana."))
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Nuevo item", systemImage: "plus") { newItem() }
                    .help("Nuevo item (⌘N)")
            }
            ToolbarItem {
                Button("Bloquear", systemImage: "lock") { store.lock() }
                    .help("Bloquear (⌘L)")
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

    private var title: String {
        switch sidebar ?? .all {
        case .all: "Todos"
        case .kind(let kind): kind.title
        case .project(let project): project
        }
    }

    /// New items inherit the current sidebar context (kind or project).
    private func newItem() {
        var item = Item(name: "", kind: .secret, content: "")
        if case .kind(let kind) = sidebar { item.kind = kind }
        if case .project(let project) = sidebar { item.project = project }
        store.editorDraft = EditorDraft(item: item, isNew: true)
    }

    private func importFile(_ url: URL?) -> Bool {
        guard let url, let content = try? String(contentsOf: url, encoding: .utf8) else { return false }
        let name = url.lastPathComponent
        var item = Item(name: name, kind: .detect(fileName: name, content: content), content: content)
        if case .project(let project) = sidebar { item.project = project }
        store.editorDraft = EditorDraft(item: item, isNew: true)
        return true
    }
}

private struct Sidebar: View {
    @Environment(VaultStore.self) private var store
    @Binding var selection: SidebarSelection?

    var body: some View {
        List(selection: $selection) {
            row("Todos", symbol: "tray.full", tint: .accentColor, count: store.vault.items.count)
                .tag(SidebarSelection.all)

            Section("Tipos") {
                ForEach(Item.Kind.allCases, id: \.self) { kind in
                    row(kind.title, symbol: kind.symbol, tint: kind.tint,
                        count: store.vault.items.count { $0.kind == kind })
                        .tag(SidebarSelection.kind(kind))
                }
            }

            if !store.vault.projects.isEmpty {
                Section("Proyectos") {
                    ForEach(store.vault.projects, id: \.self) { project in
                        row(project, symbol: "folder", tint: .secondary,
                            count: store.vault.items.count { $0.project == project })
                            .tag(SidebarSelection.project(project))
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

private struct ItemList: View {
    let items: [Item]
    @Binding var selection: Item.ID?
    @Environment(VaultStore.self) private var store
    @State private var pendingDelete: Item?

    var body: some View {
        List(items, selection: $selection) { item in
            HStack(spacing: 10) {
                Image(systemName: item.kind.symbol)
                    .foregroundStyle(item.kind.tint)
                    .accessibilityLabel(item.kind.singular)
                    .frame(width: 28, height: 28)
                    .background(item.kind.tint.opacity(0.14), in: .rect(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name).font(.body.weight(.medium)).lineLimit(1)
                    HStack(spacing: 4) {
                        if let project = item.project { Text(project) ; Text("·") }
                        Text(item.updatedAt, format: .relative(presentation: .named))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .padding(.vertical, 2)
            .contextMenu {
                Button("Editar") { store.editorDraft = EditorDraft(item: item, isNew: false) }
                Button("Eliminar", role: .destructive) { pendingDelete = item }
            }
        }
        .animation(Motion.standard, value: items)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView("Sin items", systemImage: "tray",
                                       description: Text("Crea uno con ⌘N o arrastra un archivo aquí."))
            }
        }
        .onDeleteCommand {
            pendingDelete = items.first { $0.id == selection }
        }
        .confirmationDialog("¿Eliminar «\(pendingDelete?.name ?? "")»?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                            titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if let item = pendingDelete { store.delete(item) }
                pendingDelete = nil
            }
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
        .navigationSplitViewColumnWidth(min: 240, ideal: 280)
    }
}
