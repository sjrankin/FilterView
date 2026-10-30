//
//  PassThroughFilter.swift
//  FilterView
//
//  Created by Stuart Rankin on 10/27/26.
//

import Foundation
import CoreGraphics

/// Pass-through filter that performs no processing and just returns the source image.
class PassThroughFilter: ImageFilter
{
    static let FilterName = "Passthrough"
    
    var FilterType: ImageFilterTypes
    {
        .Infrastructure
    }
    
    func ProcessImage(_ Input: CGImage, _ Options: [String: Any]? = nil) async throws -> CGImage
    {
        try Task.checkCancellation()
        return Input
    }
}
