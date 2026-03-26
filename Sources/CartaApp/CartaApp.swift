import AppKit
import Combine
import SwiftUI

enum CartaFontFamily: String, CaseIterable {
    case monospaced = "monospaced"
    case sansSerif  = "sansSerif"
    case serif      = "serif"

    var displayName: String {
        switch self {
        case .monospaced: return "Terminal"
        case .sansSerif:  return "Sans Serif"
        case .serif:      return "Serif"
        }
    }

    func resolve(size: CGFloat, traits: NSFontTraitMask = []) -> NSFont {
        let base: NSFont
        switch self {
        case .monospaced:
            base = NSFont(name: "Menlo", size: size)
                ?? NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        case .sansSerif:
            base = NSFont.systemFont(ofSize: size)
        case .serif:
            base = NSFont(name: "Times New Roman", size: size)
                ?? NSFont(name: "Times", size: size)
                ?? NSFont.systemFont(ofSize: size)
        }
        if traits.isEmpty { return base }
        return NSFontManager.shared.convert(base, toHaveTrait: traits)
    }
}

final class CartaFontSettings: ObservableObject, @unchecked Sendable {
    static let shared = CartaFontSettings()

    private let key = "cartaFontFamily"
    @Published var family: CartaFontFamily {
        didSet {
            UserDefaults.standard.set(family.rawValue, forKey: key)
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: key),
           let stored = CartaFontFamily(rawValue: raw) {
            family = stored
        } else {
            family = .monospaced
        }
    }
}

