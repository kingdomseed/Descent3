import AppKit
import XCTest

/// The buddy menu (Descent3/buddymenu.cpp) and its F4 key
/// (GameLoop.cpp:1493) as Core runs them: the request, the pause, the
/// Guide-Bot's COM_GET_MENU list, and each selection's COM_DO_ACTION.
final class BuddyMenuTests: XCTestCase {
    private func session(
        _ level: Level = makeGuideBotGoalLevel()
    ) -> GameSession {
        GameSession(level: level, presentationReadyTimestamp: 0)
    }

    /// F4 sets GAME_BUDDY_INTERFACE for the menu after the frame; a dying
    /// player's keys stop before it (GameLoop.cpp:1433-1440).
    func testF4AsksForTheMenuOnlyWhileThePlayerIsAlive() {
        let simulation = session()
        _ = simulation.update(at: 0.1, input: .zero)
        XCTAssertFalse(simulation.buddyMenuIsRequested)
        _ = simulation.update(at: 0.2, input: .init(opensBuddyMenu: true))
        XCTAssertTrue(simulation.buddyMenuIsRequested)
        XCTAssertNotNil(simulation.openBuddyMenu(at: 0.2))
        XCTAssertFalse(simulation.buddyMenuIsRequested)
        simulation.closeBuddyMenu(at: 0.2)

        let dying = session()
        dying.world.playerDeath = .init(
            fate: .instant, killer: .none, initialDeathTime: 0
        )
        _ = dying.update(at: 0.1, input: .init(opensBuddyMenu: true))
        XCTAssertFalse(dying.buddyMenuIsRequested)
    }

    /// RunGameMenu pauses the single-player game while the menu is open
    /// (PauseGame, gamesequence.cpp:1984) and resumes it after
    /// (:2139): the time the menu was open is not simulated.
    func testTheOpenMenuPausesTheGameWithNoCatchUp() {
        let simulation = session()
        _ = simulation.update(at: 1, input: .zero)
        let gameTime = simulation.world.gameTime
        XCTAssertNotNil(simulation.openBuddyMenu(at: 1))
        XCTAssertEqual(simulation.pauseDepth, 1)
        XCTAssertNotNil(simulation.buddyMenu)
        simulation.closeBuddyMenu(at: 5)
        XCTAssertEqual(simulation.pauseDepth, 0)
        XCTAssertNil(simulation.buddyMenu)
        _ = simulation.update(at: 5.1, input: .zero)
        XCTAssertEqual(
            simulation.world.gameTime - gameTime, 0.1, accuracy: 0.000_1
        )
    }

    /// MakeCommandList (AIGame.cpp:4879): in the ship the menu offers "Exit
    /// ship" and "Rename GB Unit" (with its dialog); during the birth the
    /// list is empty, so the HUD shows TXT_NOGUIDEBOT (buddymenu.cpp:377)
    /// and no menu opens; in GBM_AMBIENT it offers the goal and "Return to
    /// ship" but not "Exit ship". The hotspot text numbers the items.
    func testTheMenuListsTheCommandsOfTheGuideBotsMode() throws {
        let simulation = session()
        let inShip = try XCTUnwrap(simulation.openBuddyMenu(at: 0))
        XCTAssertEqual(inShip.title, "GB Command Menu")
        XCTAssertEqual(inShip.commands.map(\.id), [0, 2])
        XCTAssertEqual(inShip.itemText(0), "1. Exit ship")
        XCTAssertEqual(inShip.itemText(1), "2. Rename GB Unit")
        XCTAssertEqual(inShip.commands[1].dialogText, "Enter GuideBot name:")
        XCTAssertEqual(inShip.acceleratorCharacter(0), "1")
        simulation.selectBuddyMenuItem(0, at: 0)

        var timestamp = 0.0
        simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(
            simulation.world.testGuideBot?.mode, GuideBotScript.birthMode
        )
        XCTAssertNil(simulation.openBuddyMenu(at: timestamp))
        XCTAssertNil(simulation.buddyMenu)
        XCTAssertEqual(simulation.pauseDepth, 0)
        let next = simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(hudMessages(next).first, BuddyMenu.noGuideBotText)

        simulation.runFrames(33, from: &timestamp)
        let ambient = try XCTUnwrap(simulation.openBuddyMenu(at: timestamp))
        let ids = ambient.commands.map(\.id)
        XCTAssertEqual(ids.first, GuideBotScript.findActiveGoal0)
        XCTAssertTrue(ids.contains(GuideBotScript.returnToShipCommand))
        XCTAssertFalse(ids.contains(GuideBotScript.exitShipCommand))
        simulation.closeBuddyMenu(at: timestamp)
    }

