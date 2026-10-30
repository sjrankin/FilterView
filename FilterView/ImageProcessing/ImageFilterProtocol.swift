//
//  ImageFilterProtocol.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import Foundation
import CoreGraphics

protocol ImageFilter: Sendable
{
    /// Name of the filter. Also functions as the filter ID so this must be unique.
    static var FilterName: String { get }
    /// The filter type.
    var FilterType: ImageFilterTypes { get }
    /// The call to process the image.
    @concurrent nonisolated func ProcessImage(_ Input: CGImage, _ Options: [String: Any]?) async throws -> CGImage
}

/// Types of filters.
enum ImageFilterTypes
{
    /// Built-in CoreImage filter.
    case CoreImage
    /// Metal kernal filter.
    case Metal
    /// Infrastructure filter - not really intended to be used for directly image processing.
    case Infrastructure
    /// Filters implemented on the CPU because there is no CoreImage filter and the given filter is not really good on a GPU.
    case CPU
}
