## Pull Request Type
<!-- Select every affected product or evidence boundary. -->

- [ ] Revival source accounting, evidence, or documentation
- [ ] D3Import or canonical content
- [ ] RevivalCore simulation or behavior
- [ ] RevivalMetal rendering or resource lifetime
- [ ] RevivalMac application, input, audio, or media
- [ ] RevivalMobile application, touch/controller input, audio session, storage, lifecycle, device, or distribution
- [ ] RevivalEditor authoring, validation, playtest, or publishing
- [ ] Multiplayer, selected network/service boundary, security, or replay
- [ ] Retained C++ reference tree or historical tooling
- [ ] Build, dependency, or GitHub workflow

### Description
<!-- Below this comment, add a brief overview of the changes introduced by this pull request. Include any relevant context or background information. -->

### Related Issues
<!-- If this pull request will fix an issue, please link it below this comment. Say something like, "Fixes #83" where #83 is the issue number. -->

### TDD Evidence
<!-- Required for every new or changed production behavior. Use N/A only for documentation, proven dead or unreachable deletion, or a proven behavior-neutral refactor. Test bootstrap names the concrete production contract it enables and records that contract's red and green results in this change. -->

- Functional-completeness row, defect, invariant, or reachable boundary:
- Functional-row state transitions and whether capability or milestone closure is claimed:
- Current-plan packet, lane, checkpoint, packet owner, and integration owner:
- Legacy source files, symbols, and source-translation dispositions:
- Source-row state transitions and whether island or milestone closure is claimed:
- Observable dependency island and source map:
- Bounded fog-of-war preflight: inspected entry points or areas, newly exposed dependencies or unknowns, and plan or ledger corrections, or `no new gap found`:
- Core logic versus wiring or mechanical movement:
- Historical observable baseline:
- Deliberate native differences:
- Supported production path:
- Red command and intended failure observed before implementation:
- Green command and result:
- Affected suite and result:
- Applicable build, launch, integration, or other evidence claims not recorded above, with exact command, input, configuration, and result:
- Nonexecuted, deleted, weakened, or replaced tests with approved disposition and replacement or removal evidence:
- Source-fidelity, architecture-and-scope, tests-and-evidence, and simplicity-and-maintainability findings and resolution:
- Documentation continuity: canonical files and rows reconciled, or `no documentation change required` with checked owners; proposed current-plan state or next-packet update and integration-owner disposition:
- Image, device, package, security, or performance evidence:
- N/A reason, if permitted:

### Screenshots (if applicable)
<!-- Please add any relevant screenshots or images to show the changes made, if applicable. Remove this section if it does not apply. -->

### Checklist
<!-- Please review the following checklist before submitting your pull request -->

- [ ] The evidence above names the exact commands and results supporting each claimed behavior or milestone.
- [ ] Each production behavior started with a focused test that failed for the intended reason before implementation, or the TDD evidence section documents why this change qualifies for N/A.
- [ ] Each retained test protects a reachable production path and a distinct observable contract.
- [ ] I did not add speculative tests or production architecture solely for tests.
- [ ] I updated every affected source disposition and recorded deliberate differences.
- [ ] I named the current-plan packet and checkpoint and gave the integration owner the proposed landed-state and next-packet update without creating a competing plan.
- [ ] I applied the documentation-continuity check at this material boundary, routed each durable fact to its existing canonical owner, and did not add a parallel plan, findings file, progress journal, or agent ledger.
- [ ] Every source row required by a claimed island has reached its required closure state; each functional row has the evidence and state appropriate to this slice, and is terminal when complete capability or milestone closure is claimed.
- [ ] I did not present build, launch, or a synthetic fixture as proof of behavior it did not exercise.
- [ ] No stub, stand-in constant, disabled production path, required-test skip, or workaround comment is serving in place of the claimed contract.
- [ ] I kept one production path and did not add speculative abstraction.
- [ ] Where applicable, I validate untrusted input once at its boundary rather than duplicating impossible-state checks inside trusted code.
- [ ] I have documented any new or modified functionality.
- [ ] I have reviewed the changes to ensure they do not introduce any unnecessary complexity or duplicate code.
- [ ] I understand that by submitting this pull request, I am agreeing to license my contributions under the project's license.

### Additional Comments
<!-- Add any additional comments, notes, or concerns that you want to communicate to us. -->