@MainActor
final class CartaAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
final class CartaEditorState: ObservableObject {
    func reapplyFont() {
        for window in NSApp.windows {
            guard let textView = window.firstResponder as? NSTextView,
                  let storage = textView.textStorage else { continue }
            let fullRange = NSRange(location: 0, length: storage.length)
            guard fullRange.length > 0 else { continue }
            storage.beginEditing()
            storage.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                let sourceFont = (value as? NSFont) ?? CartaTypography.font(size: CartaTerminalMetrics.defaultFontSize)
                let converted = CartaTypography.convert(font: sourceFont)
                storage.addAttribute(.font, value: converted, range: range)
            }
            storage.endEditing()
            let typingFont = (textView.typingAttributes[.font] as? NSFont) ?? CartaTypography.font(size: CartaTerminalMetrics.defaultFontSize)
            textView.typingAttributes[.font] = CartaTypography.convert(font: typingFont)
            textView.didChangeText()
        }
    }

    func toggleBold() {
        toggleFontTrait(.boldFontMask)
    }

    func toggleItalic() {
        toggleFontTrait(.italicFontMask)
    }

    func toggleUnderline() {
        toggleTextAttribute(key: .underlineStyle, expectedValue: NSUnderlineStyle.single.rawValue)
    }

    func toggleStrikethrough() {
        toggleTextAttribute(key: .strikethroughStyle, expectedValue: NSUnderlineStyle.single.rawValue)
    }

    private func toggleTextAttribute(key: NSAttributedString.Key, expectedValue: Int) {
        guard let textView = activeTextView else { return }

        let storage = textView.textStorage ?? NSTextStorage()
        let selectedRange = textView.selectedRange()
        let targetRange = selectedRange.length > 0 ? selectedRange : NSRange(location: 0, length: storage.length)

        guard targetRange.location != NSNotFound else { return }

        if targetRange.length == 0 {
            let current = (textView.typingAttributes[key] as? Int) ?? 0
            textView.typingAttributes[key] = current == 0 ? expectedValue : 0
            textView.didChangeText()
            return
        }

        let shouldApply = !rangeHasAttributeValue(
            in: storage,
            range: targetRange,
            key: key,
            expected: expectedValue
        )

        storage.beginEditing()
        if shouldApply {
            storage.addAttribute(key, value: expectedValue, range: targetRange)
        } else {
            storage.removeAttribute(key, range: targetRange)
        }
        storage.endEditing()

        textView.typingAttributes[key] = shouldApply ? expectedValue : 0
        textView.didChangeText()
    }

    func increaseTextSize() {
        adjustTextSize(delta: 1)
    }

    func decreaseTextSize() {
        adjustTextSize(delta: -1)
    }

    private var activeTextView: NSTextView? {
        if let textView = NSApp.keyWindow?.firstResponder as? NSTextView {
            return textView
        }

        if let textView = NSApp.mainWindow?.firstResponder as? NSTextView {
            return textView
        }

        return nil
    }

    private func adjustTextSize(delta: CGFloat) {
        guard let textView = activeTextView else { return }

        let storage = textView.textStorage ?? NSTextStorage()
        let selectedRange = textView.selectedRange()
        let targetRange = selectedRange.length > 0 ? selectedRange : NSRange(location: 0, length: storage.length)

        guard targetRange.location != NSNotFound, targetRange.length > 0 else {
            let currentFont = textView.typingAttributes[.font] as? NSFont ?? CartaTypography.font(size: CartaTerminalMetrics.defaultFontSize)
            let nextSize = max(8, currentFont.pointSize + delta)
            textView.typingAttributes[.font] = NSFontManager.shared.convert(currentFont, toSize: nextSize)
            textView.didChangeText()
            return
        }

        storage.beginEditing()
        storage.enumerateAttribute(.font, in: targetRange) { value, range, _ in
            let currentFont = (value as? NSFont) ?? CartaTypography.font(size: CartaTerminalMetrics.defaultFontSize)
            let nextSize = max(8, currentFont.pointSize + delta)
            let resizedFont = NSFontManager.shared.convert(currentFont, toSize: nextSize)
            storage.addAttribute(.font, value: resizedFont, range: range)
        }
        storage.endEditing()

        if let currentFont = textView.typingAttributes[.font] as? NSFont {
            let nextSize = max(8, currentFont.pointSize + delta)
            textView.typingAttributes[.font] = NSFontManager.shared.convert(currentFont, toSize: nextSize)
        }

        textView.didChangeText()
    }

    private func toggleFontTrait(_ trait: NSFontTraitMask) {
        guard let textView = activeTextView else { return }

        let storage = textView.textStorage ?? NSTextStorage()
        let selectedRange = textView.selectedRange()
        let targetRange = selectedRange.length > 0 ? selectedRange : NSRange(location: 0, length: storage.length)

        guard targetRange.location != NSNotFound else { return }

        if targetRange.length == 0 {
            let currentFont = (textView.typingAttributes[.font] as? NSFont) ?? CartaTypography.font(size: CartaTerminalMetrics.defaultFontSize)
            textView.typingAttributes[.font] = toggledFont(from: currentFont, trait: trait)
            textView.didChangeText()
            return
        }

        let shouldEnableTrait = !rangeHasTrait(in: storage, range: targetRange, trait: trait)

        storage.beginEditing()
        storage.enumerateAttribute(.font, in: targetRange) { value, range, _ in
            let currentFont = (value as? NSFont) ?? CartaTypography.font(size: CartaTerminalMetrics.defaultFontSize)
            let updatedFont = shouldEnableTrait
                ? NSFontManager.shared.convert(currentFont, toHaveTrait: trait)
                : NSFontManager.shared.convert(currentFont, toNotHaveTrait: trait)
            storage.addAttribute(.font, value: updatedFont, range: range)
        }
        storage.endEditing()

        let typingFont = (textView.typingAttributes[.font] as? NSFont) ?? CartaTypography.font(size: CartaTerminalMetrics.defaultFontSize)
        textView.typingAttributes[.font] = shouldEnableTrait
            ? NSFontManager.shared.convert(typingFont, toHaveTrait: trait)
            : NSFontManager.shared.convert(typingFont, toNotHaveTrait: trait)
        textView.didChangeText()
    }

    private func toggledFont(from font: NSFont, trait: NSFontTraitMask) -> NSFont {
        let traits = NSFontManager.shared.traits(of: font)
        if traits.contains(trait) {
            return NSFontManager.shared.convert(font, toNotHaveTrait: trait)
        }
        return NSFontManager.shared.convert(font, toHaveTrait: trait)
    }

    private func rangeHasTrait(in storage: NSTextStorage, range: NSRange, trait: NSFontTraitMask) -> Bool {
        var found = false
        storage.enumerateAttribute(.font, in: range) { value, _, stop in
            let currentFont = (value as? NSFont) ?? CartaTypography.font(size: CartaTerminalMetrics.defaultFontSize)
            if NSFontManager.shared.traits(of: currentFont).contains(trait) {
                found = true
                stop.pointee = true
            }
        }
        return found
    }

    private func rangeHasAttributeValue(
        in storage: NSTextStorage,
        range: NSRange,
        key: NSAttributedString.Key,
        expected: Int
    ) -> Bool {
        var found = false
        storage.enumerateAttribute(key, in: range) { value, _, stop in
            if (value as? Int) == expected {
                found = true
                stop.pointee = true
            }
        }
        return found
    }
}

