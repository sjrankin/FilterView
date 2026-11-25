//
//  KMeansMetalTests.swift
//  FilterViewTests
//
//  Created by Claude/Stuart Rankin on 11/23/26.
//
//  Copyright 2026 Stuart Rankin
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

import Testing
import Foundation
import CoreGraphics
@testable import FilterView

/// The GPU painting must give the same picture as the CPU painting, for every feature space.
@MainActor
struct KMeansMetalTests
{
    /// A 64 x 48 image with smooth color changes, some noise, and a transparent corner.
    private func Pixels() -> [UInt8]
    {
        var Bytes = [UInt8]()
        for Y in 0 ..< 48
        {
            for X in 0 ..< 64
            {
                let Alpha: UInt8 = (X < 6 && Y < 6) ? 0 : 255
                let Noise = (X * 7 + Y * 13) % 9
                let R = min(X * 4 + Noise, 255)
                let G = min(Y * 5 + Noise, 255)
                let B = min(255 - X * 3 + Noise, 255)
                Bytes.append(contentsOf: Alpha == 0 ? [0, 0, 0, 0] : [UInt8(R), UInt8(G), UInt8(B), 255])
            }
        }
        return Bytes
    }

    @Test(arguments: KMeansFeatures.allCases)
    func GPUMatchesCPU(Feature: KMeansFeatures) async throws
    {
        let Input = Pixels()
        let Image = try #require(PixelBuffer.Image(Input, Width: 64, Height: 48))
        for Output in ["CENTER", "GRAY"]
        {
            let Made = try await KMeansColor().ProcessImage(Image, ["FEATURES": Feature.rawValue, "K": "5", "SEED": "3", "OUTPUT": Output])
            let GPU = try #require(PixelBuffer.Bytes(Made, Width: 64, Height: 48))
            let CPU = KMeansColor.Paint(Pixels: Input, Width: 64, Height: 48, Features: Feature, K: 5, Iterations: 10, Seed: 3,
                                        Output: Output)
            var Different = 0
            for Index in 0 ..< GPU.count where abs(Int(GPU[Index]) - Int(CPU[Index])) > 2
            {
                Different += 1
            }
            // Pixels right on the edge between two clusters can fall either way because the GPU and CPU round a little differently.
            #expect(Double(Different) / Double(GPU.count) < 0.01, "\(Feature.rawValue) \(Output): \(Different) values differ")
        }
    }
}
