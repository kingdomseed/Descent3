import AppKit
import XCTest

final class TrainingQuicksaveTests: XCTestCase {
    func testTrainingQuicksaveRoundTripRestoresSchema7StateAndContinuesDeterministically()
        throws
    {
        let root = try makeTemporarySaveRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let profileID = UUID()
        let package = makePackageReference()
        let level = makeTrainingRASBot1DeathLevel()
        try level.validate()
        let original = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        _ = original.update(
            at: 0.1,
            input: .init(deploysTrainingGuidebot: true)
        )
        let saved = original.continuation
        let saveFile = PlayerSaveFile(rootURL: root)

        try saveFile.save(
            profileID: profileID,
            package: package,
            continuation: saved
        )
        let encoded = try Data(contentsOf: saveFile.quicksaveURL(
            profileID: profileID
        ))
        let envelope = try JSONDecoder().decode(
            PlayerSaveEnvelope.self,
            from: encoded
        )
        XCTAssertEqual(envelope.schemaVersion, 1)
        XCTAssertEqual(envelope.profileID, profileID)
        XCTAssertEqual(envelope.package, package)
        XCTAssertEqual(envelope.continuation, saved)
        XCTAssertEqual(saved.schemaVersion, 7)
        XCTAssertNotNil(saved.authoritativeRandomState)
        XCTAssertNotEqual(saved.authoritativeRandomState, 0x1234_5678)

        let restored = try saveFile.load(
            profileID: profileID,
            package: package,
            baseLevel: level,
            resumedAtTimestamp: 100
        )
        XCTAssertEqual(restored.continuation, saved)
        XCTAssertEqual(
            restored.continuation.authoritativeRandomState,
            saved.authoritativeRandomState
        )
        let originalNext = original.update(at: 0.2, input: .zero)
        let restoredNext = restored.update(at: 100.1, input: .zero)
        XCTAssertEqual(originalNext, restoredNext)
        XCTAssertEqual(original.continuation, restored.continuation)
    }

    func testTrainingQuicksaveRejectsHostileFilesAndWrongIdentity() throws {
        let root = try makeTemporarySaveRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let profileID = UUID()
        let package = makePackageReference()
        let level = makeTrainingRASBot1DeathLevel()
        try level.validate()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        let saveFile = PlayerSaveFile(rootURL: root)
        try saveFile.save(
            profileID: profileID,
            package: package,
            continuation: simulation.continuation
        )
        let saveURL = saveFile.quicksaveURL(profileID: profileID)
        let validData = try Data(contentsOf: saveURL)

        try Data("{".utf8).write(to: saveURL)
        assertLoadError(
            .malformedSave,
            saveFile: saveFile,
            profileID: profileID,
            package: package,
            level: level
        )

        try Data(count: 8 * 1_024 * 1_024 + 1).write(to: saveURL)
        assertLoadError(
            .tooLarge,
            saveFile: saveFile,
            profileID: profileID,
            package: package,
            level: level
        )

        try writeMutatedJSON(validData, to: saveURL) {
            $0["schemaVersion"] = 2
        }
        assertLoadError(
            .unsupportedSaveSchema(2),
            saveFile: saveFile,
            profileID: profileID,
            package: package,
            level: level
        )

        let otherProfileID = UUID()
        try writeMutatedJSON(validData, to: saveURL) {
            $0["profileID"] = otherProfileID.uuidString
        }
        assertLoadError(
            .profileMismatch,
            saveFile: saveFile,
            profileID: profileID,
            package: package,
            level: level
        )

        try writeMutatedJSON(validData, to: saveURL) {
            var hostilePackage = $0["package"] as! [String: Any]
            hostilePackage["identitySHA256"] = String(repeating: "b", count: 64)
            $0["package"] = hostilePackage
        }
        assertLoadError(
            .packageMismatch,
            saveFile: saveFile,
            profileID: profileID,
            package: package,
            level: level
        )

        try FileManager.default.removeItem(at: saveURL)
        try FileManager.default.createDirectory(
            at: saveURL,
            withIntermediateDirectories: false
        )
        assertLoadError(
            .nonRegularFile,
            saveFile: saveFile,
            profileID: profileID,
            package: package,
            level: level
        )

        try FileManager.default.removeItem(at: saveURL)
        let targetURL = root.appending(path: "hostile-target.json")
        try validData.write(to: targetURL)
        try FileManager.default.createSymbolicLink(
            at: saveURL,
            withDestinationURL: targetURL
        )
        assertLoadError(
            .nonRegularFile,
            saveFile: saveFile,
            profileID: profileID,
            package: package,
            level: level
        )
    }

