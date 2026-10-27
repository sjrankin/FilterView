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

    /// Initilize the filter. Filters are added to `BuildInFilters` here.
    init()
    {
        BuiltInFilters[PassThroughFilter.FilterName] = PassThroughFilter()
        BuiltInFilters[CIGrayscale.FilterName] = CIGrayscale()
        BuiltInFilters[CINoir.FilterName] = CINoir()
        BuiltInFilters[CIDither.FilterName] = CIDither()
        BuiltInFilters[CIMaxComponent.FilterName] = CIMaxComponent()
        BuiltInFilters[CIMinComponent.FilterName] = CIMinComponent()
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
            let Infrastructure = BuiltInFilters.filter{$0.value.FilterType == .Infrastructure}
            let Metal = BuiltInFilters.filter{$0.value.FilterType == .Metal}
            let CoreImage = BuiltInFilters.filter{$0.value.FilterType == .CoreImage}
            return Array(Infrastructure.keys) + Array(Metal.keys) + Array(CoreImage.keys)
        }
        else
        {
            return Array(BuiltInFilters.keys)
        }
    }
    
    /// Run the filter whose name is in `Filter` on the passed image.
    /// - Parameter Filter: The name of the filter to run. Must match the value stored in `FilterName` in each filter.
    /// - Parameter With: The image to process.
    /// - Returns: On success, returns a new `CGImage`.
    /// - Throws: FilterException on filter errors (if `Filter` cannot be found, for example).
    /// - Note: Called asynchronously.
    /// - Note: Can be cancelled if the processing gets stuck.
    func Run(Filter: String, With Source: CGImage) async throws -> CGImage
    {
        guard let Found = GetFilter(Filter) else
        {
            throw FilterException(Message: "Cannot find \(Filter)")
        }
        return try await Found.ProcessImage(Source)
    }
}
