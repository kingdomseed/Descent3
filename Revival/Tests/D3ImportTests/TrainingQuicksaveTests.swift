import AppKit
import XCTest

final class TrainingQuicksaveTests: XCTestCase {
    func testTrainingQuicksaveRoundTripRestoresGameWorldAndContinuesDeterministically()
        throws
    {
        let root = try makeTemporarySaveRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let profileID = UUID()
        let package = makePackageReference()
        let level = withTrainingGuideBot(makeTrainingRASBot1DeathLevel())
        try level.validate()
        let original = GameSession(
            level: level,
            presentationReadyTimestamp: 0,
            authoritativeRandomSeed: 0x1234_5678
        )
        original.releaseOrRecallTestGuideBot()
        _ = original.update(
            at: 0.1,
            input: .zero
        )
        let saved = original.world
        let saveFile = GameSaveFile(rootURL: root)

        try saveFile.save(
            profileID: profileID,
            package: package,
            world: saved,
            level: level
        )
        let encoded = try Data(contentsOf: saveFile.quicksaveURL(
            profileID: profileID
        ))
        let save = try JSONDecoder().decode(GameSave.self, from: encoded)
        XCTAssertEqual(save.schemaVersion, 2)
        XCTAssertEqual(save.profileID, profileID)
        XCTAssertEqual(save.package, package)
        XCTAssertEqual(save.world, saved)
        XCTAssertNotEqual(saved.authoritativeRandomState, 0x1234_5678)

        let restored = try saveFile.load(
            profileID: profileID,
            package: package,
            baseLevel: level,
            resumedAtTimestamp: 100
        )
        XCTAssertEqual(restored.world, saved)
        XCTAssertEqual(
            restored.world.authoritativeRandomState,
            saved.authoritativeRandomState
        )
        let originalNext = original.update(at: 0.2, input: .zero)
        let restoredNext = restored.update(at: 100.1, input: .zero)
        XCTAssertEqual(originalNext, restoredNext)
        XCTAssertEqual(original.world, restored.world)
    }

    func testTrainingQuicksaveRejectsHostileFilesAndWrongIdentity() throws {
        let root = try makeTemporarySaveRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let profileID = UUID()
        let package = makePackageReference()
        let level = makeTrainingRASBot1DeathLevel()
        try level.validate()
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        let saveFile = GameSaveFile(rootURL: root)
        try saveFile.save(
            profileID: profileID,
            package: package,
            world: simulation.world,
            level: level
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
            $0["schemaVersion"] = 1
        }
        assertLoadError(
            .unsupportedSaveSchema(1),
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
        let simulation = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = simulation.update(at: 0.1, input: .zero)
        let first = simulation.world
        let saveFile = GameSaveFile(rootURL: root)
        try saveFile.save(
            profileID: profileID,
            package: package,
            world: first,
            level: level
        )
        let saveURL = saveFile.quicksaveURL(profileID: profileID)
        let originalData = try Data(contentsOf: saveURL)
        _ = simulation.update(at: 0.2, input: .zero)
        let replacement = simulation.world
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
            world: replacement,
            level: level
        )) {
            guard let error = $0 as? GameSaveError,
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
        XCTAssertEqual(restored.world, first)
    }

    func testTrainingQuickloadFailurePreservesTheLiveSimulation() throws {
        let root = try makeTemporarySaveRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let profileID = UUID()
        let package = makePackageReference()
        let level = makeTrainingRASBot1DeathLevel()
        let original = GameSession(
            level: level,
            presentationReadyTimestamp: 0
        )
        _ = original.update(at: 0.1, input: .zero)
        let liveWorld = original.world
        var live = original
        let saveFile = GameSaveFile(rootURL: root)
        try saveFile.save(
            profileID: profileID,
            package: package,
            world: liveWorld,
            level: level
        )
        let saveURL = saveFile.quicksaveURL(profileID: profileID)
        let validData = try Data(contentsOf: saveURL)
        try writeMutatedJSON(validData, to: saveURL) {
            var world = $0["world"] as! [String: Any]
            var objects = world["objects"] as! [String: Any]
            var freeSlots = objects["freeSlots"] as! [Int]
            freeSlots.append(freeSlots[0])
            objects["freeSlots"] = freeSlots
            world["objects"] = objects
            $0["world"] = world
        }

        do {
            let candidate = try saveFile.load(
                profileID: profileID,
                package: package,
                baseLevel: level,
                resumedAtTimestamp: 10
            )
            live = candidate
            XCTFail("hostile world loaded")
        } catch {
            XCTAssertEqual(error as? GameSaveError, .invalidWorld(.freeList))
        }
        XCTAssertTrue(live === original)
        XCTAssertEqual(live.world, liveWorld)
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
        _ expected: GameSaveError,
        saveFile: GameSaveFile,
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
                $0 as? GameSaveError,
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
