# Test-driven development

- Status: accepted, clarified
- Date: July 16, 2026
- Authority: binding implementation and review protocol

## Non-negotiable rule

Every new or changed production behavior begins with one focused automated test that fails before its production implementation is written. The failure must demonstrate the missing behavior or reproduced defect for the intended reason. Production code then makes that test pass with the smallest direct change.

This rule covers gameplay, import, validation, canonical content, behaviors, saves, replay, renderer state, shaders and images, editor commands, multiplayer, security limits, application integration, packaging, and performance contracts. A test written after the implementation is not test-driven development and does not satisfy this protocol.

Red evidence does not require a separate commit. The durable change record contains the focused command and the salient expected failure, followed by the green command and result. Put that evidence in the pull-request description or commit message body so it remains attached to the change. An agent handoff may repeat the record but may not replace it. Reviewers must be able to distinguish a real red step from an unrelated broken build.

Shared branches remain green. Continuous integration verifies the final state; it cannot prove the historical order and does not replace the recorded red evidence.

## The cycle

Work advances one observable contract at a time:

1. **Choose:** Name the ledger row, defect, invariant, or external boundary and the next behavior it lacks.
2. **Red:** Write the smallest test that expresses that behavior. Run the narrowest useful command. Confirm that it fails because the behavior is absent or wrong.
3. **Green:** Write the least production code that makes the focused test pass. Do not add speculative options, abstractions, or adjacent behavior.
4. **Refactor:** Simplify names, data, control flow, tests, and duplication while the focused test remains green. Refactoring does not change observable behavior.
5. **Integrate:** Run the directly affected suite, then the broader milestone checks required by the owning document.

If the new test passes before production code changes, it does not prove a red step. The behavior already exists, the assertion is too weak, or the test is aimed at the wrong boundary. If it fails because of a typo, missing fixture, unavailable tool, unrelated test, or environment error, repair the test setup until it fails for the intended product reason.

When existing reachable behavior lacks protection before a behavior-neutral refactor, prove the new test's sensitivity with a temporary controlled mutation or a reintroduced reproduction of the defect. Observe the intended failure, restore green, and only then refactor. The mutation does not enter shared history. A characterization test that has never demonstrated that it can detect the relevant mistake is not red evidence.

Do not write a batch of speculative failing tests for a future subsystem. Finish the smallest red-green-refactor slice first. A table-driven test is appropriate when its cases exercise the same rule through the same production path.

For source translation, the observable contract names the historical entry point, relevant data flow or order, and the result being preserved. A test protects that semantic result, not C++ line shape, private decomposition, or every legacy defensive branch. The separate source-translation ledger supplies file and range accounting; test count does not.

## What counts as red

A valid red result is a focused observation of the missing contract, such as:

- an assertion that reports the wrong canonical value or state transition;
- a parser or validator accepting input it must reject;
- a save, replay, editor, or package round trip losing required meaning;
- a controlled render-state or image comparison showing the missing visual result;
- an untrusted network or media input escaping its required bound;
- a build, signing, helper, or package check proving a missing product artifact;
- a reproducible benchmark or allocation test exceeding an already ratified budget.

An intentional compile failure may be the first red result when a focused test specifies a missing typed API. The missing symbol or conformance must be the expected failure. A generally broken target, missing SDK, unavailable retail file, or unrelated failure never counts.

## Test value gate

A test belongs in the project only when all of these are true:

1. It protects a ledgered capability, reproduced defect, declared invariant, or reachable external boundary.
2. It exercises the production code path that the player, editor, importer, publisher, host, or supported tool actually invokes.
3. It can fail because project-owned behavior regressed, not merely because an Apple or Swift API works as documented.
4. It checks the smallest stable contract that owns the behavior.
5. It adds distinct protection that a cheaper existing test does not already provide.
6. It is deterministic, bounded, and maintainable enough to run at the appropriate development or integration cadence.

If those conditions are not met, do not write the test. Delete an unreachable branch instead of constructing a test-only route to it. Delete a test when its production contract is deliberately removed. Coverage percentages, uncovered lines, reviewer habit, and hypothetical future implementations are not reasons to retain code or add tests.

Code coverage is a diagnostic, never a target or merge gate. An uncovered path triggers a decision: test it when a supported product route can reach it and its outcome matters; delete it when no supported route can reach it; add nothing when an existing test already protects the same contract.

Malformed files, hostile packets, corrupted saves, device loss, cancellation races, and similar boundary states are reachable because supported production boundaries can receive them. They deserve tests even when an honest user interface would not generate them.

Failure injection constructs only a state that the supported production entry point can receive. A seam may choose when a real cancellation, clock, filesystem, process, device, or network event occurs; its callback may not mutate permissions, flags, ownership, or trusted internal state that the production callback never changes merely to force a recovery branch. “Arbitrary failure” is not itself a product contract.

