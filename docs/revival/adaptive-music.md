# Adaptive music

- Status: accepted, amended
- Date: July 15, 2026
- Authority: binding adaptive-score runtime, import, persistence, and authoring contract

## Historical evidence

Descent 3 music is a stateful adaptive-score system, not a playlist. OMF theme files describe regions, streams, loops, branches, theme roles, and transitions. The historical sequencer can align transitions to musical boundaries. Gameplay and DALLAS behaviors request music-region changes, and save files preserve enough logical region state to resume the score.

The released source also contains abandoned or inactive mood inputs. `tMusicSeqInfo` declares damage, shield, kill, terrain, and hostile state, but the active game loop supplies a smaller subset and some selection logic is commented out. The native design reconstructs behavior proven active or deliberately approved in the translation ledger; unused fields do not become requirements by existing in a struct.

Primary evidence:

- [`music/omflex.cpp`](../../music/omflex.cpp) parses the current OMF instruction syntax;
- [`music/sequencer.cpp`](../../music/sequencer.cpp) implements regions, branches, loops, and clean transitions;
- [`Descent3/d3music.cpp`](../../Descent3/d3music.cpp) maps gameplay and region state into sequencer requests;
- [`scripts/DallasFuncs.cpp`](../../scripts/DallasFuncs.cpp) exposes music-region behavior actions;
- [`Descent3/gamesave.cpp`](../../Descent3/gamesave.cpp) and [`Descent3/loadstate.cpp`](../../Descent3/loadstate.cpp) persist and restore logical region state.

Historical utilities are evidence, not the product model. `legacy/musicutils` targets an older syntax, and `DallasStrmAudioDlg` selects and previews streams rather than proving a complete current-format OMF editor.

## Native decision

`D3Import` parses required retail OMF definitions and their referenced audio once. It writes canonical `AdaptiveScore` data and normalized canonical audio. No OMF parser, legacy stream decoder, or historical sequencer runs in the player or editor.

`RevivalCore` owns deterministic logical score state:

- score and region `ContentKey` values, plus the smallest semantic revision once public saves or packages require one;
- requested theme role drawn from the surface established by import of the retail OMF themes. The OMF library vocabulary includes intro, idle, combat, transition, and death roles, but the pinned game selector actively requests only idle and death; where combat switching occurs it is driven by register logic inside the theme data rather than by a five-wide C++ request surface. Import records the roles each supported theme actually uses; authoring may expose the full native set afterward;
- pending logical transition intent;
- gameplay-derived inputs and explicit elapsed-time or final-scheduler timers that the approved score rules use.

`RevivalMac` and `RevivalEditor` each own an `AVAudioEngine` instance and call the same concrete project-owned score-presentation code directly. RevivalMac consumes typed gameplay score commands; RevivalEditor uses the same scheduling, fade, interruption, and recovery code for preview. Decoded buffers, sample clocks, and audio-device state remain presentation ownership and never change authoritative gameplay state.

The canonical model stays narrow. It represents regions, named theme roles, stream references (historical OSF beds with ACM payloads, normalized at import), loop ranges, transition rules, and musical alignment needed by imported and newly authored scores. It is not a general digital-audio workstation, MIDI engine, or second behavior language. The historical save baseline stores one logical region index. Native saves begin with that minimum and add only state proven to affect future logical selection.

## Behavior contract

The first translated behavior chains call named typed operations to select a score region and request a supported score state. The same operations form the creator-facing score domain surface. Scope and authority are explicit where the source path requires them. A stock translation records whether an original request targeted one player, the authoritative session, or every participant.

The historical region action contains an ambiguity between its “specific player” comment and the multiplayer state value it submits. The translation ledger must resolve that case explicitly. The new language does not reproduce accidental zero-value or recipient conventions.

Historical interval score logic is characterized with the old `Frametime` and pre-update `Gametime`, preserving the source's later post-cap time update, pause ordering, and rate behavior. Adaptive-score gameplay work arrives after Phase 3 and implements the selected final scheduler directly. Presentation scheduling always uses the audio sample clock; it never decides gameplay state.

## Persistence and replay

A save records only the logical state required to resume coherently:

- adaptive-score key and any applicable released-format semantic revision;
- current logical region;
- requested role only when it changes future logical selection;
- pending transition intent only when it changes future logical selection;
- timers or counters only when they affect continuation, expressed in the selected final simulation model.

Saves do not contain audio-engine nodes, decoder state, sample buffers, device state, instruction pointers, or exact playback position. On load, `RevivalMac` starts from the declared resume policy at a valid musical boundary.

Replay records authoritative logical score commands in simulation order and verifies logical score state. Audio-boundary outcomes are excluded from the current replay schema; a later replay-presentation contract may add them without making them gameplay-authoritative. Exact waveform timing is not part of the canonical gameplay hash.

## Authoring

`RevivalEditor` provides adaptive-score authoring inside the existing application. A creator can:

- import supported modern audio;
- define regions and theme roles;
- assign loops and transition material;
- choose immediate, clean-boundary, or declared musical transitions;
- bind behavior commands and campaign defaults;
- preview state changes and interruption recovery;
- validate missing streams, unreachable regions, invalid loops, and transition dead ends;
- publish the score and its complete audio dependency closure.

This is a native creator workflow. It does not write OMF, reopen retail archives, or preserve the original utilities.

## Verification

Import tests cover the exact OMF constructs present in each supported source profile plus malformed bounds, unknown instructions, missing streams, invalid branches, and loop failures. Runtime tests cover deterministic logical selection, region commands, transition intent, save and load, replay, interruption, device changes, and missing optional output devices. Audio tests verify clean scheduling within declared sample tolerances without making presentation timing authoritative.

The functional-completeness ledger separates import, runtime logic, native scheduling, behavior commands, persistence, authoring, validation, playtest, and publishing. “Music works” is not a complete row.
