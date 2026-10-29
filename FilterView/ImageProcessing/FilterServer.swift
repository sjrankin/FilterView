//
//  FilterServer.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
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
            return Infrastructure + Metal + CoreImage
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
