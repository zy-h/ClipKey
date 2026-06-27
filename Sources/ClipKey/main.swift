import AppKit
import Carbon
import Combine
import SwiftUI

private let appName = "ClipKey"

extension Notification.Name {
    static let clipKeyHotKeyPressed = Notification.Name("clipKeyHotKeyPressed")
}

enum ClipboardEntryKind: String, Codable {
    case text
    case image
}

struct ClipboardEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: ClipboardEntryKind
    let text: String?
    let imageFileName: String?
    let rtfFileName: String?
    let htmlFileName: String?
    let createdAt: Date

    init(
        id: UUID,
        kind: ClipboardEntryKind,
        text: String?,
        imageFileName: String?,
        rtfFileName: String?,
        htmlFileName: String?,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.imageFileName = imageFileName
        self.rtfFileName = rtfFileName
        self.htmlFileName = htmlFileName
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(ClipboardEntryKind.self, forKey: .kind)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        rtfFileName = try container.decodeIfPresent(String.self, forKey: .rtfFileName)
        htmlFileName = try container.decodeIfPresent(String.self, forKey: .htmlFileName)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

enum AppLanguage: String, CaseIterable {
    case english
    case chinese

    var menuTitle: String {
        switch self {
        case .english: "English"
        case .chinese: "中文"
        }
    }
}

@MainActor
final class AppLocalizer: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
        }
    }

    init() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage"),
           let language = AppLanguage(rawValue: savedLanguage) {
            self.language = language
        } else {
            let preferredLanguage = Locale.preferredLanguages.first ?? ""
            self.language = preferredLanguage.hasPrefix("zh") ? .chinese : .english
        }
    }

    func text(_ key: LocalizedKey) -> String {
        switch language {
        case .english:
            key.english
        case .chinese:
            key.chinese
        }
    }
}

enum LocalizedKey {
    case clearHistory
    case delete
    case done
    case image
    case keepLast
    case language
    case menuBarIconDescription
    case noClipboardHistory
    case openAccessibilityPermission
    case pauseRecording
    case quit
    case resumeRecording
    case searchClipboard
    case settings
    case showInMenuBar
    case showHistory
    case windowTitle

    var english: String {
        switch self {
        case .clearHistory: "Clear History"
        case .delete: "Delete"
        case .done: "Done"
        case .image: "Image"
        case .keepLast: "Keep Last"
        case .language: "Language"
        case .menuBarIconDescription: "When hidden, open ClipKey from Applications or Launchpad to change settings."
        case .noClipboardHistory: "No Clipboard History"
        case .openAccessibilityPermission: "Open Accessibility Permission"
        case .pauseRecording: "Pause Recording"
        case .quit: "Quit"
        case .resumeRecording: "Resume Recording"
        case .searchClipboard: "Search clipboard"
        case .settings: "Settings"
        case .showInMenuBar: "Show in Menu Bar"
        case .showHistory: "Show History"
        case .windowTitle: "Clipboard History"
        }
    }

    var chinese: String {
        switch self {
        case .clearHistory: "清空历史"
        case .delete: "删除"
        case .done: "完成"
        case .image: "图片"
        case .keepLast: "保留最近"
        case .language: "语言"
        case .menuBarIconDescription: "隐藏后，可从应用程序或启动台打开 ClipKey 来修改设置。"
        case .noClipboardHistory: "暂无剪贴板历史"
        case .openAccessibilityPermission: "打开辅助功能权限"
        case .pauseRecording: "暂停记录"
        case .quit: "退出"
        case .resumeRecording: "继续记录"
        case .searchClipboard: "搜索剪贴板"
        case .settings: "设置"
        case .showInMenuBar: "在菜单栏显示图标"
        case .showHistory: "显示历史"
        case .windowTitle: "剪贴板历史"
        }
    }
}

@MainActor
final class AppPreferences: ObservableObject {
    @Published var showMenuBarIcon: Bool {
        didSet {
            UserDefaults.standard.set(showMenuBarIcon, forKey: "showMenuBarIcon")
        }
    }

    init() {
        if UserDefaults.standard.object(forKey: "showMenuBarIcon") == nil {
            showMenuBarIcon = true
        } else {
            showMenuBarIcon = UserDefaults.standard.bool(forKey: "showMenuBarIcon")
        }
    }
}