@MainActor
final class CartaNoteStore: ObservableObject {
    @Published private(set) var notes: [CartaNote] = []

    static let maxNotes = 5

    private let notesKey = "cartaNotes"
    private let lastOpenedNoteIDKey = "cartaLastOpenedNoteID"

    init() {
        load()

        if notes.isEmpty {
            _ = createNote(markAsOpened: true)
        }
    }

    var recentNotes: [CartaNote] {
        notes.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    var lastOpenedNoteID: String? {
        UserDefaults.standard.string(forKey: lastOpenedNoteIDKey)
    }

    var canCreateNote: Bool {
        notes.count < Self.maxNotes
    }

    func resolveNoteID(_ requestedNoteID: String?) -> String {
        if let requestedNoteID, note(withID: requestedNoteID) != nil {
            return requestedNoteID
        }

        if let lastOpenedNoteID, note(withID: lastOpenedNoteID) != nil {
            return lastOpenedNoteID
        }

        if let noteID = recentNotes.first?.id {
            return noteID
        }

        return createNote(markAsOpened: true) ?? ""
    }

    func note(withID noteID: String) -> CartaNote? {
        notes.first { $0.id == noteID }
    }

    func createNote(markAsOpened: Bool = true) -> String? {
        guard canCreateNote else { return nil }

        let note = CartaNote.empty()
        notes.append(note)
        save()

        if markAsOpened {
            markOpenedNote(noteID: note.id)
        }

        return note.id
    }

    func markOpenedNote(noteID: String) {
        guard note(withID: noteID) != nil else { return }
        UserDefaults.standard.set(noteID, forKey: lastOpenedNoteIDKey)
    }

    func updateNote(noteID: String, rtfData: Data) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].rtfData = rtfData
        notes[index].previewText = Self.previewText(from: rtfData)
        notes[index].updatedAt = .now
        save()
    }

    func togglePinned(noteID: String) {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { return }
        notes[index].isPinned.toggle()
        save()
    }

    func deleteNote(noteID: String) {
        closeWindows(for: noteID)
        notes.removeAll { $0.id == noteID }

        if notes.isEmpty {
            let replacementID = createNote(markAsOpened: true) ?? ""
            UserDefaults.standard.set(replacementID, forKey: lastOpenedNoteIDKey)
            return
        }

        if lastOpenedNoteID == noteID {
            UserDefaults.standard.set(recentNotes.first?.id, forKey: lastOpenedNoteIDKey)
        }

        save()
    }

    private func closeWindows(for noteID: String) {
        let identifier = NSUserInterfaceItemIdentifier(noteID)
        for window in NSApp.windows where window.identifier == identifier {
            window.close()
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: notesKey),
              let decoded = try? JSONDecoder().decode([CartaNote].self, from: data) else {
            notes = []
            return
        }

        notes = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        UserDefaults.standard.set(data, forKey: notesKey)
        objectWillChange.send()
    }

    private static func previewText(from rtfData: Data) -> String {
        guard !rtfData.isEmpty,
              let attributed = try? NSAttributedString(
                data: rtfData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
              ) else {
            return ""
        }

        let collapsed = attributed.string
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return String(collapsed.prefix(60))
    }
}

struct CartaNote: Identifiable, Codable, Equatable {
    let id: String
    var rtfData: Data
    var previewText: String
    let createdAt: Date
    var updatedAt: Date
    var isPinned: Bool

    var menuTitle: String {
        previewText.isEmpty ? "Empty Note" : previewText
    }

    static func empty() -> CartaNote {
        let now = Date()
        return CartaNote(
            id: UUID().uuidString,
            rtfData: Data(),
            previewText: "",
            createdAt: now,
            updatedAt: now,
            isPinned: false
        )
    }
}

enum CartaTypography {
    static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 0
        return style.copy() as? NSParagraphStyle ?? style
    }

    static func font(size: CGFloat, traits: NSFontTraitMask = []) -> NSFont {
        CartaFontSettings.shared.family.resolve(size: size, traits: traits)
    }

    static func convert(font sourceFont: NSFont) -> NSFont {
        let traits = NSFontManager.shared.traits(of: sourceFont)
        return font(size: sourceFont.pointSize, traits: traits)
    }

    static func attributes(size: CGFloat, font: NSFont? = nil) -> [NSAttributedString.Key: Any] {
        let resolvedFont = font ?? self.font(size: size)
        return [
            .font: resolvedFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
    }
}

