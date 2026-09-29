import XCTest

extension CanonicalLevelTests {
    func testScript014RequiresHiddenStartCoursePortalAndIntroVoice()
        throws
    {
        let level = makeTrainingScript003Level()
        let lesson = try XCTUnwrap(
            level.trainingOpeningLesson?.startCourse
        )
        XCTAssertEqual(lesson.startCourseObjectHandle, 6_147)
        XCTAssertGreaterThan(lesson.collisionRadius, 0)
        XCTAssertEqual(lesson.portalRoomSourceIndex, 2)
        XCTAssertEqual(lesson.portalIndex, 1)
        XCTAssertEqual(
            lesson.instruction,
            "Now, manuever through this tunnel using the sliding skills you just learned."
        )
        XCTAssertEqual(lesson.voiceSourceName, "intro1.osf")
        XCTAssertEqual(lesson.enabledControlMask, 63)
        XCTAssertEqual(
            level.objectPresentations.first {
                $0.objectHandle == lesson.startCourseObjectHandle
            }?.isVisible,
            false
        )
        XCTAssertNoThrow(try level.validate())

        var independentHistory = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        independentHistory.continueToCourse = nil
        XCTAssertNoThrow(
            try replacing(
                level,
                trainingOpeningLesson: independentHistory
            ).validate()
        )

        var hostileLesson = try XCTUnwrap(level.trainingOpeningLesson)
        hostileLesson.startCourse = .init(
            startCourseObjectHandle: lesson.startCourseObjectHandle,
            collisionRadius: lesson.collisionRadius,
            portalRoomSourceIndex: lesson.portalRoomSourceIndex,
            portalIndex: lesson.portalIndex,
            instruction: lesson.instruction,
            voiceSourceName: lesson.voiceSourceName,
            enabledControlMask: 62
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 014 start-course lesson"
            ),
            replacing(
                level,
                trainingOpeningLesson: hostileLesson
            )
        )