@MainActor
final class ClipboardHistory: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []
    @Published var maxItems: Int {
        didSet {
            UserDefaults.standard.set(maxItems, forKey: "maxItems")
            trim()
        }
    }

    private let fileURL: URL
    private let imagesDirectoryURL: URL
    private let richTextDirectoryURL: URL
    private let allowedLimits = [20, 30, 50, 100]

    init() {
        let savedLimit = UserDefaults.standard.integer(forKey: "maxItems")
        maxItems = allowedLimits.contains(savedLimit) ? savedLimit : 30

        let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent(appName, isDirectory: true)

        try? FileManager.default.createDirectory(
            at: supportDirectory,
            withIntermediateDirectories: true
        )

        fileURL = supportDirectory.appendingPathComponent("history.json")
        imagesDirectoryURL = supportDirectory.appendingPathComponent("Images", isDirectory: true)
        richTextDirectoryURL = supportDirectory.appendingPathComponent("RichText", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: imagesDirectoryURL,
            withIntermediateDirectories: true
        )
        try? FileManager.default.createDirectory(
            at: richTextDirectoryURL,
            withIntermediateDirectories: true
        )
        load()
    }

    func addText(from pasteboard: NSPasteboard) {
        guard let text = pasteboard.string(forType: .string) else { return }
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        let entryID = UUID()
        let rtfFileName = savePasteboardData(
            pasteboard.data(forType: .rtf),
            id: entryID,
            suffix: "rtf"
        )
        let htmlFileName = savePasteboardData(
            pasteboard.data(forType: .html),
            id: entryID,
            suffix: "html"
        )

        entries.removeAll { $0.kind == .text && $0.text == cleanText }
        entries.insert(
            ClipboardEntry(
                id: entryID,
                kind: .text,
                text: cleanText,
                imageFileName: nil,
                rtfFileName: rtfFileName,
                htmlFileName: htmlFileName,
                createdAt: Date()
            ),
            at: 0
        )
        trim()
    }

    func add(_ image: NSImage) {
        guard let pngData = image.pngData() else { return }

        let imageID = UUID()
        let fileName = "\(imageID.uuidString).png"
        let fileURL = imagesDirectoryURL.appendingPathComponent(fileName)
        guard (try? pngData.write(to: fileURL, options: .atomic)) != nil else { return }

        entries.insert(
            ClipboardEntry(
                id: imageID,
                kind: .image,
                text: nil,
                imageFileName: fileName,
                rtfFileName: nil,
                htmlFileName: nil,
                createdAt: Date()
            ),
            at: 0
        )
        trim()
    }

    func remove(_ entry: ClipboardEntry) {
        entries.removeAll { $0.id == entry.id }
        deleteStoredFilesIfNeeded(for: entry)
        save()
    }

    func clear() {
        for entry in entries {
            deleteStoredFilesIfNeeded(for: entry)
        }
        entries.removeAll()
        save()
    }

    func image(for entry: ClipboardEntry) -> NSImage? {
        guard let imageFileName = entry.imageFileName else { return nil }
        return NSImage(contentsOf: imagesDirectoryURL.appendingPathComponent(imageFileName))
    }

    func imageDetails(for entry: ClipboardEntry) -> String? {
        guard let imageFileName = entry.imageFileName else { return nil }

        let fileURL = imagesDirectoryURL.appendingPathComponent(imageFileName)
        let format = fileURL.pathExtension.uppercased()
        let sizeText: String

        if let byteCount = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
            sizeText = ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
        } else {
            sizeText = "-"
        }

        return "\(format) · \(sizeText)"
    }

    func data(for entry: ClipboardEntry, type: NSPasteboard.PasteboardType) -> Data? {
        let fileName: String?
        switch type {
        case .rtf:
            fileName = entry.rtfFileName
        case .html:
            fileName = entry.htmlFileName
        default:
            fileName = nil
        }

        guard let fileName else { return nil }
        return try? Data(contentsOf: richTextDirectoryURL.appendingPathComponent(fileName))
    }

    private func trim() {
        if entries.count > maxItems {
            let removedEntries = entries.dropFirst(maxItems)
            for entry in removedEntries {
                deleteStoredFilesIfNeeded(for: entry)
            }
            entries = Array(entries.prefix(maxItems))
        }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        entries = (try? JSONDecoder().decode([ClipboardEntry].self, from: data)) ?? []
        trim()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func savePasteboardData(_ data: Data?, id: UUID, suffix: String) -> String? {
        guard let data, !data.isEmpty else { return nil }

        let fileName = "\(id.uuidString).\(suffix)"
        let fileURL = richTextDirectoryURL.appendingPathComponent(fileName)
        guard (try? data.write(to: fileURL, options: .atomic)) != nil else { return nil }
        return fileName
    }

    private func deleteStoredFilesIfNeeded(for entry: ClipboardEntry) {
        if let imageFileName = entry.imageFileName {
            try? FileManager.default.removeItem(at: imagesDirectoryURL.appendingPathComponent(imageFileName))
        }

        for fileName in [entry.rtfFileName, entry.htmlFileName].compactMap({ $0 }) {
            try? FileManager.default.removeItem(at: richTextDirectoryURL.appendingPathComponent(fileName))
        }
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}

@MainActor
final class ClipboardMonitor {
    private let pasteboard = NSPasteboard.general
    private let history: ClipboardHistory
    private var lastChangeCount: Int
    private var timer: Timer?
    var isPaused = false

    init(history: ClipboardHistory) {
        self.history = history
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPasteboard()
            }
        }
    }

    private func checkPasteboard() {
        guard !isPaused else { return }
        guard pasteboard.changeCount != lastChangeCount else { return }

        lastChangeCount = pasteboard.changeCount
        if let image = NSImage(pasteboard: pasteboard) {
            history.add(image)
        } else if pasteboard.string(forType: .string) != nil {
            history.addText(from: pasteboard)
        }
    }
}

