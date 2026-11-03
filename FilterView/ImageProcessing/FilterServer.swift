//
//  FilterServer.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
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

/// Serves image filters and image filter identifiers.
class FilterServer
{
    /// Holds the dictionary of image filters.
     var BuiltInFilters = [String: ImageFilter]()

    /// Filter names in the order they were registered. Dictionaries have no stable order, so this is what makes
    /// `GetFilterList` return the same order every time.
    private var FilterOrder = [String]()

    /// Initilize the filter. Filters are added to `BuildInFilters` here.
    init()
    {
        Register(PassThroughFilter.FilterName, PassThroughFilter())
        Register(CIGrayscale.FilterName, CIGrayscale())
        Register(CINoir.FilterName, CINoir())
        Register(CIDither.FilterName, CIDither())
        Register(AtkinsonDither.FilterName, AtkinsonDither())
        Register(AtkinsonDitherFast.FilterName, AtkinsonDitherFast())
        Register(CIMaxComponent.FilterName, CIMaxComponent())
        Register(CIMinComponent.FilterName, CIMinComponent())
        Register(CICMYKHalftone.FilterName, CICMYKHalftone())
        Register(CIDotScreen.FilterName, CIDotScreen())
        Register(CIHatchedScreen.FilterName, CIHatchedScreen())
        Register(CILineScreen.FilterName, CILineScreen())
        Register(CICircularScreen.FilterName, CICircularScreen())
        Register(CILineOverlay.FilterName, CILineOverlay())
        Register(CIComicEffect.FilterName, CIComicEffect())
        Register(MetalInvert.FilterName, MetalInvert())
        Register(ConditionalMetalInvert.FilterName, ConditionalMetalInvert())
        Register(MetalBrightnessInvert.FilterName, MetalBrightnessInvert())
        Register(ColorBrightnessInvert.FilterName, ColorBrightnessInvert())
        Register(ChannelSwap.FilterName, ChannelSwap())
        Register(MirrorImage.FilterName, MirrorImage())
        Register(MetalKuwahara.FilterName, MetalKuwahara())
        Register(MPSSobel.FilterName, MPSSobel())
        Register(MPSLaplacian.FilterName, MPSLaplacian())
        Register(MPSCanny.FilterName, MPSCanny())
        Register(MPSHistogramEqualization.FilterName, MPSHistogramEqualization())
        Register(MPSPyramid.FilterName, MPSPyramid())
        Register(MPSErode.FilterName, MPSErode())
        Register(MPSDilate.FilterName, MPSDilate())
        Register(CIKaleidoscope.FilterName, CIKaleidoscope())
        Register(CITriangleFoldReflectedTile.FilterName, CITriangleFoldReflectedTile())
        Register(CIFourFoldReflectedTile.FilterName, CIFourFoldReflectedTile())
        Register(CISixFoldReflectedTile.FilterName, CISixFoldReflectedTile())
        Register(CIEightFoldReflectedTile.FilterName, CIEightFoldReflectedTile())
        Register(CITwelveFoldReflectedTile.FilterName, CITwelveFoldReflectedTile())
        Register(AtkinsonDither.FilterName, AtkinsonDither())
        Register(ColorScale.FilterName, ColorScale())
        Register(ColorScaleColor.FilterName, ColorScaleColor())
        Register(BackgroundClear.FilterName, BackgroundClear())
        Register(AlphaShape.FilterName, AlphaShape())
        Register(ColorRegion.FilterName, ColorRegion())
        Register(CIGaussianBlur.FilterName, CIGaussianBlur())
        Register(CIMedian.FilterName, CIMedian())
        Register(CIMorphologyGradient.FilterName, CIMorphologyGradient())
        Register(CIMorphologyMaximum.FilterName, CIMorphologyMaximum())
        Register(CIMorphologyMinimum.FilterName, CIMorphologyMinimum())
        Register(CIMotionBlur.FilterName, CIMotionBlur())
        Register(CIZoomBlur.FilterName, CIZoomBlur())
        Register(CIColorClamp.FilterName, CIColorClamp())
        Register(CIColorControls.FilterName, CIColorControls())
        Register(CIColorThreshold.FilterName, CIColorThreshold())
        Register(CIColorThresholdOtsu.FilterName, CIColorThresholdOtsu())
        Register(CILinearToSRGBToneCurve.FilterName, CILinearToSRGBToneCurve())
        Register(CISRGBToneCurveToLinear.FilterName, CISRGBToneCurveToLinear())
        Register(CIVibrance.FilterName, CIVibrance())
        Register(CIWhitePoint.FilterName, CIWhitePoint())
        Register(CISunBeamsGenerator.FilterName, CISunBeamsGenerator())
        Register(CIAztecCodeGenerator.FilterName, CIAztecCodeGenerator())
        Register(CIBarcodeGenerator.FilterName, CIBarcodeGenerator())
        Register(CICode128BarcodeGenerator.FilterName, CICode128BarcodeGenerator())
        Register(CIPDF417BarcodeGenerator.FilterName, CIPDF417BarcodeGenerator())
        Register(CIQRCodeGenerator.FilterName, CIQRCodeGenerator())
        Register(CILenticularHaloGenerator.FilterName, CILenticularHaloGenerator())
        Register(CIRandomGenerator.FilterName, CIRandomGenerator())
        Register(CIStarShineGenerator.FilterName, CIStarShineGenerator())
        Register(CIStripesGenerator.FilterName, CIStripesGenerator())
        Register(CICannyEdgeDetector.FilterName, CICannyEdgeDetector())
        Register(CICrystallize.FilterName, CICrystallize())
        Register(CIDepthOfField.FilterName, CIDepthOfField())
        Register(CIEdges.FilterName, CIEdges())
        Register(CIEdgeWork.FilterName, CIEdgeWork())
        Register(CIGaborGradients.FilterName, CIGaborGradients())
        Register(CIGloom.FilterName, CIGloom())
        Register(CIHexagonalPixellate.FilterName, CIHexagonalPixellate())
        Register(CIHighlightShadowAdjust.FilterName, CIHighlightShadowAdjust())
        Register(CIPixellate.FilterName, CIPixellate())
        Register(CIPointillize.FilterName, CIPointillize())
        Register(CISobelGradients.FilterName, CISobelGradients())
        Register(CISpotColor.FilterName, CISpotColor())
        Register(CIGlideReflectedTile.FilterName, CIGlideReflectedTile())
        Register(CIOpTile.FilterName, CIOpTile())
        Register(CIParallelogramTile.FilterName, CIParallelogramTile())
        Register(CIPerspectiveTile.FilterName, CIPerspectiveTile())
        Register(CIColorPosterize.FilterName, CIColorPosterize())
        Register(CIConvertRGBToLab.FilterName, CIConvertRGBToLab())
        Register(CIConvertLabToRGB.FilterName, CIConvertLabToRGB())
        Register(CITextImageGenerator.FilterName, CITextImageGenerator())
        Register(CIBumpDistortion.FilterName, CIBumpDistortion())
        Register(CICircularWrap.FilterName, CICircularWrap())
        Register(CIDroste.FilterName, CIDroste())
        Register(CIGlassDistortion.FilterName, CIGlassDistortion())
        Register(CIGlassLozenge.FilterName, CIGlassLozenge())
        Register(CILightTunnel.FilterName, CILightTunnel())
        Register(CIPinchDistortion.FilterName, CIPinchDistortion())
        Register(CIStretchCrop.FilterName, CIStretchCrop())
        Register(CITorusLensDistortion.FilterName, CITorusLensDistortion())
        Register(CITwirlDistortion.FilterName, CITwirlDistortion())
        Register(CIVortexDistortion.FilterName, CIVortexDistortion())
        Register(CIPersonSegmentation.FilterName, CIPersonSegmentation())
        Register(CIFaceDetector.FilterName, CIFaceDetector())
        #if os(macOS)
        Register(OpenCVCanny.FilterName, OpenCVCanny())
        Register(OpenCVBilateral.FilterName, OpenCVBilateral())
        Register(OpenCVCLAHE.FilterName, OpenCVCLAHE())
        Register(OpenCVAdaptiveThreshold.FilterName, OpenCVAdaptiveThreshold())
        Register(OpenCVMorphology.FilterName, OpenCVMorphology())
        Register(OpenCVBayerDemosaic.FilterName, OpenCVBayerDemosaic())
        #endif
        let SavedPipelines = SavedPipelineFilter()
        SavedPipelines.Server = self
        Register(SavedPipelineFilter.FilterName, SavedPipelines)
    }

