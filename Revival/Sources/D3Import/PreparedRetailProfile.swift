// SPDX-License-Identifier: GPL-3.0-or-later

struct PreparedRetailFile: Codable, Equatable, Sendable {
    let relativePath: String
    let byteCount: Int
    let sha256: String
}

/// One level of a prepared mission, with the provenance evidence recorded
/// for its exact source.
struct PreparedRetailLevel: Codable, Equatable, Sendable {
    let key: String
    /// The level checksum the pinned source computes for this exact level
    /// file (LevelSource.referenceChecksum).
    let referenceChecksum: String?
    /// The PageInAllData working set measured for this level
    /// (DependencyManifest.historicalEagerBaseline).
    let historicalEagerBaseline: EagerDependencyBaseline?
}

/// A mission the profile can import: its library, its .msn descriptor, and
/// its levels in LEVEL order.
struct PreparedRetailMission: Codable, Equatable, Sendable {
    let key: String
    let archivePath: String
    let descriptorName: String
    let levels: [PreparedRetailLevel]
}

struct PreparedRetailProfile: Codable, Equatable, Sendable {
    let identifier: String
    let files: [PreparedRetailFile]
    /// The base libraries in cfile search order (cfile/cfile.cpp:264: the
    /// most recently opened library is searched first). A mission's library
    /// is searched before them.
    let baseArchiveSearchOrder: [String]
    /// The table file and the table overlay, with their libraries.
    let tableArchive: String
    let tableName: String
    let overlayArchive: String
    let overlayName: String
    let missions: [PreparedRetailMission]

    /// The mission and level a scope names: a mission key imports its first
    /// level, and a level key imports that level.
    func importTarget(
        scope: String
    ) -> (mission: PreparedRetailMission, levelIndex: Int)? {
        for mission in missions {
            if mission.key == scope, !mission.levels.isEmpty {
                return (mission, 0)
            }
            if let index = mission.levels.firstIndex(where: { $0.key == scope }) {
                return (mission, index)
            }
        }
        return nil
    }

    static let training = PreparedRetailProfile(
        identifier: "descent3.cd-1.4-mercenary.training.v1",
        files: [
            .init(
                relativePath: "d3.hog",
                byteCount: 194_030_423,
                sha256: "a0f1cb2c1a73da828a5fd4e80d6544b63da04e177dc2b894d9e6418296bc24c6"
            ),
            .init(
                relativePath: "extra.hog",
                byteCount: 476_566,
                sha256: "005f035b83d7523e883b4d1b4a103367ac3b7ef45977f18c1ffc89e2f8964df9"
            ),
            .init(
                relativePath: "extra13.hog",
                byteCount: 278_329,
                sha256: "bd257272cbb436b78cacdc8e8ae8f8260922cd023bae88ff848ee89b90807187"
            ),
            .init(
                relativePath: "merc.hog",
                byteCount: 212_406_907,
                sha256: "29c9188697aafc8b2c33ebe8c9a56f2bc0e8742860def769a747a39e29b6350c"
            ),
            .init(
                relativePath: "missions/training.mn3",
                byteCount: 5_059_244,
                sha256: "fc1d81921cc4b2618e441b7b9d08c4bcb5cff90731be1bfa6f3a7b054fc0cb54"
            ),
            .init(
                relativePath: "ppics.hog",
                byteCount: 5_611_278,
                sha256: "6e911c554b42a04a4ddb2ad24676a62ce7026a07ed74e54043d5bd459dea2546"
            ),
        ],
        baseArchiveSearchOrder: [
            "extra13.hog", "merc.hog", "extra.hog", "d3.hog",
        ],
        tableArchive: "merc.hog",
        tableName: "Table.gam",
        overlayArchive: "extra13.hog",
        overlayName: "extra.gam",
        missions: [
            .init(
                key: "descent3.mission.pilot-training",
                archivePath: "missions/training.mn3",
                descriptorName: "training.msn",
                levels: [
                    .init(
                        key: "descent3.level.training-mission",
                        referenceChecksum: "6db74a2eb0c563de4eb11e6d4e91e59c",
                        historicalEagerBaseline: .init(
                            textureCount: 232,
                            soundCount: 115,
                            modelCount: 88,
                            lightmapInfoCount: 2_531
                        )
                    ),
                ]
            ),
        ]
    )
}
