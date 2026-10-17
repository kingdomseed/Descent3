// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

@main
@MainActor
enum RevivalEditorApplication {
    static func main() {
        let application = NSApplication.shared
        let delegate = RevivalEditorApplicationDelegate()

        application.delegate = delegate
        application.setActivationPolicy(.regular)

        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

@MainActor
private final class RevivalEditorApplicationDelegate: NSObject, NSApplicationDelegate {
    private let library = CanonicalPackageLibrary.revivalEditor
    private var didFinishLaunching = false
    private var queuedURLs: [URL] = []
    private var canonicalPackageRequests = CanonicalPackageRequestQueue<URL>()
    private var libraryPreparationError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMenu()
        do {
            try library.prepareForUse()
        } catch {
            libraryPreparationError = error.localizedDescription
            showError(
                title: "Could Not Prepare Revival Content",
                message: error.localizedDescription
            )
        }
        didFinishLaunching = true

        let urls = queuedURLs
        queuedURLs.removeAll()
        for url in urls {
            openPackage(url)
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard didFinishLaunching else {
            queuedURLs.append(contentsOf: urls)
            return
        }
        for url in urls {
            openPackage(url)
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }

    @objc private func chooseImportedContent(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "New Project from Imported Content"
        panel.message = "Choose a canonical package produced by D3Import."
        panel.prompt = "Create Project"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        createProject(from: url)
    }

    private func openPackage(_ url: URL) {
        if revivalEditorOpenKind(for: url) == .project {
            NSDocumentController.shared.openDocument(
                withContentsOf: url,
                display: true
            ) { [weak self] _, _, error in
                if let error {
                    self?.showError(
                        title: "Could Not Open Revival Project",
                        message: error.localizedDescription
                    )
                }
            }
        } else {
            createProject(from: url)
        }
    }

    private func createProject(from canonicalPackageURL: URL) {
        guard libraryPreparationError == nil else {
            showError(
                title: "Could Not Create Revival Project",
                message: "New installs are blocked until abandoned staging is recovered. Relaunch RevivalEditor to retry preparation."
            )
            return
        }
        canonicalPackageRequests.append(canonicalPackageURL)
        processNextCanonicalPackage()
    }

    private func processNextCanonicalPackage() {
        guard let canonicalPackageURL = canonicalPackageRequests.startNextIfIdle() else {
            return
        }
        Task { @MainActor in
            defer {
                self.canonicalPackageRequests.finishCurrent()
                self.processNextCanonicalPackage()
            }
            do {
                let library = self.library
                let candidateURL = canonicalPackageURL
                let activation = try await Task.detached(priority: .userInitiated) {
                    do {
                        return try library.installAndActivate(from: candidateURL)
                    } catch CanonicalPackageError.duplicatePackageIdentity(_) {
                        return try library.loadInstalledPackage(matching: candidateURL)
                    }
                }.value
                let project = try RevivalProject(activatedBase: activation)
                let document = RevivalProjectDocument(
                    project: project,
                    library: library
                )
                NSDocumentController.shared.addDocument(document)
                document.makeWindowControllers()
                document.updateChangeCount(.changeDone)
                document.showWindows()
                NSApplication.shared.activate(ignoringOtherApps: true)
            } catch {
                showError(
                    title: "Could Not Create Revival Project",
                    message: "\(canonicalPackageURL.lastPathComponent): \(error.localizedDescription)"
                )
            }
        }
    }

    private func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private func installMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit RevivalEditor",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let newProject = fileMenu.addItem(
            withTitle: "New Project from Imported Content…",
            action: #selector(chooseImportedContent(_:)),
            keyEquivalent: "n"
        )
        newProject.target = self
        fileMenu.addItem(
            withTitle: "Open Project…",
            action: #selector(NSDocumentController.openDocument(_:)),
            keyEquivalent: "o"
        )
        fileMenu.addItem(.separator())
        fileMenu.addItem(
            withTitle: "Close",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        fileMenu.addItem(
            withTitle: "Save",
            action: #selector(NSDocument.save(_:)),
            keyEquivalent: "s"
        )
        let saveAs = fileMenu.addItem(
            withTitle: "Save As…",
            action: #selector(NSDocument.saveAs(_:)),
            keyEquivalent: "S"
        )
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(
            withTitle: "Undo",
            action: Selector(("undo:")),
            keyEquivalent: "z"
        )
        let redo = editMenu.addItem(
            withTitle: "Redo",
            action: Selector(("redo:")),
            keyEquivalent: "Z"
        )
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(
            withTitle: "Cut",
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        editMenu.addItem(
            withTitle: "Copy",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        editMenu.addItem(
            withTitle: "Paste",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        editMenu.addItem(
            withTitle: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApplication.shared.mainMenu = mainMenu
    }
}
