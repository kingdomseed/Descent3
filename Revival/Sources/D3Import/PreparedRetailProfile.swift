// SPDX-License-Identifier: GPL-3.0-or-later

struct PreparedRetailFile: Codable, Equatable, Sendable {
    let relativePath: String
    let byteCount: Int
    let sha256: String
}

struct PreparedRetailProfile: Codable, Equatable, Sendable {
    let identifier: String
    let files: [PreparedRetailFile]

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
        ]
    )
}