        var visiblePresentations = level.objectPresentations
        let presentationIndex = try XCTUnwrap(
            visiblePresentations.firstIndex {
                $0.objectHandle == lesson.startCourseObjectHandle
            }
        )
        let presentation = visiblePresentations[presentationIndex]
        visiblePresentations[presentationIndex] = .init(
            objectHandle: presentation.objectHandle,
            primaryModel: presentation.primaryModel,
            mediumModel: presentation.mediumModel,
            lowModel: presentation.lowModel,
            dyingModel: presentation.dyingModel,
            mediumDistance: presentation.mediumDistance,
            lowDistance: presentation.lowDistance,
            isVisible: true
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 014 start-course lesson"
            ),
            replacing(
                level,
                objectPresentations: visiblePresentations
            )
        )

        let portalRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == lesson.portalRoomSourceIndex
            }
        )
        let portal =
            level.rooms[portalRoomIndex].portals[lesson.portalIndex]
        let connectedRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == portal.connectedRoom
            }
        )
        var hostileRooms = level.rooms
        let reciprocal =
            hostileRooms[connectedRoomIndex]
                .portals[portal.connectedPortal]
        hostileRooms[connectedRoomIndex]
            .portals[portal.connectedPortal] = .init(
                flags: reciprocal.flags,
                faceIndex: reciprocal.faceIndex,
                connectedRoom: reciprocal.connectedRoom,
                connectedPortal: 0
            )
        assertValidationError(
            .nonreciprocalPortal(room: 2, portal: 1),
            replacing(level, rooms: hostileRooms)
        )

        assertValidationError(
            .invalidDependency(
                "Training Script 014 start-course lesson"
            ),
            replacing(
                level,
                voiceClips: level.voiceClips.filter {
                    $0.sourceName != lesson.voiceSourceName
                }
            )
        )
    }

    func testOwnedScript014PackageAdmissionRejectsHostileStockMutations()
        throws
    {
        let fallbackPath =
            "/tmp/revival-script014-final-import/training.revival/levels/descent3.level.training-mission/level.json"
        let path = ProcessInfo.processInfo.environment[
            "REVIVAL_SCRIPT014_OWNED_LEVEL"
        ] ?? fallbackPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip(
                "requires the ignored exact-final owned Script 014 import"
            )
        }
        let stockLevel = try JSONDecoder().decode(
            Level.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        XCTAssertNoThrow(try stockLevel.validate())

        let lesson = try XCTUnwrap(stockLevel.trainingOpeningLesson)
        let startCourse = try XCTUnwrap(lesson.startCourse)
        var hostileLesson = lesson
        hostileLesson.startCourse = .init(
            startCourseObjectHandle:
                startCourse.startCourseObjectHandle,
            collisionRadius: startCourse.collisionRadius,
            portalRoomSourceIndex:
                startCourse.portalRoomSourceIndex,
            portalIndex: startCourse.portalIndex,
            instruction: "\(startCourse.instruction) ",
            voiceSourceName: startCourse.voiceSourceName,
            enabledControlMask: startCourse.enabledControlMask
        )
        assertValidationError(
            .invalidDependency("Training Script 014 package"),
            replacing(
                stockLevel,
                trainingOpeningLesson: hostileLesson
            )
        )

        var hostileObjects = stockLevel.objects
        let objectIndex = try XCTUnwrap(
            hostileObjects.firstIndex {
                $0.handle == startCourse.startCourseObjectHandle
            }
        )
        let stockPosition = hostileObjects[objectIndex].position
        hostileObjects[objectIndex].position = .init(
            x: stockPosition.x + 1,
            y: stockPosition.y,
            z: stockPosition.z
        )
        assertValidationError(
            .invalidDependency("Training Script 014 package"),
            replacing(stockLevel, objects: hostileObjects)
        )

        let portalRoomIndex = try XCTUnwrap(
            stockLevel.rooms.firstIndex {
                $0.sourceIndex == startCourse.portalRoomSourceIndex
            }
        )
        var hostileRooms = stockLevel.rooms
        hostileRooms[portalRoomIndex]
            .portals[startCourse.portalIndex].flags &= ~UInt32(1)
        assertValidationError(
            .invalidDependency("Training Script 013 package"),
            replacing(
                stockLevel,
                rooms: hostileRooms,
                surfacePhysics: stockLevel.surfacePhysics
            )
        )

        let voiceIndex = try XCTUnwrap(
            stockLevel.voiceClips.firstIndex {
                $0.sourceName == startCourse.voiceSourceName
            }
        )
        let intro1 = stockLevel.voiceClips[voiceIndex]
        var hostileVoices = stockLevel.voiceClips
        hostileVoices[voiceIndex] = .init(
            sourceName: intro1.sourceName,
            sourceEntryIndex: intro1.sourceEntryIndex,
            sampleRate: intro1.sampleRate,
            channelCount: intro1.channelCount,
            frameCount: intro1.frameCount,
            pcm16LittleEndian: intro1.pcm16LittleEndian,
            pcmSHA256: intro1.pcmSHA256,
            sourceArchive: intro1.sourceArchive,
            sourceSHA256: String(repeating: "0", count: 64)
        )
        assertValidationError(
            .invalidDependency("Training Script 014 package"),
            replacing(stockLevel, voiceClips: hostileVoices)
        )
    }

    func testScript013RequiresExactStartGoalPortalTopologyAndProceedVoice()
        throws
    {
        let level = makeTrainingScript003Level()
        let lesson = try XCTUnwrap(
            level.trainingOpeningLesson?.continueToCourse
        )
        XCTAssertEqual(lesson.startGoalObjectHandle, 12_300)
        XCTAssertEqual(lesson.portalRoomSourceIndex, 2)
        XCTAssertEqual(lesson.orderedPortalIndices, [0, 1])
        XCTAssertEqual(
            lesson.instruction,
            "Continue Sliding down to start the next step."
        )
        XCTAssertEqual(lesson.voiceSourceName, "proceed1.osf")
        XCTAssertNoThrow(try level.validate())

        var missingPredecessor = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        missingPredecessor.repeatReturnDown = nil
        assertValidationError(
            .invalidDependency(
                "Training Script 013 continue-to-course lesson"
            ),
            replacing(level, trainingOpeningLesson: missingPredecessor)
        )

        var hostileLesson = try XCTUnwrap(level.trainingOpeningLesson)
        hostileLesson.continueToCourse = .init(
            startGoalObjectHandle: lesson.startGoalObjectHandle,
            collisionRadius: lesson.collisionRadius,
            portalRoomSourceIndex: lesson.portalRoomSourceIndex,
            orderedPortalIndices: [1, 0],
            instruction: lesson.instruction,
            voiceSourceName: lesson.voiceSourceName
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 013 continue-to-course lesson"
            ),
            replacing(level, trainingOpeningLesson: hostileLesson)
        )

        let portalRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == lesson.portalRoomSourceIndex
            }
        )
        let portal = level.rooms[portalRoomIndex].portals[0]
        let reciprocalRoomIndex = try XCTUnwrap(
            level.rooms.firstIndex {
                $0.sourceIndex == portal.connectedRoom
            }
        )
        var hostileRooms = level.rooms
        let reciprocal =
            hostileRooms[reciprocalRoomIndex]
                .portals[portal.connectedPortal]
        hostileRooms[reciprocalRoomIndex]
            .portals[portal.connectedPortal] = .init(
                flags: reciprocal.flags,
                faceIndex: reciprocal.faceIndex,
                connectedRoom: reciprocal.connectedRoom,
                connectedPortal: 1,
                boundaryNodeIndex: reciprocal.boundaryNodeIndex,
                pathPoint: reciprocal.pathPoint,
                combineMaster: reciprocal.combineMaster
            )
        assertValidationError(
            .nonreciprocalPortal(
                room: portal.connectedRoom,
                portal: portal.connectedPortal
            ),
            replacing(level, rooms: hostileRooms)
        )

        var compatibleLesson = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        compatibleLesson.continueToCourse = nil
        XCTAssertNoThrow(
            try replacing(
                level,
                trainingOpeningLesson: compatibleLesson
            ).validate()
        )
    }

    func testOwnedScript013PackageAdmissionRejectsHostileStockMutations()
        throws
    {
        let fallbackPath =
            "/tmp/revival-script013-final-import-green.rZvL1j/training.revival/levels/descent3.level.training-mission/level.json"
        let path = ProcessInfo.processInfo.environment[
            "REVIVAL_SCRIPT013_OWNED_LEVEL"
        ] ?? fallbackPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip(
                "requires the ignored exact-final owned Script 013 import"
            )
        }
        let stockLevel = try JSONDecoder().decode(
            Level.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        XCTAssertNoThrow(try stockLevel.validate())

        let lesson = try XCTUnwrap(stockLevel.trainingOpeningLesson)
        let continueToCourse = try XCTUnwrap(lesson.continueToCourse)
        var hostileLesson = lesson
        hostileLesson.continueToCourse = .init(
            startGoalObjectHandle: continueToCourse.startGoalObjectHandle,
            collisionRadius: continueToCourse.collisionRadius,
            portalRoomSourceIndex:
                continueToCourse.portalRoomSourceIndex,
            orderedPortalIndices: continueToCourse.orderedPortalIndices,
            instruction: "\(continueToCourse.instruction) ",
            voiceSourceName: continueToCourse.voiceSourceName
        )
        assertValidationError(
            .invalidDependency("Training Script 013 package"),
            replacing(
                stockLevel,
                trainingOpeningLesson: hostileLesson
            )
        )

        let portalRoomIndex = try XCTUnwrap(
            stockLevel.rooms.firstIndex {
                $0.sourceIndex
                    == continueToCourse.portalRoomSourceIndex
            }
        )
        var hostileRooms = stockLevel.rooms
        hostileRooms[portalRoomIndex].portals[0].flags &= ~UInt32(1)
        assertValidationError(
            .invalidDependency("Training Script 013 package"),
            replacing(
                stockLevel,
                rooms: hostileRooms,
                surfacePhysics: stockLevel.surfacePhysics
            )
        )

        let proceedIndex = try XCTUnwrap(
            stockLevel.voiceClips.firstIndex {
                $0.sourceName == continueToCourse.voiceSourceName
            }
        )
        let proceed1 = stockLevel.voiceClips[proceedIndex]
        var hostileVoices = stockLevel.voiceClips
        hostileVoices[proceedIndex] = .init(
            sourceName: proceed1.sourceName,
            sourceEntryIndex: proceed1.sourceEntryIndex,
            sampleRate: proceed1.sampleRate,
            channelCount: proceed1.channelCount,
            frameCount: proceed1.frameCount,
            pcm16LittleEndian: proceed1.pcm16LittleEndian,
            pcmSHA256: proceed1.pcmSHA256,
            sourceArchive: proceed1.sourceArchive,
            sourceSHA256: String(repeating: "0", count: 64)
        )
        assertValidationError(
            .invalidDependency("Training Script 013 package"),
            replacing(stockLevel, voiceClips: hostileVoices)
        )
    }

    func testScript012RequiresExactHiddenUpGoalAndExistingMenuBeep() throws {
        let level = makeTrainingScript003Level()
        let lesson = try XCTUnwrap(
            level.trainingOpeningLesson?.repeatReturnDown
        )
        XCTAssertEqual(lesson.upGoalObjectHandle, 18_441)
        XCTAssertEqual(
            lesson.instruction,
            "Now Slide down until you return to the start position."
        )
        XCTAssertEqual(lesson.soundLogicalName, "MenuBeepEnter")
        XCTAssertNoThrow(try level.validate())

        var hostileLesson = try XCTUnwrap(level.trainingOpeningLesson)
        hostileLesson.repeatReturnDown = .init(
            upGoalObjectHandle: 999_999,
            collisionRadius: lesson.collisionRadius,
            instruction: lesson.instruction,
            soundLogicalName: lesson.soundLogicalName
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 012 repeat-return-down lesson"
            ),
            replacing(level, trainingOpeningLesson: hostileLesson)
        )

        var missingPredecessor = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        missingPredecessor.repeatReturnUp = nil
        assertValidationError(
            .invalidDependency(
                "Training Script 012 repeat-return-down lesson"
            ),
            replacing(level, trainingOpeningLesson: missingPredecessor)
        )

        let stockUpGoal = PlacedObject(
            handle: 18_441,
            type: 7,
            storedID: 67,
            definition: .init(
                storedIndex: 67,
                sourceName: "Invisiblepowerup",
                referenceRuntimeIndex: 68
            ),
            instanceName: "UpGoal",
            flags: 4_352,
            doorShields: nil,
            location: .room(1),
            position: .init(
                x: 2_060.6682,
                y: -25.897_497,
                z: 2_204.6843
            ),
            orientation: .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: nil,
            inertScriptName: nil,
            inertModuleName: nil,
            lightmapSubmodels: []
        )
        let stockPresentation = ObjectPresentationReference(
            objectHandle: 18_441,
            primaryModel: .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        )
        let stockMenuBeep = CanonicalSoundClip(
            logicalName: "MenuBeepEnter",
            sourceName: "MenuBeepSelectC.wav",
            sourceEntryIndex: 2_079,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 2_321,
            pcm16LittleEndian: Data(),
            pcmSHA256:
                "050b01b05e33233f6486c89d18e897a6f219ed8ecd706d6022ef9fdf01383439",
            sourceArchive: "d3.hog",
            sourceSHA256:
                "7176c7fe69ab31912d349065861a512f34f9649a117f6b3c97bee54b68ea2cea",
            importVolume: 0.7
        )
        let stockLesson = TrainingRepeatReturnDownLesson(
            upGoalObjectHandle: 18_441,
            collisionRadius: 10.052_409,
            instruction:
                "Now Slide down until you return to the start position.",
            soundLogicalName: "MenuBeepEnter"
        )
        XCTAssertNoThrow(
            try validateStockTrainingRepeatReturnDownPackage(
                lesson: stockLesson,
                upGoal: stockUpGoal,
                presentation: stockPresentation,
                menuBeep: stockMenuBeep
            )
        )
        var hostileUpGoal = stockUpGoal
        hostileUpGoal.location = .room(2)
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnDownPackage(
                lesson: stockLesson,
                upGoal: hostileUpGoal,
                presentation: stockPresentation,
                menuBeep: stockMenuBeep
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 012 package")
            )
        }

        var compatibleLesson = try XCTUnwrap(
            level.trainingOpeningLesson
        )
        compatibleLesson.repeatReturnDown = nil
        compatibleLesson.continueToCourse = nil
        XCTAssertNoThrow(
            try replacing(
                level,
                trainingOpeningLesson: compatibleLesson
            ).validate()
        )
    }

    func testOwnedScript011PackageAdmissionRejectsHostileStockMutations()
        throws
    {
        let fallbackPath =
            "/tmp/revival-script011-final-import.FPw5aQ/training.revival/levels/descent3.level.training-mission/level.json"
        let path = ProcessInfo.processInfo.environment[
            "REVIVAL_SCRIPT011_OWNED_LEVEL"
        ] ?? fallbackPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip(
                "requires the ignored exact-final owned Script 011 import"
            )
        }
        let stockLevel = try JSONDecoder().decode(
            Level.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        XCTAssertNoThrow(try stockLevel.validate())

        var hostileLesson = try XCTUnwrap(
            stockLevel.trainingOpeningLesson
        )
        let repeatReturnUp = try XCTUnwrap(
            hostileLesson.repeatReturnUp
        )
        hostileLesson.repeatReturnUp = .init(
            startGoalObjectHandle: repeatReturnUp.startGoalObjectHandle,
            collisionRadius: repeatReturnUp.collisionRadius,
            instruction: "Wrong Script 011 instruction",
            voiceSourceName: repeatReturnUp.voiceSourceName
        )
        assertValidationError(
            .invalidDependency("Training Script 011 package"),
            replacing(
                stockLevel,
                trainingOpeningLesson: hostileLesson
            )
        )

        var hostileVoices = stockLevel.voiceClips
        let udownIndex = try XCTUnwrap(
            hostileVoices.firstIndex {
                $0.sourceName.caseInsensitiveCompare("udown.osf")
                    == .orderedSame
            }
        )
        let udown = hostileVoices[udownIndex]
        hostileVoices[udownIndex] = .init(
            sourceName: udown.sourceName,
            sourceEntryIndex: udown.sourceEntryIndex,
            sampleRate: udown.sampleRate,
            channelCount: udown.channelCount,
            frameCount: udown.frameCount,
            pcm16LittleEndian: udown.pcm16LittleEndian,
            pcmSHA256: udown.pcmSHA256,
            sourceArchive: udown.sourceArchive,
            sourceSHA256: String(repeating: "0", count: 64)
        )
        assertValidationError(
            .invalidDependency("Training Script 011 package"),
            replacing(stockLevel, voiceClips: hostileVoices)
        )
    }

    func testScript011RequiresExactHiddenStartGoalAndUDownVoice() throws {
        let stockLevel = makeTrainingScript003Level()
        let repeatReturnUp = try XCTUnwrap(
            stockLevel.trainingOpeningLesson?.repeatReturnUp
        )
        XCTAssertEqual(repeatReturnUp.startGoalObjectHandle, 12_300)
        XCTAssertEqual(
            repeatReturnUp.instruction,
            "Now Slide up  until you stop."
        )
        XCTAssertEqual(repeatReturnUp.voiceSourceName, "udown.osf")
        XCTAssertNoThrow(try stockLevel.validate())

        let fixtureStartGoal = try XCTUnwrap(
            stockLevel.objects.first { $0.handle == 12_300 }
        )
        let stockStartGoal = PlacedObject(
            handle: 12_300,
            type: 7,
            storedID: 67,
            definition: .init(
                storedIndex: 67,
                sourceName: "Invisiblepowerup",
                referenceRuntimeIndex: 68
            ),
            instanceName: "StartGoal",
            flags: 36_864,
            doorShields: nil,
            location: .room(1),
            position: .init(
                x: 2_062.7678,
                y: -134.19601,
                z: 2_201.679
            ),
            orientation: .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: fixtureStartGoal.soundSource,
            inertScriptName: fixtureStartGoal.inertScriptName,
            inertModuleName: fixtureStartGoal.inertModuleName,
            lightmapSubmodels: fixtureStartGoal.lightmapSubmodels
        )
        let stockPresentation = ObjectPresentationReference(
            objectHandle: 12_300,
            primaryModel: .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        )
        let fixtureUDown = try XCTUnwrap(
            stockLevel.voiceClips.first {
                $0.sourceName == "udown.osf"
            }
        )
        let stockUDown = CanonicalVoiceClip(
            sourceName: "udown.osf",
            sourceEntryIndex: 36,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 37_257,
            pcm16LittleEndian: fixtureUDown.pcm16LittleEndian,
            pcmSHA256:
                "e54d74f7e18603ad90015cef1e7c15cce693e35a394be4a0a45943c07740af2a",
            sourceArchive: "missions/training.mn3",
            sourceSHA256:
                "f9596f8edb16be0821bb7b846b81432b27aa95f08ac621f1ac1f15eb1279aa43"
        )
        let stockLesson = TrainingRepeatReturnUpLesson(
            startGoalObjectHandle: 12_300,
            collisionRadius: 10.052_409,
            instruction: "Now Slide up  until you stop.",
            voiceSourceName: "udown.osf"
        )
        XCTAssertNoThrow(
            try validateStockTrainingRepeatReturnUpPackage(
                lesson: stockLesson,
                startGoal: stockStartGoal,
                presentation: stockPresentation,
                udown: stockUDown
            )
        )

        var hostileStartGoal = stockStartGoal
        hostileStartGoal.location = .room(2)
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnUpPackage(
                lesson: stockLesson,
                startGoal: hostileStartGoal,
                presentation: stockPresentation,
                udown: stockUDown
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 011 package")
            )
        }
        let hostileUDown = CanonicalVoiceClip(
            sourceName: stockUDown.sourceName,
            sourceEntryIndex: stockUDown.sourceEntryIndex,
            sampleRate: stockUDown.sampleRate,
            channelCount: stockUDown.channelCount,
            frameCount: stockUDown.frameCount,
            pcm16LittleEndian: stockUDown.pcm16LittleEndian,
            pcmSHA256: stockUDown.pcmSHA256,
            sourceArchive: stockUDown.sourceArchive,
            sourceSHA256: String(repeating: "0", count: 64)
        )
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnUpPackage(
                lesson: stockLesson,
                startGoal: stockStartGoal,
                presentation: stockPresentation,
                udown: hostileUDown
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 011 package")
            )
        }

        var divergentLesson = try XCTUnwrap(
            stockLevel.trainingOpeningLesson
        )
        divergentLesson.repeatReturnUp = .init(
            startGoalObjectHandle: 12_301,
            collisionRadius: repeatReturnUp.collisionRadius,
            instruction: repeatReturnUp.instruction,
            voiceSourceName: repeatReturnUp.voiceSourceName
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 011 repeat-return-up lesson"
            ),
            replacing(
                stockLevel,
                trainingOpeningLesson: divergentLesson
            )
        )
    }

    func testOwnedScript010PackageAdmissionRejectsHostileStockMutations()
        throws
    {
        let fallbackPath =
            "/tmp/revival-script010-final-import.3UeqAk/training.revival/levels/descent3.level.training-mission/level.json"
        let path = ProcessInfo.processInfo.environment[
            "REVIVAL_SCRIPT010_OWNED_LEVEL"
        ] ?? fallbackPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip(
                "requires the ignored exact-final owned Script 010 import"
            )
        }
        let stockLevel = try JSONDecoder().decode(
            Level.self,
            from: Data(contentsOf: URL(fileURLWithPath: path))
        )
        XCTAssertNoThrow(try stockLevel.validate())

        var hostileObjects = stockLevel.objects
        let leftGoalIndex = try XCTUnwrap(
            hostileObjects.firstIndex { $0.handle == 12_299 }
        )
        hostileObjects[leftGoalIndex].location = .room(2)
        assertValidationError(
            .invalidDependency("Training Script 010 package"),
            replacing(stockLevel, objects: hostileObjects)
        )

        var hostileLesson = try XCTUnwrap(
            stockLevel.trainingOpeningLesson
        )
        let repeatReturnRight = try XCTUnwrap(
            hostileLesson.repeatReturnRight
        )
        hostileLesson.repeatReturnRight = .init(
            leftGoalObjectHandle: repeatReturnRight.leftGoalObjectHandle,
            collisionRadius: repeatReturnRight.collisionRadius,
            instruction: "Wrong Script 010 instruction",
            soundLogicalName: repeatReturnRight.soundLogicalName
        )
        assertValidationError(
            .invalidDependency("Training Script 010 package"),
            replacing(
                stockLevel,
                trainingOpeningLesson: hostileLesson
            )
        )
    }

    func testScript010RequiresExactHiddenLeftGoalAndMenuBeep() throws {
        let stockLevel = makeTrainingScript003Level()
        let repeatReturnRight = try XCTUnwrap(
            stockLevel.trainingOpeningLesson?.repeatReturnRight
        )
        XCTAssertEqual(repeatReturnRight.leftGoalObjectHandle, 12_299)
        XCTAssertEqual(
            repeatReturnRight.instruction,
            "Now Slide right until you return to the start position."
        )
        XCTAssertEqual(repeatReturnRight.soundLogicalName, "MenuBeepEnter")
        XCTAssertNoThrow(try stockLevel.validate())

        let fixtureLeftGoal = try XCTUnwrap(
            stockLevel.objects.first { $0.handle == 12_299 }
        )
        let stockLeftGoal = PlacedObject(
            handle: 12_299,
            type: 7,
            storedID: 67,
            definition: .init(
                storedIndex: 67,
                sourceName: "Invisiblepowerup",
                referenceRuntimeIndex: 68
            ),
            instanceName: "LeftGoal",
            flags: 4_352,
            doorShields: nil,
            location: .room(1),
            position: .init(
                x: 1_958.2805,
                y: -131.22517,
                z: 2_205.8071
            ),
            orientation: .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(x: 0, y: 0, z: -1)
            ),
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: fixtureLeftGoal.soundSource,
            inertScriptName: fixtureLeftGoal.inertScriptName,
            inertModuleName: fixtureLeftGoal.inertModuleName,
            lightmapSubmodels: fixtureLeftGoal.lightmapSubmodels
        )
        let stockPresentation = ObjectPresentationReference(
            objectHandle: 12_299,
            primaryModel: .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        )
        let fixtureMenuBeep = try XCTUnwrap(
            stockLevel.soundClips.first {
                $0.logicalName == "MenuBeepEnter"
            }
        )
        let stockMenuBeep = CanonicalSoundClip(
            logicalName: "MenuBeepEnter",
            sourceName: "MenuBeepSelectC.wav",
            sourceEntryIndex: 2_079,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 2_321,
            pcm16LittleEndian: fixtureMenuBeep.pcm16LittleEndian,
            pcmSHA256:
                "050b01b05e33233f6486c89d18e897a6f219ed8ecd706d6022ef9fdf01383439",
            sourceArchive: "d3.hog",
            sourceSHA256:
                "7176c7fe69ab31912d349065861a512f34f9649a117f6b3c97bee54b68ea2cea",
            importVolume: 0.7
        )
        let stockRepeatReturnRight = TrainingRepeatReturnRightLesson(
            leftGoalObjectHandle: 12_299,
            collisionRadius: 10.052_409,
            instruction:
                "Now Slide right until you return to the start position.",
            soundLogicalName: "MenuBeepEnter"
        )
        XCTAssertNoThrow(
            try validateStockTrainingRepeatReturnRightPackage(
                lesson: stockRepeatReturnRight,
                leftGoal: stockLeftGoal,
                presentation: stockPresentation,
                menuBeep: stockMenuBeep
            )
        )

        var hostileLeftGoal = stockLeftGoal
        hostileLeftGoal.location = .room(2)
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnRightPackage(
                lesson: stockRepeatReturnRight,
                leftGoal: hostileLeftGoal,
                presentation: stockPresentation,
                menuBeep: stockMenuBeep
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 010 package")
            )
        }
        let hostileMenuBeep = CanonicalSoundClip(
            logicalName: stockMenuBeep.logicalName,
            sourceName: stockMenuBeep.sourceName,
            sourceEntryIndex: stockMenuBeep.sourceEntryIndex,
            sampleRate: stockMenuBeep.sampleRate,
            channelCount: stockMenuBeep.channelCount,
            frameCount: stockMenuBeep.frameCount,
            pcm16LittleEndian: stockMenuBeep.pcm16LittleEndian,
            pcmSHA256: stockMenuBeep.pcmSHA256,
            sourceArchive: stockMenuBeep.sourceArchive,
            sourceSHA256: stockMenuBeep.sourceSHA256,
            importVolume: 1
        )
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnRightPackage(
                lesson: stockRepeatReturnRight,
                leftGoal: stockLeftGoal,
                presentation: stockPresentation,
                menuBeep: hostileMenuBeep
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 010 package")
            )
        }

        var divergentLesson = try XCTUnwrap(
            stockLevel.trainingOpeningLesson
        )
        divergentLesson.repeatReturnRight = .init(
            leftGoalObjectHandle: 12_301,
            collisionRadius: repeatReturnRight.collisionRadius,
            instruction: repeatReturnRight.instruction,
            soundLogicalName: repeatReturnRight.soundLogicalName
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 010 repeat-return-right lesson"
            ),
            replacing(
                stockLevel,
                trainingOpeningLesson: divergentLesson
            )
        )
    }

    func testScript009RequiresExactHiddenStartGoalAndLRightVoice() throws {
        let stockLevel = makeTrainingScript003Level()
        let repeatReturnLeft = try XCTUnwrap(
            stockLevel.trainingOpeningLesson?.repeatReturnLeft
        )
        XCTAssertEqual(repeatReturnLeft.startGoalObjectHandle, 12_300)
        XCTAssertEqual(
            repeatReturnLeft.instruction,
            "Now Go Left until you stop."
        )
        XCTAssertEqual(repeatReturnLeft.voiceSourceName, "lright.osf")
        XCTAssertNoThrow(try stockLevel.validate())

        let fixtureStartGoal = try XCTUnwrap(
            stockLevel.objects.first {
                $0.handle == repeatReturnLeft.startGoalObjectHandle
            }
        )
        let stockLesson = TrainingRepeatReturnLeftLesson(
            startGoalObjectHandle: 12_300,
            collisionRadius: 10.052_409,
            instruction: "Now Go Left until you stop.",
            voiceSourceName: "lright.osf"
        )
        let stockStartGoal = PlacedObject(
            handle: 12_300,
            type: 7,
            storedID: 67,
            definition: .init(
                storedIndex: 67,
                sourceName: "Invisiblepowerup",
                referenceRuntimeIndex: 68
            ),
            instanceName: "StartGoal",
            flags: 36_864,
            doorShields: nil,
            location: .room(1),
            position: .init(
                x: 2_062.7678,
                y: -134.19601,
                z: 2_201.679
            ),
            orientation: .init(
                right: .init(x: -1, y: 0, z: 0),
                up: .init(x: 0, y: 1, z: -0),
                forward: .init(x: -0, y: -0, z: -1)
            ),
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: fixtureStartGoal.soundSource,
            inertScriptName: fixtureStartGoal.inertScriptName,
            inertModuleName: fixtureStartGoal.inertModuleName,
            lightmapSubmodels: fixtureStartGoal.lightmapSubmodels
        )
        let stockPresentation = ObjectPresentationReference(
            objectHandle: 12_300,
            primaryModel: .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        )
        let fixtureLRight = try XCTUnwrap(
            stockLevel.voiceClips.first {
                $0.sourceName == "lright.osf"
            }
        )
        let stockLRight = CanonicalVoiceClip(
            sourceName: "lright.osf",
            sourceEntryIndex: 19,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 43_289,
            pcm16LittleEndian: fixtureLRight.pcm16LittleEndian,
            pcmSHA256:
                "db92df633fdc0010fe9c5cc89f452ea79107e0abdfd4a1ff1e845220abf8b7b5",
            sourceArchive: "missions/training.mn3",
            sourceSHA256:
                "234c82a439232af1072a7cb6aef8e6d14b6432a2c7a642f7a8e4904a01e88294"
        )
        XCTAssertNoThrow(
            try validateStockTrainingRepeatReturnLeftPackage(
                lesson: stockLesson,
                startGoal: stockStartGoal,
                presentation: stockPresentation,
                lright: stockLRight
            )
        )

        var hostileStartGoal = stockStartGoal
        hostileStartGoal.location = .room(2)
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnLeftPackage(
                lesson: stockLesson,
                startGoal: hostileStartGoal,
                presentation: stockPresentation,
                lright: stockLRight
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 009 package")
            )
        }
        let wrongLRight = CanonicalVoiceClip(
            sourceName: stockLRight.sourceName,
            sourceEntryIndex: stockLRight.sourceEntryIndex,
            sampleRate: stockLRight.sampleRate,
            channelCount: stockLRight.channelCount,
            frameCount: stockLRight.frameCount,
            pcm16LittleEndian: stockLRight.pcm16LittleEndian,
            pcmSHA256: stockLRight.pcmSHA256,
            sourceArchive: stockLRight.sourceArchive,
            sourceSHA256: String(repeating: "0", count: 64)
        )
        XCTAssertThrowsError(
            try validateStockTrainingRepeatReturnLeftPackage(
                lesson: stockLesson,
                startGoal: stockStartGoal,
                presentation: stockPresentation,
                lright: wrongLRight
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 009 package")
            )
        }

        var authoredObjects = stockLevel.objects
        let authoredTargetIndex = try XCTUnwrap(
            authoredObjects.firstIndex {
                $0.handle == repeatReturnLeft.startGoalObjectHandle
            }
        )
        let authoredPosition = authoredObjects[authoredTargetIndex].position
        authoredObjects[authoredTargetIndex].position = .init(
            x: authoredPosition.x + 1,
            y: authoredPosition.y,
            z: authoredPosition.z
        )
        XCTAssertNoThrow(
            try replacing(
                stockLevel,
                objects: authoredObjects
            ).validateForAuthoring()
        )

        assertValidationError(
            .invalidDependency(
                "Training Script 009 repeat-return-left lesson"
            ),
            replacing(
                stockLevel,
                voiceClips: stockLevel.voiceClips.filter {
                    $0.sourceName != "lright.osf"
                }
            )
        )

        var divergentLesson = try XCTUnwrap(
            stockLevel.trainingOpeningLesson
        )
        let leftGoal = try XCTUnwrap(
            stockLevel.objects.first { $0.handle == 12_299 }
        )
        let leftGoalPresentation = try XCTUnwrap(
            stockLevel.objectPresentations.first {
                $0.objectHandle == leftGoal.handle
            }
        )
        let leftGoalModel = try XCTUnwrap(
            stockLevel.models.first {
                $0.source == leftGoalPresentation.primaryModel
            }
        )
        divergentLesson.repeatReturnLeft = .init(
            startGoalObjectHandle: leftGoal.handle,
            collisionRadius: sourceObjectPresentationSize(
                model: leftGoalModel,
                objectType: leftGoal.type
            ),
            instruction: repeatReturnLeft.instruction,
            voiceSourceName: repeatReturnLeft.voiceSourceName
        )
        assertValidationError(
            .invalidDependency(
                "Training Script 009 repeat-return-left lesson"
            ),
            replacing(
                stockLevel,
                trainingOpeningLesson: divergentLesson
            )
        )
    }

    func testScript008RequiresExactHiddenForwardGoalAndMenuBeep() throws {
        var stockLevel = makeTrainingScript003Level()
        stockLevel = replacing(
            stockLevel,
            missionKey: "descent3.mission.pilot-training",
            levelKey: "descent3.level.training-mission",
            source: replacing(
                stockLevel.source,
                archiveSHA256:
                    "fc1d81921cc4b2618e441b7b9d08c4bcb5cff90731be1bfa6f3a7b054fc0cb54",
                levelSHA256:
                    "915a561cd3bd720d88bffed72fe41b4ff711c287711f060ecd9696e2cd5f7d41"
            )
        )
        let repeatForwardGoal = try XCTUnwrap(
            stockLevel.trainingOpeningLesson?.repeatForwardGoal
        )
        let stockRepeatForwardGoal = TrainingRepeatForwardGoalLesson(
            forwardGoalObjectHandle: 12_301,
            collisionRadius: 10.052_409,
            reverseInstruction:
                "Now use the reverse Key to return to where you started!",
            soundLogicalName: "MenuBeepEnter"
        )
        let fixtureForwardGoal = try XCTUnwrap(
            stockLevel.objects.first {
                $0.handle == repeatForwardGoal.forwardGoalObjectHandle
            }
        )
        let forwardGoal = PlacedObject(
            handle: 12_301,
            type: 7,
            storedID: 67,
            definition: .init(
                storedIndex: 67,
                sourceName: "Invisiblepowerup",
                referenceRuntimeIndex: 68
            ),
            instanceName: "ForwardGoal",
            flags: 36_864,
            doorShields: nil,
            location: .room(1),
            position: .init(
                x: 2_060.4836,
                y: -131.22517,
                z: 2_310.928
            ),
            orientation: .init(
                right: .init(
                    x: -0.997_518_1,
                    y: 0,
                    z: 0.070_410_63
                ),
                up: .init(x: 0, y: 1, z: 0),
                forward: .init(
                    x: -0.070_410_63,
                    y: 0,
                    z: -0.997_518_1
                )
            ),
            containsType: 255,
            containsID: 0,
            containsCount: 0,
            lifeLeft: 0,
            soundSource: fixtureForwardGoal.soundSource,
            inertScriptName: fixtureForwardGoal.inertScriptName,
            inertModuleName: fixtureForwardGoal.inertModuleName,
            lightmapSubmodels: fixtureForwardGoal.lightmapSubmodels
        )
        let presentation = ObjectPresentationReference(
            objectHandle: 12_301,
            primaryModel: .init(
                storedIndex: 6,
                sourceName: "invisiblepowerup.OOF"
            ),
            mediumModel: nil,
            lowModel: nil,
            dyingModel: nil,
            mediumDistance: nil,
            lowDistance: nil,
            isVisible: false
        )
        let fixtureMenuBeep = try XCTUnwrap(
            stockLevel.soundClips.first {
                $0.logicalName == repeatForwardGoal.soundLogicalName
            }
        )
        let stockMenuBeep = CanonicalSoundClip(
            logicalName: fixtureMenuBeep.logicalName,
            sourceName: "MenuBeepSelectC.wav",
            sourceEntryIndex: 2_079,
            sampleRate: 22_050,
            channelCount: 1,
            frameCount: 2_321,
            pcm16LittleEndian: fixtureMenuBeep.pcm16LittleEndian,
            pcmSHA256:
                "050b01b05e33233f6486c89d18e897a6f219ed8ecd706d6022ef9fdf01383439",
            sourceArchive: "d3.hog",
            sourceSHA256:
                "7176c7fe69ab31912d349065861a512f34f9649a117f6b3c97bee54b68ea2cea",
            importVolume: 0.7
        )
        XCTAssertNoThrow(
            try validateStockTrainingRepeatForwardGoalPackage(
                lesson: stockRepeatForwardGoal,
                forwardGoal: forwardGoal,
                presentation: presentation,
                menuBeep: stockMenuBeep
            )
        )

        var hostileForwardGoal = forwardGoal
        hostileForwardGoal.orientation = .init(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )
        XCTAssertThrowsError(
            try validateStockTrainingRepeatForwardGoalPackage(
                lesson: stockRepeatForwardGoal,
                forwardGoal: hostileForwardGoal,
                presentation: presentation,
                menuBeep: stockMenuBeep
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 008 package")
            )
        }

        let wrongVolumeMenuBeep = CanonicalSoundClip(
            logicalName: stockMenuBeep.logicalName,
            sourceName: stockMenuBeep.sourceName,
            sourceEntryIndex: stockMenuBeep.sourceEntryIndex,
            sampleRate: stockMenuBeep.sampleRate,
            channelCount: stockMenuBeep.channelCount,
            frameCount: stockMenuBeep.frameCount,
            pcm16LittleEndian: stockMenuBeep.pcm16LittleEndian,
            pcmSHA256: stockMenuBeep.pcmSHA256,
            sourceArchive: stockMenuBeep.sourceArchive,
            sourceSHA256: stockMenuBeep.sourceSHA256,
            importVolume: 1
        )
        XCTAssertThrowsError(
            try validateStockTrainingRepeatForwardGoalPackage(
                lesson: stockRepeatForwardGoal,
                forwardGoal: forwardGoal,
                presentation: presentation,
                menuBeep: wrongVolumeMenuBeep
            )
        ) {
            XCTAssertEqual(
                $0 as? LevelValidationError,
                .invalidDependency("Training Script 008 package")
            )
        }

        var hostileObjects = stockLevel.objects
        let targetIndex = try XCTUnwrap(
            hostileObjects.firstIndex {
                $0.handle == repeatForwardGoal.forwardGoalObjectHandle
            }
        )
        hostileObjects[targetIndex].orientation =
            hostileForwardGoal.orientation
        XCTAssertNoThrow(
            try replacing(
                stockLevel,
                objects: hostileObjects
            ).validateForAuthoring()
        )
    }

    func testScript007RequiresHiddenCollisionActiveStartGoal() throws {
        let level = makeTrainingScript003Level()
        XCTAssertNoThrow(try level.validate())
        var lesson = try XCTUnwrap(level.trainingOpeningLesson)
        let repeatForward = try XCTUnwrap(lesson.repeatForward)
        lesson.repeatForwardGoal = nil
        lesson.repeatReturnLeft = nil
        lesson.repeatReturnRight = nil
        lesson.repeatReturnUp = nil
        lesson.repeatReturnDown = nil
        lesson.continueToCourse = nil
        lesson.startCourse = nil
        lesson.returnLeft = nil
        lesson.returnRight = nil
        lesson.returnUp = nil
        let isolatedLevel = replacing(level, trainingOpeningLesson: lesson)
        let presentationIndex = try XCTUnwrap(
            isolatedLevel.objectPresentations.firstIndex {
                $0.objectHandle == repeatForward.startGoalObjectHandle
            }
        )
        var visiblePresentations = isolatedLevel.objectPresentations
        let hidden = visiblePresentations[presentationIndex]
        visiblePresentations[presentationIndex] = .init(
            objectHandle: hidden.objectHandle,
            primaryModel: hidden.primaryModel,
            mediumModel: hidden.mediumModel,
            lowModel: hidden.lowModel,
            dyingModel: hidden.dyingModel,
            mediumDistance: hidden.mediumDistance,
            lowDistance: hidden.lowDistance,
            isVisible: true
        )
        assertValidationError(
            .invalidDependency("Training Script 007 repeat-forward lesson"),
            replacing(isolatedLevel, objectPresentations: visiblePresentations)
        )

        lesson.repeatForward = .init(
            startGoalObjectHandle: 999_999,
            collisionRadius: repeatForward.collisionRadius,
            successMessage: repeatForward.successMessage,
            repeatMessage: repeatForward.repeatMessage,
            forwardInstruction: repeatForward.forwardInstruction,
            voiceSourceName: repeatForward.voiceSourceName
        )
        assertValidationError(
            .invalidDependency("Training Script 007 repeat-forward lesson"),
            replacing(isolatedLevel, trainingOpeningLesson: lesson)
        )

        lesson.repeatForward = repeatForward
        // A package without the level script data (schema 9): the
        // Training module would name the removed clips.
        var stockLevel = replacing(
            isolatedLevel,
            schemaVersion: 9,
            trainingOpeningLesson: lesson,
            voiceClips: isolatedLevel.voiceClips.filter {
                !["left1.osf", "return2.osf", "up1.osf"].contains(
                    $0.sourceName
                )
            }
        )
        stockLevel = replacing(
            stockLevel,
            missionKey: "descent3.mission.pilot-training",
            levelKey: "descent3.level.training-mission",
            source: replacing(
                stockLevel.source,
                archiveSHA256:
                    "fc1d81921cc4b2618e441b7b9d08c4bcb5cff90731be1bfa6f3a7b054fc0cb54",
                levelSHA256:
                    "915a561cd3bd720d88bffed72fe41b4ff711c287711f060ecd9696e2cd5f7d41"
            )
        )
        var hostileObjects = stockLevel.objects
        let targetIndex = try XCTUnwrap(
            hostileObjects.firstIndex {
                $0.handle == repeatForward.startGoalObjectHandle
            }
        )
        hostileObjects[targetIndex].orientation = .init(
            right: .init(x: 1, y: 0, z: 0),
            up: .init(x: 0, y: 1, z: 0),
            forward: .init(x: 0, y: 0, z: 1)
        )
        assertValidationError(
            .invalidDependency("Training Script 007 package"),
            replacing(stockLevel, objects: hostileObjects)
        )
        XCTAssertNoThrow(
            try replacing(
                stockLevel,
                objects: hostileObjects
            ).validateForAuthoring()
        )
    }

    func testScript006RequiresHiddenCollisionActiveUpGoal() throws {
        let level = makeTrainingScript003Level()
        XCTAssertNoThrow(try level.validate())
        let lesson = try XCTUnwrap(level.trainingOpeningLesson)
        let returnDown = try XCTUnwrap(lesson.returnDown)
        let presentationIndex = try XCTUnwrap(
            level.objectPresentations.firstIndex {
                $0.objectHandle == returnDown.upGoalObjectHandle
            }
        )
        var visiblePresentations = level.objectPresentations
        let hidden = visiblePresentations[presentationIndex]
        visiblePresentations[presentationIndex] = .init(
            objectHandle: hidden.objectHandle,
            primaryModel: hidden.primaryModel,
            mediumModel: hidden.mediumModel,
            lowModel: hidden.lowModel,
            dyingModel: hidden.dyingModel,
            mediumDistance: hidden.mediumDistance,
            lowDistance: hidden.lowDistance,
            isVisible: true
        )
        assertValidationError(
            .invalidDependency("Training Script 006 return-down lesson"),
            replacing(level, objectPresentations: visiblePresentations)
        )

        var missingTarget = lesson
        missingTarget.returnDown = .init(
            upGoalObjectHandle: 999_999,
            collisionRadius: returnDown.collisionRadius,
            successMessage: returnDown.successMessage,
            instruction: returnDown.instruction,
            voiceSourceName: returnDown.voiceSourceName
        )
        assertValidationError(
            .invalidDependency("Training Script 006 return-down lesson"),
            replacing(level, trainingOpeningLesson: missingTarget)
        )
    }
}
