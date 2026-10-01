import XCTest

// Pilot profiles and mission progress (PilotProfile.swift; pilot.cpp
// PltWriteFile and the mission data, :1463): selection, persistence,
// completion keyed by mission key, and the record boundary.

final class PilotProfileTests: XCTestCase {
    func testPilotProfilesRequireConfirmedSelectionAndSurviveReload() throws {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-pilot-lifecycle-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let library = PilotProfileLibrary(rootURL: rootURL)

        XCTAssertTrue(try library.load().profiles.isEmpty)

        let createdAlice = try library.createProfile(named: "Alice")
        let alice = try XCTUnwrap(createdAlice.profiles.first)
        XCTAssertEqual(alice.name, "Alice")
        XCTAssertNil(createdAlice.defaultProfileID)

        let createdBob = try library.createProfile(named: "Bob")
        let bob = try XCTUnwrap(
            createdBob.profiles.first { $0.name == "Bob" }
        )
        XCTAssertNil(createdBob.defaultProfileID)

        let confirmedBob = try library.confirmProfile(bob.id)
        XCTAssertEqual(confirmedBob.defaultProfileID, bob.id)
        XCTAssertEqual(try library.load().defaultProfileID, bob.id)

        _ = alice.id
        XCTAssertEqual(
            try library.load().defaultProfileID, bob.id,
            "Tentative browsing followed by Cancel must not change the default"
        )
    }

    func testSuccessfulTrainingCompletionPersistsBeforeAcknowledgement()
        throws
    {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-training-progress-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let library = PilotProfileLibrary(rootURL: rootURL)
        let created = try library.createProfile(named: "Alice")
        let profileID = try XCTUnwrap(created.profiles.first?.id)
        _ = try library.confirmProfile(profileID)

        let (simulation, completionFrame) = try trainingLevelEndFrame()
        XCTAssertEqual(completionFrame.levelEnd?.endLevelState, .succeeded)
        XCTAssertEqual(simulation.levelOutcome, .awaitingResultAcknowledgement)

        let package = CanonicalPackageReference(
            identitySHA256: String(repeating: "a", count: 64),
            missionKey: "descent3.mission.pilot-training",
            levelKey: "descent3.level.training-mission"
        )
        let completed = try library.recordMissionCompletion(
            profileID: profileID, package: package,
            missionName: "Pilot Training"
        )
        let progress = try XCTUnwrap(
            completed.profiles.first?.missionProgress.first
        )
        XCTAssertEqual(progress.missionName, "Pilot Training")
        XCTAssertEqual(progress.package, package)
        XCTAssertEqual(progress.highestLevel, 0)
        XCTAssertTrue(progress.finished)
        XCTAssertEqual(progress.restoreCount, 0)
        XCTAssertEqual(progress.saveCount, 0)
        XCTAssertEqual(progress.shipPermissions, 0x01)
        XCTAssertEqual(
            try library.load().profiles.first?.missionProgress, [progress]
        )
        XCTAssertEqual(
            simulation.levelOutcome, .awaitingResultAcknowledgement,
            "Released EndLevel writes mission progress before result acknowledgement"
        )

        XCTAssertEqual(simulation.acknowledgeLevelResult(), .completed)
    }

    /// CurrentPilotUpdateMissionStatus (pilot.cpp:1463): a pilot keeps one
    /// progress record per mission, keyed by the package's mission key.
    func testMissionCompletionIsKeyedByMissionKey() throws {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-mission-progress-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let library = PilotProfileLibrary(rootURL: rootURL)
        let profileID = try XCTUnwrap(
            library.createProfile(named: "Alice").profiles.first?.id
        )
        func package(_ mission: String, _ digit: Character) -> CanonicalPackageReference {
            .init(
                identitySHA256: String(repeating: digit, count: 64),
                missionKey: mission, levelKey: mission + ".level-1"
            )
        }
        _ = try library.recordMissionCompletion(
            profileID: profileID,
            package: package("descent3.mission.first", "a"),
            missionName: "First"
        )
        _ = try library.recordMissionCompletion(
            profileID: profileID,
            package: package("descent3.mission.second", "b"),
            missionName: "Second"
        )
        // A new package of the first mission replaces its record, even when
        // the mission's NAME changed.
        let replaced = try library.recordMissionCompletion(
            profileID: profileID,
            package: package("descent3.mission.first", "c"),
            missionName: "First Renamed"
        )
        let progress = try XCTUnwrap(replaced.profiles.first?.missionProgress)
        XCTAssertEqual(
            progress.map(\.package.missionKey),
            ["descent3.mission.second", "descent3.mission.first"]
        )
        XCTAssertEqual(progress.map(\.missionName), ["Second", "First Renamed"])
        XCTAssertEqual(
            progress.last?.package.identitySHA256,
            String(repeating: "c", count: 64)
        )
        // Two missions with the same NAME keep separate records.
        let sameName = try library.recordMissionCompletion(
            profileID: profileID,
            package: package("descent3.mission.third", "d"),
            missionName: "Second"
        )
        XCTAssertEqual(
            sameName.profiles.first?.missionProgress.map(\.package.missionKey),
            ["descent3.mission.second", "descent3.mission.first",
             "descent3.mission.third"]
        )
        XCTAssertEqual(try library.load(), sameName)
        XCTAssertThrowsError(try library.recordMissionCompletion(
            profileID: profileID,
            package: package("descent3.mission.fourth", "e"), missionName: ""
        ))
    }

