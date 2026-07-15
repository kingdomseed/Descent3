# Descent 3 revival

This repository is the working home for a complete Apple-native Descent 3 revival: a new Swift and Metal game, native multiplayer and replay, and an integrated creator suite capable of building and publishing new levels and campaigns. Phase 10 is the complete version 1.0 release; Phase 11 is post-1.0 visual and experiential development.

The selected product is an Apple-native semantic translation and modernization:

- the Swift 6.4 compiler toolchain in Swift 6 language mode for host code, using Xcode 27 beta until the stable Xcode 27 release;
- MSL and direct Metal 4 graphics;
- Apple Silicon player applications for macOS 26+, iOS 26+ and iPadOS 26+, using Metal 4 on Apple GPU family 7 or later, with the editor and importer remaining Mac-only;
- one-way conversion from owned retail formats into canonical content;
- an explicit source-faithful old/new variable-time handoff followed by one measured scheduler decision, evidence-grown behavior authoring, new saves, replay, and modern multiplayer;
- one canonical content and world model shared by the Mac player, universal iPhone/iPad player, editor, validator and publisher, with separately owned runtime and document values;
- no C++ runtime, OpenGL, SDL, Wine, Game Porting Toolkit runtime, native Osiris module, backward export, or original network contract.

Functional completeness is mandatory. The translation preserves reachable game and creative semantics while replacing old ABIs, platform APIs, formats, dialogs, protocols, and implementation baggage. Read [REVIVAL.md](REVIVAL.md) for the charter, [Source translation discipline](docs/revival/source-translation.md) for file accounting, [Functional completeness](docs/revival/functional-completeness.md) for scope, and [AGENTS.md](AGENTS.md) for binding implementation rules.

## Repository state

The repository currently contains the GPL-released [`DescentDevelopers/Descent3`](https://github.com/DescentDevelopers/Descent3) tree at pinned source commit `156cba8aafd997d27deb0902ba6026bcdcc1cfaf`, local exploratory fixes, verified retail-data tooling, and the new architecture documents.

The C++ tree is the systematic translation source, and the retained runnable build is one historical reference evidence source, but neither is linked into the new product. They stay through Phase 10 until every relevant source file and every runtime, campaign, editor, DALLAS and Osiris behavior, multiplayer, replay, and utility row is implemented and verified, deliberately replaced, or explicitly excluded.

Phase 1 creates the `D3Import`, `RevivalMac`, universal `RevivalMobile`, and `RevivalEditor` products. `RevivalCore` and `RevivalMetal` name code-ownership boundaries whose build-target shape follows the first real code. D3Import converts the complete Training D3L into canonical content on Mac; RevivalMac, RevivalMobile and RevivalEditor load separately owned copies of the resulting complete Training `Level` through the same resident-world path. One selected room is the first rendering and editing acceptance slice.

Each document under `docs/revival/` declares whether it is a binding contract, an execution record, or non-normative evidence. [AGENTS.md](AGENTS.md) and the accepted contracts govern current work. [Historical discovery](docs/revival/discovery.md) and the [legacy M4 build procedure](docs/revival/macos-arm64-build.md) preserve evidence without defining the product architecture.

## Retail content

No retail game assets are included. Original and converted retail content stays outside Git. Version 1.0 requires each user to own and import a supported prepared retail installation on Mac; RevivalMobile consumes only the transferred canonical package and therefore still requires access to that Mac conversion path. Version 1.0 does not promise raw-disc preparation, additional storefront profiles, mobile retail parsing or bundled replacement assets. The verified local source profile uses owned original CDs, Mercenary, and the official 1.4 update. See [Retail data and provenance](docs/revival/retail-data.md) and [One-way content pipeline](docs/revival/content-pipeline.md).

## Historical upstream documents

[BUILD.md](BUILD.md), [USAGE.md](USAGE.md), [CHANGELOG.md](CHANGELOG.md), and [THIRD_PARTY.md](THIRD_PARTY.md) describe the retained community C++ engine. They remain useful for archaeology and license provenance but do not define the Swift/Metal product workflow. [Legacy source artifacts](legacy/README.md) and retained C++ maintenance tools are likewise evidence, not Revival implementation guidance.

## License

The released source is GPL-3.0-or-later as stated in its source headers. New project code derived from or translated from that source will remain compatible with GPL-3.0-or-later. Retail media keeps its original ownership and is not covered by the code license.