@MainActor
final class ClipboardWriter {
    static func copy(_ entry: ClipboardEntry, history: ClipboardHistory) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if let text = entry.text {
            pasteboard.setString(text, forType: .string)
        }

        if let rtfData = history.data(for: entry, type: .rtf) {
            pasteboard.setData(rtfData, forType: .rtf)
        }

        if let htmlData = history.data(for: entry, type: .html) {
            pasteboard.setData(htmlData, forType: .html)
        }
    }

    static func copy(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }
}

@MainActor
final class AutoPasteController {
    private var targetProcessIdentifier: pid_t?

    func rememberCurrentApplication() {
        let currentApplication = NSWorkspace.shared.frontmostApplication
        guard currentApplication?.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        targetProcessIdentifier = currentApplication?.processIdentifier
    }

    func pasteIntoRememberedApplication() {
        let options = ["AXTrustedCheckOptionPrompt": true]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            return
        }

        closeHistoryWindowAndPaste()
    }

    private func closeHistoryWindowAndPaste() {
        if let targetProcessIdentifier,
           let application = NSRunningApplication(processIdentifier: targetProcessIdentifier) {
            application.activate(options: [.activateAllWindows])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.sendPasteShortcut()
        }
    }

    private func sendPasteShortcut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let commandDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_Command),
            keyDown: true
        )
        let vDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: true
        )
        let vUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_ANSI_V),
            keyDown: false
        )
        let commandUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(kVK_Command),
            keyDown: false
        )

        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        commandDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        commandUp?.post(tap: .cghidEventTap)
    }
}

struct HistoryView: View {
    @ObservedObject var history: ClipboardHistory
    @ObservedObject var localizer: AppLocalizer
    let onPick: (ClipboardEntry) -> Void
    let onClose: () -> Void

    @State private var query = ""

