// SPDX-License-Identifier: GPL-3.0-or-later
//
// Translated from Descent3/OsirisLoadandBind.cpp (Descent 3, Copyright (C)
// 2024 Parallax Software, GPL-3.0-or-later): the timer table (:2254-2278),
// Osiris_ProcessTimers (:2285), Osiris_ResetAllTimers (:2395),
// Osiris_CreateTimer (:2405), Osiris_CancelTimer (:2471),
// Osiris_GetTimerHandle (:2502), Osiris_CancelTimerID (:2515),
// Osiris_TimerExists (:2527), and
// Osiris_TimerTimeRemaining (:2545). The request fields come from
// tOSIRISTIMER (scripts/osiris_common.h:1168-1190).

/// A timer request (tOSIRISTIMER).
struct OsirisTimerRequest: Equatable, Sendable {
    enum Target: Equatable, Sendable {
        case object(ObjectHandle)   // object_handle
        case trigger(Int)           // OTF_TRIGGER, trigger_number
        case level                  // OTF_LEVEL
    }

    var target: Target
    /// Passed back in EVT_TIMER.
    var id: Int32
    /// Interval between signals, or the delay of a one-shot timer.
    var interval: Float
    /// OTF_REPEATER with repeat_count: a count of signals, or -1 for
    /// endless.
    var repeatCount: Int32?
    /// OTF_CANCELONDEAD with object_handle_detonator.
    var detonator: ObjectHandle?
}

/// One entry of OsirisTimers (tOSIRISINTERNALTIMER). A free entry keeps its
/// last fields, as the original only clears OITF_USED.
struct OsirisTimer: Codable, Equatable, Sendable {
    enum Owner: Codable, Equatable, Sendable {
        case object(ObjectHandle)
        case trigger(Int)
        case level
    }

    /// OITF_USED.
    var isUsed = false
    /// OITF_REPEATCALL.
    var repeats = false
    /// OITF_CANCELONDEAD: `objhandle_detonator`.
    var detonator: ObjectHandle?
    /// OITF_TRIGGERTIMER, OITF_LEVELTIMER, or the object handle.
    var owner = Owner.object(ObjectHandle(0))
    var id: Int32 = 0
    var repeatCount: Int32 = 0
    var handle: Int32 = 0
    var interval: Float = 0
    var nextSignal: Float = 0
    var end: Float = 0
}

/// OsirisTimers and Osiris_timer_counter.
struct OsirisTimers: Codable, Equatable, Sendable {
    /// MAX_OSIRIS_TIMERS (OsirisLoadandBind.cpp:2254).
    static let capacity = 64

    private(set) var entries = Array(
        repeating: OsirisTimer(),
        count: OsirisTimers.capacity
    )
    /// Osiris_timer_counter. Osiris_ResetAllTimers does not reset it.
    private(set) var counter: Int32 = 0

    /// FORM_HANDLE (OsirisLoadandBind.cpp:2276).
    static func handle(counter: Int32, slot: Int) -> Int32 {
        Int32(
            bitPattern: (UInt32(bitPattern: counter) & 0xff_ffff) << 8
                | UInt32(slot & 0xff)
        )
    }

    /// GET_SLOT (OsirisLoadandBind.cpp:2278).
    static func slot(of handle: Int32) -> Int {
        Int(handle & 0xff)
    }

    /// Osiris_ResetAllTimers (OsirisLoadandBind.cpp:2395).
    mutating func resetAll() {
        for index in entries.indices {
            entries[index].isUsed = false
            entries[index].repeats = false
            entries[index].detonator = nil
        }
    }

    /// Osiris_CreateTimer (OsirisLoadandBind.cpp:2405). Returns the timer
    /// handle, or -1 when all 64 entries are in use.
    mutating func create(
        _ request: OsirisTimerRequest,
        gameTime: Float
    ) -> Int32 {
        guard let slot = entries.firstIndex(where: { !$0.isUsed }) else {
            return -1
        }
        var timer = OsirisTimer()
        timer.isUsed = true
        timer.id = request.id
        timer.end = request.interval + gameTime
        timer.interval = request.interval
        timer.nextSignal = request.interval + gameTime
        switch request.target {
        case let .trigger(number): timer.owner = .trigger(number)
        case .level: timer.owner = .level
        case let .object(handle): timer.owner = .object(handle)
        }
        if let repeatCount = request.repeatCount {
            timer.repeats = true
            timer.repeatCount = repeatCount
            if repeatCount != -1 {
                timer.end = request.interval * Float(repeatCount) + gameTime
            }
        }
        timer.detonator = request.detonator
        counter &+= 1
        timer.handle = Self.handle(counter: counter, slot: slot)
        entries[slot] = timer
        return timer.handle
    }

    /// Osiris_TimerExists (OsirisLoadandBind.cpp:2527).
    func exists(_ handle: Int32) -> Bool {
        let slot = Self.slot(of: handle)
        return slot < Self.capacity
            && entries[slot].isUsed
            && entries[slot].handle == handle
    }

    /// Osiris_TimerTimeRemaining (OsirisLoadandBind.cpp:2545).
    func timeRemaining(_ handle: Int32, gameTime: Float) -> Float {
        let slot = Self.slot(of: handle)
        guard slot < Self.capacity,
              entries[slot].isUsed,
              entries[slot].handle == handle
        else {
            return -1
        }
        return entries[slot].end - gameTime
    }

