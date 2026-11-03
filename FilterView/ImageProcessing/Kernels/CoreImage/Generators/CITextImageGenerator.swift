//
//  CITextImageGenerator.swift
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

/// Makes an image of some text. This is a generator, so it does not use the image's pixels, only its size, which the result is cut to.
/// In a pipeline, a text stage merged onto another stage is made on a canvas the size of that stage (see `PipelineCanvas`), so the
/// text keeps its size and the center options place it on the target. Options:
///   - `TEXT`: the text (default `FilterView`).
///   - `FONT`: the PostScript name of the font (default `HelveticaNeue`). An unknown name gives the default font.
///   - `FONTSIZE`: size of the text in points (default 48).
///   - `PADDING`: space around the text in points, which matters when the text is put over an image (default 0).
///   - `COLOR`: the color of the text, as hexadecimal text (default white, `FFFFFFFF`).
///   - `CENTERX`, `CENTERY`: where the middle of the text is, as percentages of the width and height (default 50, the middle). Y is
///   measured from the top of the image.
///   - `OVERIMAGE`: `true` puts the text over the image; the default `false` shows only the text, on transparency.
class CITextImageGenerator: OverlayGenerator
{
    static let FilterName = "CI Text Image Generator"

    var FilterType: ImageFilterTypes
    {
        .CoreImage
    }

    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        let ci = ImageUtility.CGImageToCIImage(Input)
        let filter = CIFilter.textImageGenerator()
        filter.text = FilterOptionValues.Text(Options, "TEXT", Default: "FilterView")
        filter.fontName = FilterOptionValues.Text(Options, "FONT", Default: "HelveticaNeue")
        filter.fontSize = Float(max(FilterOptionValues.Number(Options, "FONTSIZE", Default: 48), 1))
        filter.scaleFactor = 1
        filter.padding = Float(max(FilterOptionValues.Number(Options, "PADDING", Default: 0), 0))
        guard let Letters = filter.outputImage,
              !Letters.extent.isInfinite,
              !Letters.extent.isEmpty else
        {
            throw FilterException(Message: "Error from CITextImageGenerator.")
        }
        // The text image is only a shape (its alpha), so it is filled with the chosen color.
        let Tint = FilterOptionValues.CoreImageColor(Options, "COLOR", Default: [1, 1, 1, 1])
        let Fill = CIFilter.sourceInCompositing()
        Fill.inputImage = CIImage(color: Tint).cropped(to: Letters.extent)
        Fill.backgroundImage = Letters
        guard let Colored = Fill.outputImage else
        {
            throw FilterException(Message: "Error from CITextImageGenerator.")
        }
        let Spot = FilterOptionValues.Center(Options, Input)
        let Placed = Colored.transformed(by: CGAffineTransform(translationX: Spot.x - Colored.extent.midX,
                                                               y: Spot.y - Colored.extent.midY))
        // The text image is only as big as the text, so it goes on a transparent canvas the size of the image.
        let OnCanvas = Placed.composited(over: CIImage(color: .clear).cropped(to: ci.extent))
        return try GeneratorSupport.Finish(OnCanvas, Source: ci, OverImage: FilterOptionValues.Flag(Options, "OVERIMAGE"),
                                           Name: "CITextImageGenerator")
    }
}