    /// BuddyProcessCommand (buddymenu.cpp:437) sends each item's command:
    /// "Exit ship" releases the Guide-Bot (EVT_USE, AIGame.cpp:5243), the
    /// goal item sends it to the goal (:4971), and "Return to ship" calls
    /// it back (:5075). The Guide-Bot's messages wait for the next frame,
    /// so the world holds no presentation while the game is paused.
    func testEachSelectionSendsItsCommandToTheGuideBot() throws {
        let simulation = session()
        XCTAssertTrue(simulation.selectTestBuddyCommand(
            GuideBotScript.exitShipCommand
        ))
        XCTAssertEqual(
            simulation.world.objectType(simulation.world.buddyHandle), .robot
        )
        XCTAssertTrue(simulation.world.presentationRequests.isEmpty)
        XCTAssertNoThrow(try simulation.world.validate(against: simulation.level))
        var timestamp = 0.0
        let released = simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(soundNames(released), ["GBExpulsionA"])
        simulation.runFrames(34, from: &timestamp)

        XCTAssertTrue(simulation.selectTestBuddyCommand(
            GuideBotScript.findActiveGoal0
        ))
        let accepted = simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(hudMessages(accepted), ["GB: On my way!"])
        XCTAssertEqual(
            simulation.world.testGuideBot?.lastCommand,
            GuideBotScript.findActiveGoal0
        )

        simulation.runFrames(30, from: &timestamp)
        XCTAssertTrue(simulation.selectTestBuddyCommand(
            GuideBotScript.returnToShipCommand
        ))
        XCTAssertEqual(simulation.world.testGuideBot?.isMarkedForPickup, true)
        let recalled = simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(hudMessages(recalled), ["GB: Returning to ship."])
    }

    /// GBC_RENAME (AIGame.cpp:5395-5403): the dialog's answer (at most 7
    /// characters, `answer[8]`, buddymenu.cpp:440) names the Guide-Bot and
    /// the pilot's Guide-Bot; an empty answer (a cancelled dialog) is
    /// refused.
    func testRenameUsesTheDialogAnswer() throws {
        let simulation = session()
        XCTAssertTrue(simulation.selectTestBuddyCommand(
            GuideBotScript.renameCommand, text: "Sparkyxyz"
        ))
        XCTAssertEqual(simulation.world.testGuideBot?.name, "Sparkyx")
        XCTAssertEqual(simulation.world.playerGuideBotName, "Sparkyx")
        var timestamp = 0.0
        let renamed = simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(
            hudMessages(renamed), ["Sparkyx: Thank you for the new name!"]
        )

        simulation.runFrames(30, from: &timestamp)
        XCTAssertTrue(simulation.selectTestBuddyCommand(
            GuideBotScript.renameCommand, text: nil
        ))
        XCTAssertEqual(simulation.world.testGuideBot?.name, "Sparkyx")
        let refused = simulation.runFrames(1, from: &timestamp)
        XCTAssertEqual(hudMessages(refused), ["Sparkyx: No way!"])
    }

    /// The menu is session state: Guidebot_menu_data is a static of
    /// buddymenu.cpp that no save writes, and no key (so no quicksave)
    /// reaches the game while the menu is open (GameLoop.cpp:2389). A world
    /// saved after the F4 frame restores with no menu request.
    func testTheMenuIsNotPartOfTheSavedWorld() throws {
        let simulation = session()
        _ = simulation.update(at: 0.1, input: .init(opensBuddyMenu: true))
        XCTAssertTrue(simulation.buddyMenuIsRequested)
        let saved = try JSONDecoder().decode(
            GameWorld.self, from: JSONEncoder().encode(simulation.world)
        )
        let restored = try GameSession(
            level: simulation.level, world: saved, resumedAtTimestamp: 10
        )
        XCTAssertFalse(restored.buddyMenuIsRequested)
        XCTAssertNil(restored.buddyMenu)
        XCTAssertEqual(saved, simulation.world)
    }
}
