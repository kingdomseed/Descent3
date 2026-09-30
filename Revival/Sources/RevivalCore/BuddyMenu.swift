// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/buddymenu.cpp (Descent 3, Copyright (C) 2024
// Parallax Software, GPL-3.0-or-later): BuddyDisplay (:95),
// BuddyBotDownloadData (:363), and BuddyProcessCommand (:437); with the F4
// key (ProcessNormalKey, Descent3/GameLoop.cpp:1493) and the
// GAME_BUDDY_INTERFACE case of RunGameMenu (Descent3/gamesequence.cpp:1972,
// :2006). The multiplayer download and selection paths are post-1.0. The
// menu is session state, not world state: Guidebot_menu_data is a static
// of buddymenu.cpp that SaveGameState does not write, and no key reaches
// the game while the menu is open (ProcessKeys, GameLoop.cpp:2389), so no
// save can happen then. The app draws the menu (RevivalAppKit).

/// Guidebot_menu_data as BuddyDisplay lists it.
struct BuddyMenu: Equatable, Sendable {
    /// `gb_menu.title`.
    let title: String
    /// The commands, in the Guide-Bot's order.
    let commands: [GuideBotMenu.Command]

    /// TXT_NOGUIDEBOT (stringtable.h:78): the HUD text when the Guide-Bot
    /// offers no command. The engine string table is not imported yet, so
    /// the English text of the header comment stands in (M4).
    static let noGuideBotText = "One second... Waking up."

    /// The edit dialog's buffer is `char answer[8]`, and DoEditDialog takes
    /// at most 7 characters (buddymenu.cpp:440, :445).
    static let maximumAnswerLength = 7

    /// N_WINDOW_ACCELS (ui.h:1009).
    private static let windowAcceleratorCount = 48

    /// The hotspot text (buddymenu.cpp:113-117): "1. " to "9. ", then
    /// "A. " onward.
    func itemText(_ index: Int) -> String {
        let text = commands[index].text
        if index < 9 {
            return "\(index + 1). \(text)"
        }
        let letter = Character(UnicodeScalar(
            UInt8(ascii: "A") &+ UInt8(truncatingIfNeeded: index - 9)
        ))
        return "\(letter). \(text)"
    }

    /// The accelerator key of an item (buddymenu.cpp:124-132): '1' to '9',
    /// then 'a' onward, for the first N_WINDOW_ACCELS - 1 items. An index
    /// past 'z' names no key.
    func acceleratorCharacter(_ index: Int) -> Character? {
        guard index < Self.windowAcceleratorCount - 1 else { return nil }
        if index < 9 {
            return Character(String(index + 1))
        }
        guard index - 9 < 26 else { return nil }
        return Character(UnicodeScalar(
            UInt8(ascii: "a") + UInt8(index - 9)
        ))
    }
}

extension GameSession {
    /// RunGameMenu's GAME_BUDDY_INTERFACE case (gamesequence.cpp:1972-2014):
    /// the single-player game pauses (PauseGame, :1984), and BuddyDisplay
    /// (buddymenu.cpp:95) gets the menu from BuddyBotDownloadData (:363),
    /// which sends COM_GET_MENU to the player's Guide-Bot. When the
    /// Guide-Bot offers no command, the HUD shows TXT_NOGUIDEBOT, no menu
    /// opens, and the game resumes (:2139). Returns the open menu.
    func openBuddyMenu(at timestamp: Double) -> BuddyMenu? {
        precondition(buddyMenu == nil)
        buddyMenuIsRequested = false
        stopTime(at: timestamp)
        // A level with no Guide-Bot fails the ASSERT(b_obj) of :371; here it
        // gets the same message as a Guide-Bot with no command.
        guard let menu = world.guideBotMenu(level: level),
              !menu.commands.isEmpty
        else {
            takeMenuPresentation()
            pendingMenuPresentation.append(
                .hudMessage(BuddyMenu.noGuideBotText)
            )
            startTime(at: timestamp)
            return nil
        }
        takeMenuPresentation()
        let open = BuddyMenu(title: menu.title, commands: menu.commands)
        buddyMenu = open
        return open
    }

    /// BuddyProcessCommand (buddymenu.cpp:437): the item's command goes to
    /// the Guide-Bot as COM_DO_ACTION through AINotify. A GBCT_STRING_DIALOG
    /// item sends the text of its edit dialog (empty when the dialog was
    /// cancelled); another item sends none. Then the menu closes and the
    /// game resumes (RunGameMenu, gamesequence.cpp:2139-2146).
    func selectBuddyMenuItem(
        _ index: Int,
        text: String? = nil,
        at timestamp: Double
    ) {
        guard let menu = buddyMenu else {
            preconditionFailure("No buddy menu is open.")
        }
        precondition(menu.commands.indices.contains(index))
        let command = menu.commands[index]
        let answer = command.dialogText == nil
            ? nil
            : String((text ?? "").prefix(BuddyMenu.maximumAnswerLength))
        world.guideBotCommand(command.id, text: answer, level: level)
        takeMenuPresentation()
        closeBuddyMenu(at: timestamp)
    }

    /// UID_OK or UID_CANCEL (ESC, F4, or the return button,
    /// buddymenu.cpp:158-161): the menu closes with no command, and the game
    /// resumes.
    func closeBuddyMenu(at timestamp: Double) {
        precondition(buddyMenu != nil)
        buddyMenu = nil
        startTime(at: timestamp)
    }

    /// The HUD messages and sounds the Guide-Bot asked for while the game
    /// is paused wait for the next frame's presentation, so the world holds
    /// none between frames.
    private func takeMenuPresentation() {
        pendingMenuPresentation += world.presentationRequests
        world.presentationRequests = []
    }
}
