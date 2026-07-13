# Descent 3 revival

This repository is the working home for a complete Apple-native Descent 3 revival: a new Swift and Metal game, native multiplayer and replay, and an integrated creator suite capable of building and publishing new levels and campaigns.

The selected product is a clean rewrite:

- Swift 6.3 host code;
- MSL and direct Metal 4 graphics;
- Apple Silicon and macOS 26 or later;
- one-way conversion from owned retail formats into canonical content;
- a fixed 120 Hz simulation, typed behavior language, new saves, replay, and modern multiplayer;
- one native project model shared by the player, editor, validator, and publisher;
- no C++ runtime, OpenGL, SDL, Wine, Game Porting Toolkit runtime, native Osiris module, backward export, or original network contract.

Functional completeness is mandatory. The rewrite keeps the game and creative capabilities while discarding old ABIs, formats, dialogs, protocols, and implementation baggage. Read [REVIVAL.md](REVIVAL.md) for the charter, [Functional completeness](docs/revival/functional-completeness.md) for scope, and [AGENTS.md](AGENTS.md) for binding implementation rules.

## Repository state

The repository currently contains the GPL-released [`DescentDevelopers/Descent3`](https://github.com/DescentDevelopers/Descent3) tree at pinned source commit `156cba8aafd997d27deb0902ba6026bcdcc1cfaf`, local exploratory fixes, verified retail-data tooling, and the new architecture documents.

The C++ tree is temporary historical evidence and is never linked into the new product. It stays through Phase 10 until every runtime, campaign, editor, DALLAS and Osiris behavior, multiplayer, replay, and utility row is implemented and verified, replaced, or explicitly excluded, with no unresolved product question that still depends on the active tree.

Phase 1 creates `D3Import`, `RevivalCore`, `RevivalMetal`, and `RevivalMac`. Phase 2 adds `RevivalEditor`, which grows with every gameplay milestone instead of arriving after the game is finished.

## Retail content

No retail game assets are included. Original and converted retail content stays outside Git. The verified local source profile uses owned original CDs, Mercenary, and the official 1.4 update. See [Retail data and provenance](docs/revival/retail-data.md) and [One-way content pipeline](docs/revival/content-pipeline.md).

## Historical upstream documents

[BUILD.md](BUILD.md), [USAGE.md](USAGE.md), [CHANGELOG.md](CHANGELOG.md), and [THIRD_PARTY.md](THIRD_PARTY.md) describe the retained community C++ engine. They remain useful for archaeology and license provenance but do not define the Swift/Metal product workflow.

## License

The released source is GPL-3.0-or-later as stated in its source headers. New project code derived from or translated from that source will remain compatible with GPL-3.0-or-later. Retail media keeps its original ownership and is not covered by the code license.