    /// Osiris_GetTimerHandle (OsirisLoadandBind.cpp:2502).
    func handle(forID id: Int32) -> Int32 {
        entries.first { $0.isUsed && $0.id == id }?.handle ?? 0
    }

    fileprivate mutating func setEntry(_ slot: Int, _ timer: OsirisTimer) {
        entries[slot] = timer
    }

    fileprivate mutating func clearUsed(_ slot: Int) {
        entries[slot].isUsed = false
    }
}

/// Where Osiris_ProcessTimers and Osiris_CancelTimer send a timer event.
enum OsirisTimerTarget: Equatable, Sendable {
    case object(ObjectHandle)
    case trigger(Int)
    case level
}

extension GameWorld {
    /// Osiris_CreateTimer with the current (pre-update) Gametime.
    @discardableResult
    mutating func osirisCreateTimer(_ request: OsirisTimerRequest) -> Int32 {
        osirisTimers.create(request, gameTime: gameTime)
    }

    /// Osiris_ProcessTimers (OsirisLoadandBind.cpp:2285), run after the
    /// level EVT_INTERVAL in GameFrame (GameLoop.cpp:3014). It reads the
    /// pre-update Gametime. Events go to the owner's scripts.
    mutating func osirisProcessTimers(level: Level) {
        osirisProcessTimers { world, target, event in
            world.osirisSendTimerEvent(target, event, level: level)
        }
    }

    /// Osiris_ProcessTimers with the event delivery passed in, so a test can
    /// record it. Each entry is read from the world when its turn comes, so
    /// a timer that a handler creates in a later entry is processed in the
    /// same pass, as in the original.
    mutating func osirisProcessTimers(
        send: (inout GameWorld, OsirisTimerTarget, ScriptEvent) -> Void
    ) {
        for index in 0..<OsirisTimers.capacity {
            var timer = osirisTimers.entries[index]
            guard timer.isUsed else { continue }
            var signal = false
            var kill = false

            if let detonator = timer.detonator {
                let object = objects[detonator]
                // A dying or dead player also cancels the timer; player death
                // arrives in M1 step 7.
                if object == nil || object?.type == .ghost {
                    timer.isUsed = false
                    timer.repeatCount = 0
                    osirisTimers.setEntry(index, timer)
                    send(
                        &self,
                        timer.owner.target,
                        .timerCancel(handle: timer.handle, detonated: true)
                    )
                    continue
                }
            }

            if timer.nextSignal <= gameTime {
                signal = true
                if timer.repeats {
                    if timer.repeatCount != -1 {
                        timer.repeatCount -= 1
                        if timer.repeatCount <= 0 {
                            kill = true
                            timer.repeatCount = 0
                        } else {
                            timer.nextSignal += timer.interval
                        }
                    } else {
                        timer.nextSignal += timer.interval
                    }
                }
            }
            if !(timer.repeats && timer.repeatCount == -1),
               timer.end <= gameTime {
                kill = true
                signal = true
            }
            osirisTimers.setEntry(index, timer)

            let event = ScriptEvent.timer(id: timer.id, gameTime: gameTime)
            switch timer.owner {
            case .trigger, .level:
                if signal {
                    send(&self, timer.owner.target, event)
                }
            case let .object(handle):
                if objects[handle] != nil {
                    if signal {
                        send(&self, .object(handle), event)
                    }
                } else {
                    kill = true
                }
            }
            // The original clears OITF_USED on this entry after the event,
            // even if a handler replaced the timer in it.
            if kill {
                osirisTimers.clearUsed(index)
            }
        }
    }

    /// Osiris_CancelTimer (OsirisLoadandBind.cpp:2471). As in the original,
    /// it does not check OITF_USED: a handle that still names its entry
    /// cancels it again.
    mutating func osirisCancelTimer(_ handle: Int32, level: Level) {
        osirisCancelTimer(handle) { world, target, event in
            world.osirisSendTimerEvent(target, event, level: level)
        }
    }

    mutating func osirisCancelTimer(
        _ handle: Int32,
        send: (inout GameWorld, OsirisTimerTarget, ScriptEvent) -> Void
    ) {
        let slot = OsirisTimers.slot(of: handle)
        guard slot < OsirisTimers.capacity,
              osirisTimers.entries[slot].handle == handle
        else {
            return
        }
        osirisTimers.clearUsed(slot)
        send(
            &self,
            osirisTimers.entries[slot].owner.target,
            .timerCancel(handle: handle, detonated: false)
        )
    }

    /// Osiris_CancelTimerID (OsirisLoadandBind.cpp:2515).
    mutating func osirisCancelTimerID(_ id: Int32, level: Level) {
        guard let timer = osirisTimers.entries.first(where: {
            $0.isUsed && $0.id == id
        }) else {
            return
        }
        osirisCancelTimer(timer.handle, level: level)
    }

    /// The event call for a timer owner. An object timer goes to the object
    /// only while it exists (OsirisLoadandBind.cpp:2322, :2490).
    private mutating func osirisSendTimerEvent(
        _ target: OsirisTimerTarget,
        _ event: ScriptEvent,
        level: Level
    ) {
        switch target {
        case let .trigger(number):
            osirisCallTriggerEvent(number, event, level: level)
        case .level:
            osirisCallLevelEvent(event, level: level)
        case let .object(handle):
            osirisCallEvent(handle, event, level: level)
        }
    }
}

private extension OsirisTimer.Owner {
    var target: OsirisTimerTarget {
        switch self {
        case let .object(handle): .object(handle)
        case let .trigger(number): .trigger(number)
        case .level: .level
        }
    }
}