    /// Adds a filter, remembering the order in which it was added.
    /// - Parameter Name: The name of the filter.
    /// - Parameter Filter: The filter.
    private func Register(_ Name: String, _ Filter: ImageFilter)
    {
        if BuiltInFilters[Name] == nil
        {
            FilterOrder.append(Name)
        }
        BuiltInFilters[Name] = Filter
    }
    
    /// Given a filter ID, return the filter itself.
    /// - Parameter Name: The name of the filter (which functions as the ID).
    /// - Returns: An image filter that can be executed on images. `Nil` if not found.
     func GetFilter(_ Name: String) -> ImageFilter?
    {
        return BuiltInFilters[Name]
    }
    
    /// Returns a list of image filter names.
    /// - Parameter InOrder: If true, the filter names are in the order `Infrastructure`, `Metal`, and `CoreImage`,
    /// and internally in each group, in the order defined in `init`. Otherwise, the image filter names are returned in an
    /// arbitrary order since they are stored in a dictionary.
    /// - Returns: Array of filter names.
    func GetFilterList(InOrder: Bool = true) -> [String]
    {
        if InOrder
        {
            let Infrastructure = FilterOrder.filter{BuiltInFilters[$0]?.FilterType == .Infrastructure}
            let Metal = FilterOrder.filter{BuiltInFilters[$0]?.FilterType == .Metal}
            let CoreImage = FilterOrder.filter{BuiltInFilters[$0]?.FilterType == .CoreImage}
            let CPU = FilterOrder.filter{BuiltInFilters[$0]?.FilterType == .CPU}
            return Infrastructure + Metal + CoreImage + CPU
        }
        else
        {
            return FilterOrder
        }
    }
    
    /// Run the filter whose name is in `Filter` on the passed image.
    ///
    /// - Parameter Filter: The name of the filter to run. Must match the value stored in `FilterName` in each filter.
    /// - Parameter With: The image to process.
    /// - Parameter Options: Dictionary with context-sensitive keys to supply options to filters. Keys are defined in the actual filter so
    /// please refer to the source for what is expected.
    /// - Returns: On success, returns a new `CGImage`.
    /// - Throws: FilterException on filter errors (if `Filter` cannot be found, for example).
    /// - Note: Called asynchronously.
    /// - Note: Can be cancelled if the processing gets stuck.
    func Run(Filter: String, With Source: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        guard let Found = GetFilter(Filter) else
        {
            throw FilterException(Message: "Cannot find \(Filter)")
        }
        return try await Found.ProcessImage(Source, Options)
    }
}
