//
//  CIColorClamp.swift
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

/// Limits each color channel to a range. Options (numbers 0.0 to 1.0): `MINR`, `MING`, `MINB`, `MINA` are the lowest values of red,
/// green, blue, and alpha (default 0), and `MAXR`, `MAXG`, `MAXB`, `MAXA` are the highest (default 1).
class CIColorClamp: ImageFilter
{
    static let FilterName = "CI Color Clamp"
    
    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.colorClamp()
        filter.inputImage = ci
        filter.minComponents = CIVector(x: CGFloat(Float(FilterOptionValues.Number(Options, "MINR", Default: 0))),
                                        y: CGFloat(Float(FilterOptionValues.Number(Options, "MING", Default: 0))),
                                        z: CGFloat(Float(FilterOptionValues.Number(Options, "MINB", Default: 0))),
                                        w: CGFloat(Float(FilterOptionValues.Number(Options, "MINA", Default: 0))))
        filter.maxComponents = CIVector(x: CGFloat(Float(FilterOptionValues.Number(Options, "MAXR", Default: 1))),
                                        y: CGFloat(Float(FilterOptionValues.Number(Options, "MAXG", Default: 1))),
                                        z: CGFloat(Float(FilterOptionValues.Number(Options, "MAXB", Default: 1))),
                                        w: CGFloat(Float(FilterOptionValues.Number(Options, "MAXA", Default: 1))))
        if let final = filter.outputImage
        {
            if let final = ImageUtility.CIImageToCGImage(final)
            {
                return final
            }
        }
        throw FilterException(Message: "Error from CIColorClamp.")
    }
}