A malformed or hostile fixture remains otherwise valid through the target boundary and asserts the exact intended error and relevant context. Removing the target check must make that test fail for the claimed reason; an earlier or broader rejection does not prove the contract.

## No test-only architecture

Tests do not justify production pathways that the product never runs. Do not add a protocol, dependency-injection container, wrapper, public setter, alternate initializer, mock mode, test flag, subclass seam, virtual filesystem, renderer backend, or service layer solely to make a test convenient.

A narrow seam is allowed when production already crosses a nondeterministic boundary such as monotonic time, randomness, filesystem promotion, process execution, audio-device completion, or network delivery. The seam controls that real boundary and remains smaller than the behavior it makes deterministic. This is the same abstraction gate defined in [Engineering principles](engineering-principles.md).

Prefer plain values and direct functions. Import tests feed bytes to the production parser. Simulation tests step the production world. Editor tests execute production commands. Renderer tests validate production extraction and controlled Metal output. Application tests use the real composition at the narrowest reliable level. Do not test an imitation of the product.

Do not duplicate the same assertion at every layer. Add an integration test only when composition, ownership, serialization, framework adaptation, process boundaries, or GPU execution can fail independently of the focused lower-level contract.

## Special cases

### Refactoring and deletion

Refactoring is the third step of an already green cycle. Existing focused tests protect it; inventing a failing assertion for unchanged behavior would be dishonest. A change described as refactoring must not alter an observable contract. If it does, that part starts with a new red test.

Deleting dead or unreachable production code and its obsolete tests is simplification, not a new behavior. Prove the path is unreachable from supported production entry points; do not preserve it by manufacturing test coverage.

### Rendering and Apple frameworks

Test project-owned render extraction, material choice, resource bounds, pass ordering, shader results, and controlled images. Do not unit-test Metal, MetalKit, AppKit, UIKit, AVFoundation, AVAudioSession or GameController themselves. Test the project's assumptions and adaptation at the real boundary, including target-specific composition without introducing a generic platform seam.

### Performance

An optimization starts with a reproducible release-build measurement that misses a ratified budget or demonstrates the regression. Functional tests remain green throughout. A microbenchmark with no connection to a measured production path does not justify optimization code.

### Documentation and planning

Documentation-only changes do not invent a failing product test. Run available link, consistency, format, or example checks when the document has an executable contract. The recursive demand to “test the test” stops at the smallest existing test infrastructure contract.

The initial test runner and fixture bootstrap may be created to enable the first red test. Keep it smaller than the behavior it will test and prove it by observing the intended red and green results. Do not build a general harness before a concrete production contract needs it.

### Disposable research

A bounded nonshipping spike may precede the production cycle when the team does not yet know enough to state the contract—for example, to inspect an unknown retail field, capture reference timing, test a Metal API, or falsify a loading assumption.

The spike is clearly marked as research, never enters a product target, creates no public interface, and is deleted or archived as evidence when the question is answered. Its result is a source note, fixture, capture, measurement, or proposed contract. Shipping implementation still begins with the focused red test. Research is not a loophole for implementing production code first.

### Manual evidence

Manual play, physical-device checks, Metal captures, Instruments traces, and accessibility review supplement automation where they observe something automation cannot. On iPhone and iPad this includes orientation and safe areas, UIKit lifecycle, audio routes and interruptions, memory warnings, thermal behavior, virtual/physical controller handoff and local-network permission. Simulator evidence cannot replace these device effects. Manual evidence does not replace the first failing automated test for project-owned behavior. When an operating-system effect cannot be automated reliably, the red test covers the nearest project-owned decision or command and the manual evidence covers the final integration.

If no credible automated red can be stated at a known project-owned boundary, stop production implementation and clarify the contract. Use a bounded research spike only when the boundary itself is still unknown; once known, difficulty testing a design is not permission to implement it first.

## Review gate

A production-behavior change is not reviewable without:

- the protected ledger row, defect, invariant, or boundary;
- the focused red command and expected failure;
- the focused green command and pass;
- the affected-suite result;
- any required image, device, performance, security, or end-to-end evidence.

Reviewers reject implementation-first tests, tests that passed before the change, wrong-reason failures, flaky tests, tests coupled only to private implementation shape, and production seams with no production purpose.

Reviewers also reject demands for speculative tests. A requested test must name the supported production entry point, reachable state, observable contract, and distinct regression it prevents. “Coverage,” “defensive,” “best practice,” and “we may need it later” are insufficient.

A request based on arbitrary failure is not a finding unless it identifies the supported production event that reaches the state and the accepted outcome it violates.

For existing behavior, a blocking request for new coverage must also identify a plausible defect or mutation the test will detect and why the current suite would miss it. The new test must demonstrate that sensitivity before it is retained.

No agent, review, skill, contributor guide, deadline, phase, or local convention may waive or weaken this protocol. Changing it requires an explicit user-approved amendment to the accepted project documents.
