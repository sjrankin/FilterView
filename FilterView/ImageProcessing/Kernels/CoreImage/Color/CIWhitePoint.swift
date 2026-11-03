//
//  CIWhitePoint.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
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

/// Maps the chosen color to white. Option: `WPCOLOR`, the color as hexadecimal text (`RRGGBB` or `RRGGBBAA`). The default is white,
/// which leaves the image unchanged.
class CIWhitePoint: ImageFilter
{
    static let FilterName = "CI WhitePoint"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.whitePointAdjust()
        filter.inputImage = ci
        let White = FilterOptionValues.Color(Options, "WPCOLOR", Default: [1, 1, 1, 1])
        filter.color = CIColor(red: CGFloat(White[0]), green: CGFloat(White[1]), blue: CGFloat(White[2]), alpha: CGFloat(White[3]))
        if let final = filter.outputImage
        {
            if let final = ImageUtility.CIImageToCGImage(final)
            {
                return final
            }
        }
        throw FilterException(Message: "Error from CIWhitePoint.")
    }
}