enum CartaTerminalMetrics {
    static let defaultFontSize: CGFloat = 10
    static let defaultColumns: CGFloat = 59
    static let defaultRows: CGFloat = 25
    static let minimumColumns: CGFloat = 20
    static let minimumRows: CGFloat = 6
    static let scrollBottomInsetMultiplier: CGFloat = 1.0

    static func cellSize(for font: NSFont = CartaTypography.font(size: defaultFontSize)) -> CGSize {
        let characterWidth = ceil(("W" as NSString).size(withAttributes: [.font: font]).width)
        let lineHeight = ceil(NSLayoutManager().defaultLineHeight(for: font))
        return CGSize(width: characterWidth, height: lineHeight)
    }

    static var scrollBottomInset: CGFloat {
        ceil(cellSize().height * scrollBottomInsetMultiplier)
    }

    static func contentSize(columns: CGFloat, rows: CGFloat, horizontalInset: CGFloat, verticalInset: CGFloat) -> CGSize {
        let cell = cellSize()
        return CGSize(
            width: ceil(columns * cell.width + horizontalInset),
            height: ceil(rows * cell.height + verticalInset)
        )
    }
}

enum CartaWindowTitleFormatter {
    static let fullFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "MMM d, yyyy 'at' HH:mm"
        return formatter
    }()

    static let mediumFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "MMM d, HH:mm"
        return formatter
    }()

    static let compactFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func title(for date: Date, availableWidth: CGFloat) -> String {
        if availableWidth >= 400 {
            return fullFormatter.string(from: date)
        }
        if availableWidth >= 260 {
            return mediumFormatter.string(from: date)
        }
        return compactFormatter.string(from: date)
    }
}

enum CartaUIColors {
    static let menuHover = Color(
        nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(white: 1.0, alpha: 0.08)
                : NSColor(white: 0.0, alpha: 0.08)
        }
    )
}

@main
struct CartaApp: App {
    @NSApplicationDelegateAdaptor(CartaAppDelegate.self) private var cartaAppDelegate
    @StateObject private var editorState = CartaEditorState()
    @StateObject private var noteStore = CartaNoteStore()
    @StateObject private var fontSettings = CartaFontSettings.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("Carta", for: String.self) { noteID in
            CartaNoteWindowView(requestedNoteID: noteID.wrappedValue)
                .environmentObject(editorState)
                .environmentObject(noteStore)
                .environmentObject(fontSettings)
        }
        .defaultSize(width: 420, height: 520)
        .windowResizability(.contentMinSize)

        MenuBarExtra("Carta", systemImage: "note.text") {
            CartaMenuPanel(
                noteStore: noteStore,
                openNote: { noteID in
                    noteStore.markOpenedNote(noteID: noteID)
                    openWindow(value: noteID)
                    NSApp.activate(ignoringOtherApps: true)
                },
                createNote: {
                    guard let noteID = noteStore.createNote() else { return }
                    openWindow(value: noteID)
                    NSApp.activate(ignoringOtherApps: true)
                },
                quitApp: {
                    NSApplication.shared.terminate(nil)
                }
            )
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandMenu("Format") {
                Button("Bold") {
                    editorState.toggleBold()
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Italic") {
                    editorState.toggleItalic()
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Underline") {
                    editorState.toggleUnderline()
                }
                .keyboardShortcut("u", modifiers: .command)

                Button("Strikethrough") {
                    editorState.toggleStrikethrough()
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])

                Divider()

                Button("Increase Text Size") {
                    editorState.increaseTextSize()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Decrease Text Size") {
                    editorState.decreaseTextSize()
                }
                .keyboardShortcut("-", modifiers: .command)

                Divider()

                Menu("Font") {
                    ForEach(CartaFontFamily.allCases, id: \.self) { family in
                        Button {
                            fontSettings.family = family
                            editorState.reapplyFont()
                        } label: {
                            if fontSettings.family == family {
                                Text("✓ \(family.displayName)")
                            } else {
                                Text("   \(family.displayName)")
                            }
                        }
                    }
                }
            }

            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    guard let noteID = noteStore.createNote() else { return }
                    openWindow(value: noteID)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

private struct CartaMenuPanel: View {
    @ObservedObject var noteStore: CartaNoteStore