    func testTrainingQuicksaveFailedOverwritePreservesPriorValidSave() throws {
        let root = try makeTemporarySaveRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let profileID = UUID()
        let package = makePackageReference()
        let level = makeTrainingRASBot1DeathLevel()
        let simulation = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(at: 0.1, input: .zero)
        let first = simulation.continuation
        let saveFile = PlayerSaveFile(rootURL: root)
        try saveFile.save(
            profileID: profileID,
            package: package,
            continuation: first
        )
        let saveURL = saveFile.quicksaveURL(profileID: profileID)
        let originalData = try Data(contentsOf: saveURL)
        _ = simulation.update(at: 0.2, input: .zero)
        let replacement = simulation.continuation
        XCTAssertNotEqual(replacement, first)

        let profileURL = saveURL.deletingLastPathComponent()
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: profileURL.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: profileURL.path
            )
        }
        XCTAssertThrowsError(try saveFile.save(
            profileID: profileID,
            package: package,
            continuation: replacement
        )) {
            guard let error = $0 as? PlayerSaveError,
                  case .writeFailed = error else {
                return XCTFail("unexpected error: \($0)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: saveURL), originalData)
        let restored = try saveFile.load(
            profileID: profileID,
            package: package,
            baseLevel: level,
            resumedAtTimestamp: 10
        )
        XCTAssertEqual(restored.continuation, first)
    }

    func testTrainingQuickloadFailurePreservesTheLiveSimulation() throws {
        let root = try makeTemporarySaveRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let profileID = UUID()
        let package = makePackageReference()
        let level = makeTrainingRASBot1DeathLevel()
        let original = PlayerSimulation(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = original.update(at: 0.1, input: .zero)
        let liveContinuation = original.continuation
        var live = original
        let saveFile = PlayerSaveFile(rootURL: root)
        try saveFile.save(
            profileID: profileID,
            package: package,
            continuation: liveContinuation
        )
        let saveURL = saveFile.quicksaveURL(profileID: profileID)
        let validData = try Data(contentsOf: saveURL)
        try writeMutatedJSON(validData, to: saveURL) {
            var continuation = $0["continuation"] as! [String: Any]
            continuation["levelSHA256"] = String(repeating: "f", count: 64)
            $0["continuation"] = continuation
        }

        do {
            let candidate = try saveFile.load(
                profileID: profileID,
                package: package,
                baseLevel: level,
                resumedAtTimestamp: 10
            )
            live = candidate
            XCTFail("hostile continuation loaded")
        } catch {
            XCTAssertEqual(error as? PlayerSaveError, .invalidContinuation)
        }
        XCTAssertTrue(live === original)
        XCTAssertEqual(live.continuation, liveContinuation)
    }

    @MainActor
    func testPhysicalEntriesAreNonrepeatAndEditorPlayReportsUnavailable()
        throws
    {
        XCTAssertEqual(requestedSaveAction(keyCode: 101), .quicksave)
        XCTAssertEqual(
            requestedSaveAction(keyCode: 101, modifiers: [.function]),
            .quicksave
        )
        XCTAssertEqual(
            requestedSaveAction(keyCode: 99, modifiers: [.option, .function]),
            .quickload
        )
        XCTAssertNil(requestedSaveAction(keyCode: 99))
        XCTAssertNil(requestedSaveAction(keyCode: 101, modifiers: [.option]))
        XCTAssertNil(requestedSaveAction(keyCode: 101, isRepeat: true))
        XCTAssertNil(requestedSaveAction(keyCode: 101, gameplayIsActive: false))

        _ = NSApplication.shared
        let view = RevivalGameplayView(frame: .zero, device: nil)
        var pauseChanges: [Bool] = []
        view.soloPauseChanged = { pauseChanges.append($0) }
        view.setGameplayActive(true)
        let events = [
            try makeKeyEvent(keyCode: 101, modifiers: [.function]),
            try makeKeyEvent(keyCode: 99, modifiers: [.option, .function]),
        ]
        for event in events {
            var inspectedModal = false
            DispatchQueue.main.async {
                guard let modalWindow = NSApplication.shared.modalWindow else {
                    return XCTFail("save key did not present the unavailable alert")
                }
                inspectedModal = true
                let descendants = Self.descendants(of: modalWindow.contentView)
                let text = descendants.compactMap {
                    ($0 as? NSTextField)?.stringValue
                }
                XCTAssertTrue(text.contains("Save Unavailable"))
                XCTAssertTrue(text.contains(
                    "Save and load are unavailable in disposable editor play."
                ))
                descendants.compactMap { $0 as? NSButton }.only?
                    .performClick(nil)
            }
            view.keyDown(with: event)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            XCTAssertTrue(inspectedModal)
            XCTAssertNil(NSApplication.shared.modalWindow)
        }
        XCTAssertEqual(pauseChanges, [true, false, true, false])
    }

    private func makeTemporarySaveRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "revival-quicksave-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        return root
    }

    private func makePackageReference() -> CanonicalPackageReference {
        CanonicalPackageReference(
            identitySHA256: String(repeating: "a", count: 64),
            missionKey: "descent3.mission.pilot-training",
            levelKey: "descent3.level.training-mission"
        )
    }

    private func assertLoadError(
        _ expected: PlayerSaveError,
        saveFile: PlayerSaveFile,
        profileID: UUID,
        package: CanonicalPackageReference,
        level: Level,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try saveFile.load(
            profileID: profileID,
            package: package,
            baseLevel: level,
            resumedAtTimestamp: 10
        ), file: file, line: line) {
            XCTAssertEqual(
                $0 as? PlayerSaveError,
                expected,
                file: file,
                line: line
            )
        }
    }

    private func writeMutatedJSON(
        _ data: Data,
        to url: URL,
        mutate: (inout [String: Any]) -> Void
    ) throws {
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        mutate(&object)
        try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        ).write(to: url)
    }

    private func requestedSaveAction(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = [],
        isRepeat: Bool = false,
        gameplayIsActive: Bool = true
    ) -> TrainingPlayerSaveAction? {
        RevivalGameplayView.requestedTrainingPlayerSaveAction(
            keyCode: keyCode,
            modifierFlags: modifiers,
            isRepeat: isRepeat,
            gameplayIsActive: gameplayIsActive
        )
    }

    @MainActor
    private func makeKeyEvent(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "",
            charactersIgnoringModifiers: "",
            isARepeat: false,
            keyCode: keyCode
        ))
    }

    @MainActor
    private static func descendants(of view: NSView?) -> [NSView] {
        guard let view else { return [] }
        return view.subviews + view.subviews.flatMap { descendants(of: $0) }
    }
}