    func testPilotProfileBoundaryRejectsMalformedAndUnsupportedRecords()
        throws
    {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-pilot-boundary-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(
            at: rootURL, withIntermediateDirectories: true
        )
        let recordURL = rootURL.appending(path: "profiles.json")
        let library = PilotProfileLibrary(rootURL: rootURL)

        try Data(#"{"schemaVersion":2}"#.utf8).write(to: recordURL)
        XCTAssertThrowsError(try library.load()) {
            XCTAssertEqual(
                $0 as? PilotProfileLibraryError, .unsupportedSchema(2)
            )
        }

        try Data(
            #"{"schemaVersion":1,"defaultProfileID":null,"profiles":"bad"}"#
                .utf8
        ).write(to: recordURL)
        XCTAssertThrowsError(try library.load()) {
            XCTAssertEqual($0 as? PilotProfileLibraryError, .malformedRecord)
        }

        let symlinkContainerURL =
            FileManager.default.temporaryDirectory.appending(
                path: "revival-pilot-root-symlink-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
        defer {
            try? FileManager.default.removeItem(at: symlinkContainerURL)
        }

        let ownedRootURL = symlinkContainerURL.appending(
            path: "owned", directoryHint: .isDirectory
        )
        let linkedRootURL = symlinkContainerURL.appending(
            path: "linked", directoryHint: .isDirectory
        )
        _ = try PilotProfileLibrary(rootURL: ownedRootURL)
            .createProfile(named: "Alice")
        try FileManager.default.createSymbolicLink(
            at: linkedRootURL, withDestinationURL: ownedRootURL
        )
        XCTAssertThrowsError(
            try PilotProfileLibrary(rootURL: linkedRootURL).load()
        ) {
            XCTAssertEqual($0 as? PilotProfileLibraryError, .malformedRecord)
        }
    }

    func testPilotProfileAtomicReplacementPreservesPriorRecordOnWriteFailure()
        throws
    {
        let rootURL = FileManager.default.temporaryDirectory.appending(
            path: "revival-pilot-atomic-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: rootURL.path
            )
            try? FileManager.default.removeItem(at: rootURL)
        }

        let recordURL = rootURL.appending(path: "profiles.json")
        let library = PilotProfileLibrary(rootURL: rootURL)
        let created = try library.createProfile(named: "Alice")
        let profileID = try XCTUnwrap(created.profiles.first?.id)
        _ = try library.confirmProfile(profileID)
        let priorData = try Data(contentsOf: recordURL)
        let priorRecord = try library.load()

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500], ofItemAtPath: rootURL.path
        )
        XCTAssertThrowsError(try library.createProfile(named: "Bob")) {
            guard case .writeFailed = $0 as? PilotProfileLibraryError else {
                return XCTFail("Expected actionable profile write failure")
            }
        }
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700], ofItemAtPath: rootURL.path
        )

        XCTAssertEqual(try Data(contentsOf: recordURL), priorData)
        XCTAssertEqual(try library.load(), priorRecord)

        let replaced = try library.createProfile(named: "Bob")
        XCTAssertEqual(replaced.profiles.map(\.name), ["Alice", "Bob"])
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: rootURL.path),
            ["profiles.json"]
        )
    }
}
