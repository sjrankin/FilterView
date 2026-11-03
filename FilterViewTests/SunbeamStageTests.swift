//
//  SunbeamStageTests.swift
//  FilterViewTests
//
//  Created by Claude/Stuart Rankin on 11/3/26.
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
//

import Testing
import Foundation
import CoreGraphics
@testable import FilterView

@MainActor
struct SunbeamStageTests
{
    private func Sunbeams(CenterX: String) -> FilterSelection
    {
        FilterSelection(Filter: CISunBeamsGenerator.FilterName,
                        Options: ["CENTERX": CenterX, "CENTERY": "50", "SUNRADIUS": "20", "COLOR": "FF8000FF"],
                        DisplayName: "Sunbeams", Parameters: [])
    }

    /// The bytes of an image, to tell two images apart.
    private func Bytes(_ Image: CGImage?) -> Data?
    {
        Image?.dataProvider?.data as Data?
    }

    @Test func ChangingTheCenterMakesTheStageImageAgain() async throws
    {
        let Model = PipelineModel()
        Model.Server = FilterServer()
        Model.IsOpen = true
        await Model.Refresh(Original: TestSupport.MakeImage(Width: 128, Height: 128))
        await Model.Add(Sunbeams(CenterX: "10"))
        let Before = Bytes(Model.Stages[1].Output)
        Model.UpdateOptions(1, To: Sunbeams(CenterX: "90"))
        // Waits for the picture to be made again.
        await Model.Drain()
        let After = Bytes(Model.Stages[1].Output)
        #expect(Before != nil)
        #expect(Before != After)
    }
}