    let openNote: (String) -> Void
    let createNote: () -> Void
    let quitApp: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(0..<CartaNoteStore.maxNotes, id: \.self) { index in
                    if index < noteStore.recentNotes.count {
                        let note = noteStore.recentNotes[index]
                        CartaRecentNoteRow(
                            note: note,
                            openAction: {
                                openNote(note.id)
                            },
                            deleteAction: {
                                noteStore.deleteNote(noteID: note.id)
                            }
                        )
                    } else {
                        CartaEmptyNoteRow(createAction: createNote)
                    }
                }
            }

            Divider()

            CartaHoverButton(action: quitApp) {
                Text("Quit")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(width: 280)
    }
}

private struct CartaRecentNoteRow: View {
    let note: CartaNote
    let openAction: () -> Void
    let deleteAction: () -> Void

    @State private var isRowHovered = false
    @State private var isDeleteHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Button(action: openAction) {
                Text(note.menuTitle)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(hoverBackground(isActive: isRowHovered))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isRowHovered = hovering
            }

            Button(action: deleteAction) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
                    .padding(2)
                    .contentShape(Rectangle())
                    .background(hoverBackground(isActive: isDeleteHovered))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isDeleteHovered = hovering
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hoverBackground(isActive: Bool) -> Color {
        isActive ? CartaUIColors.menuHover : .clear
    }
}

private struct CartaEmptyNoteRow: View {
    let createAction: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: createAction) {
            Text("New Note +")
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                .background(isHovered ? CartaUIColors.menuHover : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct CartaHoverButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            label()
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(isHovered ? CartaUIColors.menuHover : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct CartaNoteWindowView: View {
    let requestedNoteID: String?

    private let topMargin: CGFloat = 0
    private let sideMargin: CGFloat = 6
    private let bottomMargin: CGFloat = 0

    @EnvironmentObject private var noteStore: CartaNoteStore
    @EnvironmentObject private var editorState: CartaEditorState

    @State private var resolvedNoteID: String = ""

    private var currentNote: CartaNote? {
        noteStore.note(withID: resolvedNoteID)
    }

    private var titleDate: Date? {
        currentNote?.createdAt
    }

    private var horizontalInset: CGFloat {
        sideMargin * 2
    }

    private var verticalInset: CGFloat {
        topMargin + bottomMargin + CartaTerminalMetrics.scrollBottomInset
    }

    var body: some View {
        Group {
            if resolvedNoteID.isEmpty {
                Color(nsColor: .textBackgroundColor)
            } else {
                ZStack(alignment: .topLeading) {
                    CartaRichTextView(
                        richTextData: Binding(
                            get: { noteStore.note(withID: resolvedNoteID)?.rtfData ?? Data() },
                            set: { noteStore.updateNote(noteID: resolvedNoteID, rtfData: $0) }
                        )
                    )
                    .environmentObject(editorState)
                    .padding(.top, topMargin)
                    .padding(.horizontal, sideMargin)
                    .padding(.bottom, bottomMargin)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .frame(minWidth: 120, minHeight: 80)
            }
        }
        .background(
            CartaWindowConfigurator(
                noteID: resolvedNoteID,
                titleDate: titleDate,
                horizontalInset: horizontalInset,
                verticalInset: verticalInset
            )
            .id("\(resolvedNoteID)-\(titleDate?.timeIntervalSinceReferenceDate ?? 0)")
        )
        .onAppear {
            resolveWindowNote()
        }
        .onChange(of: requestedNoteID) { _ in
            resolveWindowNote()
        }
        .onReceive(noteStore.$notes) { _ in
            guard !resolvedNoteID.isEmpty else { return }
            if noteStore.note(withID: resolvedNoteID) == nil {
                resolvedNoteID = noteStore.resolveNoteID(nil)
                noteStore.markOpenedNote(noteID: resolvedNoteID)
            }
        }
    }

    private func resolveWindowNote() {
        resolvedNoteID = noteStore.resolveNoteID(requestedNoteID)
        noteStore.markOpenedNote(noteID: resolvedNoteID)
    }
}

private struct CartaWindowConfigurator: NSViewRepresentable {
    let noteID: String
    let titleDate: Date?
    let horizontalInset: CGFloat
    let verticalInset: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = CartaWindowObserverView()
        view.onWindowChange = { window in
            configure(window: window, coordinator: context.coordinator)
        }

        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configure(window: window, coordinator: context.coordinator)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            configure(window: window, coordinator: context.coordinator)
        }
    }

    private func configure(window: NSWindow, coordinator: Coordinator) {
        window.level = .floating
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.isReleasedWhenClosed = false
        window.identifier = noteID.isEmpty ? nil : NSUserInterfaceItemIdentifier(noteID)
        if let titleDate {
            window.title = CartaWindowTitleFormatter.title(
                for: titleDate,
                availableWidth: window.frame.width
            )
        } else {
            window.title = "Carta"
        }
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = true
        window.backgroundColor = .windowBackgroundColor
        window.isOpaque = true

        let minimumContentSize = CartaTerminalMetrics.contentSize(
            columns: CartaTerminalMetrics.minimumColumns,
            rows: CartaTerminalMetrics.minimumRows,
            horizontalInset: horizontalInset,
            verticalInset: verticalInset
        )
        let defaultContentSize = CartaTerminalMetrics.contentSize(
            columns: CartaTerminalMetrics.defaultColumns,
            rows: CartaTerminalMetrics.defaultRows,
            horizontalInset: horizontalInset,
            verticalInset: verticalInset
        )
        let cell = CartaTerminalMetrics.cellSize()

        window.contentMinSize = minimumContentSize
        window.contentResizeIncrements = cell

        if !coordinator.hasAppliedInitialSize {
            window.setContentSize(defaultContentSize)
            coordinator.hasAppliedInitialSize = true
        }
    }

    @MainActor
    final class Coordinator {
        var hasAppliedInitialSize = false
    }
}

private final class CartaWindowObserverView: NSView {
    var onWindowChange: ((NSWindow) -> Void)?
    private weak var observedWindow: NSWindow?

    deinit {
        if let observedWindow {
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.didResizeNotification,
                object: observedWindow
            )
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }

        if observedWindow !== window {
            if let observedWindow {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSWindow.didResizeNotification,
                    object: observedWindow
                )
            }

            observedWindow = window
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleWindowResize(_:)),
                name: NSWindow.didResizeNotification,
                object: window
            )
        }

        onWindowChange?(window)
    }

    @objc private func handleWindowResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        onWindowChange?(window)
    }
}

