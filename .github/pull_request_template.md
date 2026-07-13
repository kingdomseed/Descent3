## Pull Request Type
<!-- Please select which type of change this most aligns with. If more than one type fits, please select multiple. -->

- [ ] GitHub Workflow changes
- [ ] Documentation or Wiki changes
- [ ] Build and Dependency changes
- [ ] Runtime changes
  - [ ] Render changes
  - [ ] Audio changes
  - [ ] Input changes
  - [ ] Network changes
  - [ ] Other changes

### Description
<!-- Below this comment, add a brief overview of the changes introduced by this pull request. Include any relevant context or background information. -->

### Related Issues
<!-- If this pull request will fix an issue, please link it below this comment. Say something like, "Fixes #83" where #83 is the issue number. -->

### TDD Evidence
<!-- Required for every new or changed production behavior. Use N/A only for documentation, deletion, or a proven behavior-neutral refactor. Test bootstrap names the concrete production contract it enables and records that contract's red and green results in this change. -->

- Contract, ledger row, defect, invariant, or reachable boundary:
- Supported production path:
- Red command and intended failure observed before implementation:
- Green command and result:
- Affected suite and result:
- Additional image, device, package, security, or performance evidence:
- N/A reason, if permitted:

### Screenshots (if applicable)
<!-- Please add any relevant screenshots or images to show the changes made, if applicable. Remove this section if it does not apply. -->

### Checklist
<!-- Please review the following checklist before submitting your pull request -->

- [ ] I have tested my changes locally and verified that they work as intended.
- [ ] Each production behavior started with a focused test that failed for the intended reason before implementation.
- [ ] Each retained test protects a reachable production path and a distinct observable contract.
- [ ] I did not add speculative tests or production architecture solely for tests.
- [ ] I have documented any new or modified functionality.
- [ ] I have reviewed the changes to ensure they do not introduce any unnecessary complexity or duplicate code.
- [ ] I understand that by submitting this pull request, I am agreeing to license my contributions under the project's license.

### Additional Comments
<!-- Add any additional comments, notes, or concerns that you want to communicate to us. -->
