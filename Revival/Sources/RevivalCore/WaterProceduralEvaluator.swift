// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

struct WaterProceduralEvaluator: Sendable {
    private static let dimension = 128
    private static let pixelCount = dimension * dimension

    private let sourceRGBA8: [UInt8]
    private let definition: WaterProceduralDefinition
    private var current = [Int16](repeating: 0, count: pixelCount)
    private var previous = [Int16](repeating: 0, count: pixelCount)
    private var output = Data(repeating: 0, count: pixelCount * 4)
    private var lastVisualTick: Int?

    init(
        image: CanonicalRGBA8Image,
        definition: WaterProceduralDefinition
    ) {
        precondition(
            image.width == Self.dimension
                && image.height == Self.dimension
                && image.rgba8.count == Self.pixelCount * 4
                && definition.lightingShift < 16
                && definition.dampingShift < 16
                && definition.elements.count <= 64
                && definition.evaluationIntervalSeconds.isFinite
                && definition.evaluationIntervalSeconds >= 0,
            "Water evaluators require validated canonical inputs."
        )
        sourceRGBA8 = [UInt8](image.rgba8)
        self.definition = definition
    }

    mutating func rgba8(visualTick: Int) -> Data {
        if lastVisualTick == visualTick { return output }

        let elapsedTicks = lastVisualTick.map { visualTick - $0 } ?? 1
        let stepCount = (1...8).contains(elapsedTicks) ? elapsedTicks : 1
        for step in stride(from: stepCount - 1, through: 0, by: -1) {
            injectStaticElements(frameCount: visualTick - step)
            output = renderCurrentWater()
            calculateNextWater()
            swap(&current, &previous)
        }
        lastVisualTick = visualTick
        return output
    }

    private mutating func injectStaticElements(frameCount: Int) {
        for (elementIndex, element) in definition.elements.enumerated() {
            guard element.kind == .heightBlob else { continue }
            let frequency = Int(element.frequency)
            if frequency != 0 && (frameCount + elementIndex) % frequency != 0 {
                continue
            }
            injectHeightBlob(element)
        }
    }

    private mutating func injectHeightBlob(_ element: WaterProceduralElement) {
        let centerX = Int(element.x1)
        let centerY = Int(element.y1)
        let radius = Int(element.size)
        let radiusSquared = radius * radius
        var left = -radius
        var top = -radius
        var right = radius
        var bottom = radius
        if centerX - radius < 1 { left -= centerX - radius - 1 }
        if centerY - radius < 1 { top -= centerY - radius - 1 }
        if centerX + radius > Self.dimension - 1 {
            right -= centerX + radius - Self.dimension + 1
        }
        if centerY + radius > Self.dimension - 1 {
            bottom -= centerY + radius - Self.dimension + 1
        }
        guard left < right, top < bottom else { return }
        let height = Int16(element.speed)
        for y in top..<bottom {
            let ySquared = y * y
            for x in left..<right where x * x + ySquared < radiusSquared {
                let index = (centerY + y) * Self.dimension + centerX + x
                current[index] = current[index] &+ height
            }
        }
    }

    private func renderCurrentWater() -> Data {
        var rgba8 = [UInt8](repeating: 0, count: Self.pixelCount * 4)
        for y in 0..<Self.dimension {
            let previousY = y == 0 ? Self.dimension - 1 : y - 1
            let nextY = y == Self.dimension - 1 ? 0 : y + 1
            for x in 0..<Self.dimension {
                let previousX = x == 0 ? Self.dimension - 1 : x - 1
                let nextX = x == Self.dimension - 1 ? 0 : x + 1
                let index = y * Self.dimension + x
                let dx = Int(current[y * Self.dimension + previousX])
                    - Int(current[y * Self.dimension + nextX])
                let dy = Int(current[previousY * Self.dimension + x])
                    - Int(current[nextY * Self.dimension + x])
                let sampleX = (x + (dx >> 3)) & (Self.dimension - 1)
                let sampleY = (y + (dy >> 3)) & (Self.dimension - 1)
                let sample = (sampleY * Self.dimension + sampleX) * 4
                let shade = min(
                    63,
                    max(0, 32 - (dx >> Int(definition.lightingShift)))
                )
                let destination = index * 4
                let shaded = shadedRGB(
                    red: sourceRGBA8[sample] >> 3,
                    green: sourceRGBA8[sample + 1] >> 3,
                    blue: sourceRGBA8[sample + 2] >> 3,
                    shade: shade
                )
                rgba8[destination] = expandFiveBits(shaded.red)
                rgba8[destination + 1] = expandFiveBits(shaded.green)
                rgba8[destination + 2] = expandFiveBits(shaded.blue)
                rgba8[destination + 3] = 255
            }
        }
        return Data(rgba8)
    }

    private func shadedRGB(
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        shade: Int
    ) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let normalized = Float(shade) / 63
        let low = min(normalized / 0.5, 1)
        let high = max((normalized - 0.5) / 0.5, 0)
        let shadedRed = min(Int(Float(red) * low + 31 * high), 31)
        let shadedBlue = min(Int(Float(blue) * low + 31 * high), 31)
        let lowGreen = min(Int(Float(green & 0x07) * low + 7 * high), 7)
        let highGreen = min(Int(Float(green & 0x18) * low + 24 * high), 24)
        return (
            UInt8(shadedRed),
            UInt8(lowGreen + highGreen),
            UInt8(shadedBlue)
        )
    }

    private mutating func calculateNextWater() {
        for y in 0..<Self.dimension {
            let north = y == 0 ? Self.dimension - 1 : y - 1
            let south = y == Self.dimension - 1 ? 0 : y + 1
            for x in 0..<Self.dimension {
                let west = x == 0 ? Self.dimension - 1 : x - 1
                let east = x == Self.dimension - 1 ? 0 : x + 1
                let index = y * Self.dimension + x
                var next = (
                    Int(current[north * Self.dimension + x])
                        + Int(current[south * Self.dimension + x])
                        + Int(current[y * Self.dimension + west])
                        + Int(current[y * Self.dimension + east])
                ) >> 1
                next -= Int(previous[index])
                next -= next >> Int(definition.dampingShift)
                previous[index] = Int16(truncatingIfNeeded: next)
            }
        }
    }
}

private func expandFiveBits(_ value: UInt8) -> UInt8 {
    value << 3 | value >> 2
}
