//
//  CIDroste.swift
//  FilterView
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

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Repeats the image inside itself, in a spiral that gets smaller and smaller. Options: `POINT0X`, `POINT0Y`, `POINT1X`, `POINT1Y` (the
/// corners of the rectangle where the copy goes, as percent of the width and height from the top left; default 25, 75 and 75, 25),
/// `STRANDS` (default 1), `PERIODICITY` (default 1), `ROTATION` (degrees; default 0), and `ZOOM` (default 1).
class CIDroste: ImageFilter
{
    static let FilterName = "CI Droste"

    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.droste()
        filter.inputImage = ci
        filter.insetPoint0 = FilterOptionValues.Point(Options, "POINT0X", "POINT0Y", Input, DefaultX: 25, DefaultY: 75)
        filter.insetPoint1 = FilterOptionValues.Point(Options, "POINT1X", "POINT1Y", Input, DefaultX: 75, DefaultY: 25)
        filter.strands = Float(FilterOptionValues.Number(Options, "STRANDS", Default: 1))
        filter.periodicity = Float(FilterOptionValues.Number(Options, "PERIODICITY", Default: 1))
        filter.rotation = Float(FilterOptionValues.Radians(Options, "ROTATION", DefaultDegrees: 0))
        filter.zoom = Float(FilterOptionValues.Number(Options, "ZOOM", Default: 1))
        return try DistortSupport.Finish(filter.outputImage, Source: ci, Name: "CIDroste")
    }
}
