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
    static var FilterName: String { get }
    var FilterType: ImageFilterTypes { get }
    @concurrent nonisolated func ProcessImage(_ Input: CGImage) async throws -> CGImage
}

enum ImageFilterTypes
{
    case CoreImage
    case Metal
    case Infrastructure
}