    private var filteredEntries: [ClipboardEntry] {
        guard !query.isEmpty else { return history.entries }
        return history.entries.filter {
            if $0.text?.localizedCaseInsensitiveContains(query) == true {
                return true
            }
            return $0.kind == .image && ["image", "图片", "图像"].contains {
                $0.localizedCaseInsensitiveContains(query) || query.localizedCaseInsensitiveContains($0)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(.secondary)
                TextField(localizer.text(.searchClipboard), text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(12)

            Divider()

            if filteredEntries.isEmpty {
                ContentUnavailableView(localizer.text(.noClipboardHistory), systemImage: "clipboard")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            Color.clear
                                .frame(height: 0)
                                .id("history-top")

                            ForEach(filteredEntries) { entry in
                                Button {
                                    onPick(entry)
                                } label: {
                                    ClipboardRow(
                                        entry: entry,
                                        image: history.image(for: entry),
                                        imageDetails: history.imageDetails(for: entry),
                                        localizer: localizer
                                    )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(localizer.text(.delete)) {
                                        history.remove(entry)
                                    }
                                }

                                Divider()
                                    .padding(.leading, entry.kind == .image ? 92 : 0)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                    .onAppear {
                        scrollToTop(proxy)
                    }
                    .onChange(of: filteredEntries.first?.id) {
                        scrollToTop(proxy)
                    }
                }
            }
        }
        .frame(width: 520, height: 460)
    }

    private func scrollToTop(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo("history-top", anchor: .top)
        }
    }
}

struct ClipboardRow: View {
    let entry: ClipboardEntry
    let image: NSImage?
    let imageDetails: String?
    @ObservedObject var localizer: AppLocalizer

    var body: some View {
        HStack(spacing: 12) {
            if entry.kind == .image {
                thumbnail
            }

            VStack(alignment: .leading, spacing: 6) {
                if entry.kind == .text {
                    Text(entry.text ?? "")
                        .font(.system(size: 14))
                        .lineLimit(3)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(localizer.text(.image))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    if let image {
                        Text(imageMetadataText(for: image))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(entry.createdAt, style: .relative)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func imageMetadataText(for image: NSImage) -> String {
        let dimensions = "\(Int(image.size.width)) x \(Int(image.size.height))"
        guard let imageDetails else { return dimensions }
        return "\(imageDetails) · \(dimensions)"
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
        } else {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.12))
                .frame(width: 72, height: 54)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var preferences: AppPreferences
    @ObservedObject var localizer: AppLocalizer
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localizer.text(.settings))
                        .font(.system(size: 24, weight: .semibold))
                    Text(appName)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Picker(localizer.text(.language), selection: $localizer.language) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.menuTitle).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Toggle(localizer.text(.showInMenuBar), isOn: $preferences.showMenuBarIcon)
                    .toggleStyle(.switch)

                Text(localizer.text(.menuBarIconDescription))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack {
                Spacer()
                Button(localizer.text(.done), action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 430, height: 260)
    }
}

@MainActor
final class SettingsWindowController {
    private let preferences: AppPreferences
    private let localizer: AppLocalizer
    private var window: NSWindow?

    init(preferences: AppPreferences, localizer: AppLocalizer) {
        self.preferences = preferences
        self.localizer = localizer
    }

    func show() {
        if window == nil {
            let view = SettingsView(
                preferences: preferences,
                localizer: localizer,
                onClose: { [weak self] in
                    self?.close()
                }
            )

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 430, height: 260),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = localizer.text(.settings)
            window.contentViewController = NSHostingController(rootView: view)
            window.isReleasedWhenClosed = false
            self.window = window
        }

        guard let window else { return }
        window.title = localizer.text(.settings)
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.orderOut(nil)
    }
}

@MainActor
final class HistoryWindowController {
    private let history: ClipboardHistory
    private let autoPasteController: AutoPasteController
    private let localizer: AppLocalizer
    private var panel: NSPanel?

    init(
        history: ClipboardHistory,
        autoPasteController: AutoPasteController,
        localizer: AppLocalizer
    ) {
        self.history = history
        self.autoPasteController = autoPasteController
        self.localizer = localizer
    }

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil {
            let view = HistoryView(
                history: history,
                localizer: localizer,
                onPick: { [weak self] entry in
                    if entry.kind == .image, let image = self?.history.image(for: entry) {
                        ClipboardWriter.copy(image)
                    } else if let history = self?.history {
                        ClipboardWriter.copy(entry, history: history)
                    }
                    self?.close()
                    self?.autoPasteController.pasteIntoRememberedApplication()
                },
                onClose: { [weak self] in
                    self?.close()
                }
            )

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.title = localizer.text(.windowTitle)
            panel.contentViewController = NSHostingController(rootView: view)
            panel.isReleasedWhenClosed = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            self.panel = panel
        }

        guard let panel else { return }
        panel.title = localizer.text(.windowTitle)
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
    }
}

final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?

