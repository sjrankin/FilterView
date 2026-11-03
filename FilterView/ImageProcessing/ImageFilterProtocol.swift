//
//  ImageFilterProtocol.swift
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

protocol ImageFilter: Sendable
{
    /// Name of the filter. Also functions as the filter ID so this must be unique.
    static var FilterName: String { get }
    /// The filter type. This is any string the implementor wants, as long as it is unique in the univers of filters in this program.
    var FilterType: ImageFilterTypes { get }
    /// The call to process the image. Throws `FilterException` on error. Asynchronous.
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
    /// Filters implemented on the CPU because there is no CoreImage filter and the given filter is not really good on a GPU. Filters
    /// in this class are presumed to be non-performant.
    case CPU
    /// Filters implemented using the OpenCV library.
    case OpenCV
}

/// A filter that makes its picture from nothing and uses only the size of the image it is given, such as the sunbeams. Meant to be
/// laid over another image. In a pipeline, when such a stage is merged onto a target stage, it is made again on a canvas the size of
/// the target, so the picture keeps its own size and its center options place it on the target instead of the merge stretching it.
protocol OverlayGenerator: ImageFilter
{
}