private final class CartaPagingScrollView: NSScrollView {
    var lineHeightProvider: (() -> CGFloat)?
    private var pendingScrollDeltaY: CGFloat = 0

    override func scrollWheel(with event: NSEvent) {
        guard let documentView,
              let lineHeight = lineHeightProvider?(),
              lineHeight > 0 else {
            super.scrollWheel(with: event)
            return
        }

        let deltaY = CGFloat(event.scrollingDeltaY)
        let directionAdjustedDelta = event.isDirectionInvertedFromDevice ? -deltaY : deltaY

        if event.hasPreciseScrollingDeltas {
            pendingScrollDeltaY += directionAdjustedDelta

            var stepCount = Int(pendingScrollDeltaY / lineHeight)
            if stepCount == 0, event.phase == .ended || event.momentumPhase == .ended {
                stepCount = Int((pendingScrollDeltaY / lineHeight).rounded())
            }

            guard stepCount != 0 else { return }

            pendingScrollDeltaY -= CGFloat(stepCount) * lineHeight
            scrollBy(lines: stepCount, lineHeight: lineHeight, documentView: documentView)
            return
        }

        pendingScrollDeltaY = 0
        let stepCount = max(1, Int(abs(deltaY))) * (directionAdjustedDelta > 0 ? 1 : -1)
        scrollBy(lines: stepCount, lineHeight: lineHeight, documentView: documentView)
    }

    private func scrollBy(lines: Int, lineHeight: CGFloat, documentView: NSView) {
        let currentOriginY = contentView.bounds.origin.y
        let maxOriginY = max(
            0,
            documentView.bounds.height + contentInsets.bottom - contentView.bounds.height
        )
        let nextOriginY = min(
            max(currentOriginY + CGFloat(lines) * lineHeight, 0),
            maxOriginY
        )

        guard abs(nextOriginY - currentOriginY) > 0.5 else { return }

        contentView.setBoundsOrigin(NSPoint(x: 0, y: nextOriginY))
        reflectScrolledClipView(contentView)
    }
}

