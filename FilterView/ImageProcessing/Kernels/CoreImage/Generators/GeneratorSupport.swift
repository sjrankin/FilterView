//
//  GeneratorSupport.swift
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

import Foundation
import CoreGraphics
import CoreImage
import CoreImage.CIFilterBuiltins

/// Shared steps for the Core Image generators. A generator makes an image from nothing, so it does not use the pixels of the image
/// it is given, only its size: the result is the size of that image.
enum GeneratorSupport
{
    /// Makes the final image from what a generator made.
    /// - Parameter Result: The generator's image, which may go on forever.
    /// - Parameter Source: The image the filter was given. Its size is the size of the result.
    /// - Parameter OverImage: If true, the result is put over the source image instead of standing alone.
    /// - Parameter Name: Name of the filter, for the error message.
    /// - Throws: `FilterException` if the image cannot be made.
    static func Finish(_ Result: CIImage, Source: CIImage, OverImage: Bool, Name: String) throws -> CGImage
    {
        var Cut = Result.cropped(to: Source.extent)
        if OverImage
        {
            Cut = Cut.composited(over: Source)
        }
        guard let Final = ImageUtility.CIImageToCGImage(Cut) else
        {
            throw FilterException(Message: "Error from \(Name).")
        }
        return Final
    }

    /// Makes a barcode as large as it can be inside the source image, centered on white. Barcodes are made one pixel to a module,
    /// so they are enlarged by whole numbers with no smoothing, which keeps the edges sharp. A barcode bigger than the image is
    /// made smaller to fit.
    /// - Parameter Code: The barcode.
    /// - Parameter Source: The image the filter was given. Its size is the size of the result.
    static func Fit(_ Code: CIImage, in Source: CIImage) -> CIImage
    {
        let Area = Source.extent
        let Ratio = min(Area.width / Code.extent.width, Area.height / Code.extent.height)
        let Scale = Ratio >= 1 ? Ratio.rounded(.down) : Ratio
        let Scaled = Code.samplingNearest().transformed(by: CGAffineTransform(scaleX: Scale, y: Scale))
        let Centered = Scaled.transformed(by: CGAffineTransform(translationX: Area.midX - Scaled.extent.midX,
                                                                y: Area.midY - Scaled.extent.midY))
        return Centered.composited(over: CIImage(color: .white).cropped(to: Area))
    }

    /// The text to put in a barcode.
    /// - Parameter Options: The filter's options. The text is the `"TEXT"` value.
    /// - Parameter ASCIIOnly: True for barcodes that cannot hold anything but ASCII characters.
    /// - Throws: `FilterException` if the text cannot be held.
    static func Message(_ Options: [String: Any]?, ASCIIOnly: Bool = false) throws -> Data
    {
        let Text = FilterOptionValues.Text(Options, "TEXT", Default: "FilterView")
        guard let Encoded = Text.data(using: ASCIIOnly ? .ascii : .utf8) else
        {
            throw FilterException(Message: "This barcode can only hold ASCII characters.")
        }
        return Encoded
    }
}