    func register() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                guard let event else { return noErr }

                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                if hotKeyID.id == 1 {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .clipKeyHotKeyPressed, object: nil)
                    }
                }

                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        let hotKeyID = EventHotKeyID(signature: fourCharCode("CLPK"), id: 1)
        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { result, character in
            (result << 8) + OSType(character)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let history = ClipboardHistory()
    private let preferences = AppPreferences()
    private let localizer = AppLocalizer()
    private let autoPasteController = AutoPasteController()
    private lazy var monitor = ClipboardMonitor(history: history)
    private lazy var settingsWindowController = SettingsWindowController(
        preferences: preferences,
        localizer: localizer
    )
    private lazy var windowController = HistoryWindowController(
        history: history,
        autoPasteController: autoPasteController,
        localizer: localizer
    )
    private let hotKeyManager = HotKeyManager()
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        bindPreferences()
        applyMenuBarVisibility()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(toggleHistory),
            name: .clipKeyHotKeyPressed,
            object: nil
        )
        monitor.start()
        hotKeyManager.register()

        if !preferences.showMenuBarIcon {
            settingsWindowController.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindowController.show()
        return true
    }

    private func bindPreferences() {
        preferences.$showMenuBarIcon
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.applyMenuBarVisibility()
                }
            }
            .store(in: &cancellables)

        localizer.$language
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.buildMenuBarItem()
                }
            }
            .store(in: &cancellables)
    }

    private func applyMenuBarVisibility() {
        if preferences.showMenuBarIcon {
            buildMenuBarItem()
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func buildMenuBarItem() {
        guard preferences.showMenuBarIcon else { return }

        let item = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = menuBarImage()

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: localizer.text(.showHistory), action: #selector(showHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: localizer.text(.settings), action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(
            title: monitor.isPaused ? localizer.text(.resumeRecording) : localizer.text(.pauseRecording),
            action: #selector(togglePause),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: localizer.text(.openAccessibilityPermission),
            action: #selector(openAccessibilityPermission),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem.separator())

        let limitMenu = NSMenu()
        for limit in [20, 30, 50, 100] {
            let limitItem = NSMenuItem(
                title: "\(limit)",
                action: #selector(setLimit(_:)),
                keyEquivalent: ""
            )
            limitItem.representedObject = limit
            limitItem.state = history.maxItems == limit ? .on : .off
            limitMenu.addItem(limitItem)
        }

        let limitRoot = NSMenuItem(title: localizer.text(.keepLast), action: nil, keyEquivalent: "")
        limitRoot.submenu = limitMenu
        menu.addItem(limitRoot)

        let languageMenu = NSMenu()
        for language in AppLanguage.allCases {
            let languageItem = NSMenuItem(
                title: language.menuTitle,
                action: #selector(setLanguage(_:)),
                keyEquivalent: ""
            )
            languageItem.representedObject = language.rawValue
            languageItem.state = localizer.language == language ? .on : .off
            languageMenu.addItem(languageItem)
        }

        let languageRoot = NSMenuItem(title: localizer.text(.language), action: nil, keyEquivalent: "")
        languageRoot.submenu = languageMenu
        menu.addItem(languageRoot)
        menu.addItem(NSMenuItem(title: localizer.text(.clearHistory), action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: localizer.text(.quit), action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    private func menuBarImage() -> NSImage? {
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = false
            image.size = NSSize(width: 18, height: 18)
            return image
        }

        return NSImage(systemSymbolName: "clipboard", accessibilityDescription: appName)
    }

    @objc private func showHistory() {
        autoPasteController.rememberCurrentApplication()
        windowController.show()
    }

    @objc private func toggleHistory() {
        autoPasteController.rememberCurrentApplication()
        windowController.toggle()
    }

    @objc private func showSettings() {
        settingsWindowController.show()
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        monitor.isPaused.toggle()
        buildMenuBarItem()
    }

    @objc private func setLimit(_ sender: NSMenuItem) {
        guard let limit = sender.representedObject as? Int else { return }
        history.maxItems = limit

        if let menu = sender.menu {
            for item in menu.items {
                item.state = (item.representedObject as? Int) == limit ? .on : .off
            }
        }
    }

    @objc private func clearHistory() {
        history.clear()
    }

    @objc private func setLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = AppLanguage(rawValue: rawValue) else { return }

        localizer.language = language
        buildMenuBarItem()
    }

    @objc private func openAccessibilityPermission() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