private final class CartaPlainPasteTextView: NSTextView {
    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }

    override func pasteAsRichText(_ sender: Any?) {
        pasteAsPlainText(sender)
    }
}

private struct CartaRichTextView: NSViewRepresentable {
    @Binding var richTextData: Data

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = CartaPagingScrollView()
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let textView = CartaPlainPasteTextView(frame: .zero, textContainer: textContainer)
        scrollView.documentView = textView

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesInspectorBar = false
        textView.allowsUndo = true
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.defaultParagraphStyle = CartaTypography.paragraphStyle
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.typingAttributes = [
            .font: CartaTypography.font(size: CartaTerminalMetrics.defaultFontSize),
            .paragraphStyle: CartaTypography.paragraphStyle
        ]
        textView.insertionPointColor = .labelColor
        textView.textColor = .labelColor
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.contentInsets = NSEdgeInsets(
            top: 0,
            left: 0,
            bottom: CartaTerminalMetrics.scrollBottomInset,
            right: 0
        )
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.lineHeightProvider = {
            let typingFont = (textView.typingAttributes[.font] as? NSFont) ?? CartaTypography.font(size: CartaTerminalMetrics.defaultFontSize)
            return ceil(layoutManager.defaultLineHeight(for: typingFont))
        }

        context.coordinator.configure(
            scrollView: scrollView,
            textView: textView,
            richTextData: richTextData
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        context.coordinator.refresh(scrollView: scrollView, textView: textView, richTextData: richTextData)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CartaRichTextView
        private var lastRTF = Data()
        private var isApplyingExternalUpdate = false

        init(_ parent: CartaRichTextView) {
            self.parent = parent
        }

        func configure(scrollView: NSScrollView, textView: NSTextView, richTextData: Data) {
            applyStoredContent(to: textView, richTextData: richTextData)
        }

        func refresh(scrollView: NSScrollView, textView: NSTextView, richTextData: Data) {
            if richTextData != lastRTF {
                applyStoredContent(to: textView, richTextData: richTextData)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingExternalUpdate,
                  let textView = notification.object as? NSTextView else { return }
            persist(textView: textView)
        }

        private func applyStoredContent(to textView: NSTextView, richTextData: Data) {
            isApplyingExternalUpdate = true
            defer { isApplyingExternalUpdate = false }

            let attributed: NSMutableAttributedString
            if richTextData.isEmpty {
                attributed = NSMutableAttributedString(string: "", attributes: CartaTypography.attributes(size: CartaTerminalMetrics.defaultFontSize))
            } else if let loaded = try? NSAttributedString(
                data: richTextData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            ) {
                attributed = NSMutableAttributedString(attributedString: loaded)
                normalizeAttributes(in: attributed)
            } else {
                attributed = NSMutableAttributedString(string: "", attributes: CartaTypography.attributes(size: CartaTerminalMetrics.defaultFontSize))
            }

            textView.textStorage?.setAttributedString(attributed)
            let typingSize = currentTypingSize(from: textView, fallback: CartaTerminalMetrics.defaultFontSize)
            textView.typingAttributes = CartaTypography.attributes(size: typingSize)
            lastRTF = serializedRTF(from: attributed)
        }

        private func normalizeAttributes(in attributed: NSMutableAttributedString) {
            let fullRange = NSRange(location: 0, length: attributed.length)
            guard fullRange.length > 0 else { return }

            attributed.enumerateAttribute(.font, in: fullRange) { value, range, _ in
                let sourceFont = (value as? NSFont) ?? CartaTypography.font(size: CartaTerminalMetrics.defaultFontSize)
                let converted = CartaTypography.convert(font: sourceFont)
                attributed.addAttributes(CartaTypography.attributes(size: converted.pointSize, font: converted), range: range)
            }

            attributed.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
        }

        private func persist(textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let data = serializedRTF(from: storage)
            lastRTF = data
            parent.richTextData = data
        }

        private func serializedRTF(from attributed: NSAttributedString) -> Data {
            let range = NSRange(location: 0, length: attributed.length)
            return (try? attributed.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )) ?? Data()
        }

        private func currentTypingSize(from textView: NSTextView, fallback: CGFloat) -> CGFloat {
            if let font = textView.typingAttributes[.font] as? NSFont {
                return font.pointSize
            }
            return fallback
        }

    }
}
