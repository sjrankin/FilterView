//
//  PipelineMerge.swift
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/2/26.
//

import CoreImage
import CoreGraphics

/// How two pipeline images are combined. Every mode except `Mix` is a CoreImage blend or compositing filter.
enum MergeModes: String, CaseIterable, Identifiable
{
    case Mix = "Mix"
    case SourceOver = "Over"
    case Add = "Add"
    case Subtract = "Subtract"
    case Multiply = "Multiply"
    case Divide = "Divide"
    case Screen = "Screen"
    case Overlay = "Overlay"
    case SoftLight = "Soft Light"
    case HardLight = "Hard Light"
    case Darken = "Darken"
    case Lighten = "Lighten"
    case Minimum = "Minimum"
    case Maximum = "Maximum"
    case ColorDodge = "Color Dodge"
    case ColorBurn = "Color Burn"
    case LinearDodge = "Linear Dodge"
    case LinearBurn = "Linear Burn"
    case Difference = "Difference"
    case Exclusion = "Exclusion"
    case Hue = "Hue"
    case Saturation = "Saturation"
    case Color = "Color"
    case Luminosity = "Luminosity"

    var id: String
    {
        rawValue
    }

    /// The name shown to the user.
    var Title: String
    {
        rawValue
    }

    /// The CoreImage filter that does the merge. `nil` for `Mix`, which is only the amount.
    var FilterName: String?
    {
        switch self
        {
            case .Mix: return nil
            case .SourceOver: return "CISourceOverCompositing"
            case .Add: return "CIAdditionCompositing"
            case .Subtract: return "CISubtractBlendMode"
            case .Multiply: return "CIMultiplyBlendMode"
            case .Divide: return "CIDivideBlendMode"
            case .Screen: return "CIScreenBlendMode"
            case .Overlay: return "CIOverlayBlendMode"
            case .SoftLight: return "CISoftLightBlendMode"
            case .HardLight: return "CIHardLightBlendMode"
            case .Darken: return "CIDarkenBlendMode"
            case .Lighten: return "CILightenBlendMode"
            case .Minimum: return "CIMinimumCompositing"
            case .Maximum: return "CIMaximumCompositing"
            case .ColorDodge: return "CIColorDodgeBlendMode"
            case .ColorBurn: return "CIColorBurnBlendMode"
            case .LinearDodge: return "CILinearDodgeBlendMode"
            case .LinearBurn: return "CILinearBurnBlendMode"
            case .Difference: return "CIDifferenceBlendMode"
            case .Exclusion: return "CIExclusionBlendMode"
            case .Hue: return "CIHueBlendMode"
            case .Saturation: return "CISaturationBlendMode"
            case .Color: return "CIColorBlendMode"
            case .Luminosity: return "CILuminosityBlendMode"
        }
    }
}

/// Combines two images with CoreImage.
enum PipelineMerger
{
    private static let Context = CIContext()

    /// Merges two images.
    /// - Parameter Background: The image the other one is merged onto. The result has its size.
    /// - Parameter Foreground: The image merged onto the background. It is scaled to the background's size if it differs.
    /// - Parameter Mode: How the two are combined.
    /// - Parameter Amount: How much of the merge shows, 0.0 to 1.0. At 1.0 the merge is complete; below that it fades toward the
    /// background.
    /// - Returns: The merged image. `nil` if the CoreImage filter is not available or fails.
    static func Merge(Background: CGImage, Foreground: CGImage, Mode: MergeModes, Amount: Double) -> CGImage?
    {
        let Back = CIImage(cgImage: Background)
        var Front = CIImage(cgImage: Foreground)
        if Front.extent.size != Back.extent.size,
           Front.extent.width > 0,
           Front.extent.height > 0
        {
            Front = Front.transformed(by: CGAffineTransform(scaleX: Back.extent.width / Front.extent.width,
                                                            y: Back.extent.height / Front.extent.height))
        }
        var Merged = Front
        if let Name = Mode.FilterName
        {
            guard let Blender = CIFilter(name: Name) else
            {
                return nil
            }
            Blender.setValue(Front, forKey: kCIInputImageKey)
            Blender.setValue(Back, forKey: kCIInputBackgroundImageKey)
            guard let Blended = Blender.outputImage else
            {
                return nil
            }
            Merged = Blended
        }
        if Amount < 1.0,
           let Fade = CIFilter(name: "CIDissolveTransition")
        {
            Fade.setValue(Back, forKey: kCIInputImageKey)
            Fade.setValue(Merged, forKey: kCIInputTargetImageKey)
            Fade.setValue(max(Amount, 0.0), forKey: kCIInputTimeKey)
            if let Faded = Fade.outputImage
            {
                Merged = Faded
            }
        }
        return Context.createCGImage(Merged.cropped(to: Back.extent), from: Back.extent)
    }
}
