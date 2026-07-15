# Preserved future opportunities

- Status: accepted
- Date: July 15, 2026
- Authority: preservation record; not a version 1.0 product-scope contract

## Purpose

Preserve two kinds of later possibility without silently losing either: source-evidenced ideas that were dormant, incomplete, disabled, or unsupported in the shipped game, and working historical capabilities deferred only through an explicit approved product-scope amendment.

The functional-completeness contract still governs version 1.0. A reachable, functioning player or creator capability cannot move here merely to avoid implementation. It may enter only through an explicit user-approved scope amendment that records the working historical capability, the reason for deferral, and the affected ledger disposition. A dormant or incomplete idea may enter when current source or retail evidence does not establish a working historical capability, and the register must state what evidence remains unresolved. Absence of proof is not a permanent exclusion: a final excluded disposition still requires evidence meeting the functional ledger's standard or an explicit approved product-scope amendment. Moving any entry back into product scope requires a deliberate product amendment with an observable contract, owner, roadmap phase, and verification.

Each entry records its category, evidence, apparent intent or working outcome, known limitation or deferral reason, and the trigger that would justify reconsideration. Exclusion from the 1.0 native baseline does not erase the idea or its provenance.

## Initial register

| ID | Category | Preserved idea | Historical evidence and limitation | Evidence status | Reconsideration trigger |
| --- | --- | --- | --- | --- | --- |
| F-001 | Dormant or incomplete | Ambient-life simulation | `Descent3/aiambient.cpp` retains an empty runtime `DoFrame(void) {}` while `editor/levelkeypad.cpp` retains authoring and serialization surfaces. The shipped source does not currently prove a working runtime capability. | Source is incomplete; retail behavior remains unverified. | Retail observation or creator research establishes the intended observable behavior and a later product decision selects a native runtime and authoring contract. |
| F-002 | Dormant or incomplete | Per-level ship selection | `Descent3/Mission.h` declares `LVLFLAG_SHIPSELECT`, but the pinned source never sets or reads it. Mission-wide default and allowed-ship declarations remain required version 1.0 capability. | Source field is dormant; retail behavior remains unverified. | A later campaign-design need or contrary retail evidence justifies per-level selection as a deliberate native addition with save, replay, editor, and multiplayer semantics. |
| F-003 | Dormant or incomplete | Historical bumpmap and ship environment-mapping concepts | The retained D3D-only paths are dead and the active hardware abstraction reports bumpmapping unsupported. They are excluded from the source-faithful 1.0 renderer baseline. | The retained source backend is conclusively dead; a new Metal material capability is a separate post-1.0 decision. | Post-1.0 visual development identifies a real material need and selects one modern Metal capability without reviving the dead backend path. |
| F-004 | Dormant or incomplete | Automatic unattended attract mode | `Descent3/menu.cpp` and `Descent3/demofile.cpp` provide manual demo selection and a user-selected repeat loop, but the pinned source does not show a menu-idle timer or automatic demo rotation. The working manual playback and repeat capability remains required under `P-036`. | Source does not establish the automatic mode; retail behavior remains unverified. | Later interface research or contrary retail evidence identifies a useful unattended presentation mode and defines its content-selection, input-exit, audio, accessibility, and creator contracts. |

## Preservation rules

- Keep exact source paths, symbols, and current evidence with each entry.
- Do not create production types, flags, schemas, tests, or placeholder UI for an opportunity before it becomes accepted scope.
- Do not classify a working feature as future merely because it appears late in the roadmap or is expensive. A working capability needs an explicit user-approved scope amendment, its functional-ledger disposition, and a `Working capability deferred by amendment` category entry.
- When an opportunity is adopted, remove it from this register and add or amend the owning functional and source-translation rows in the same change.
