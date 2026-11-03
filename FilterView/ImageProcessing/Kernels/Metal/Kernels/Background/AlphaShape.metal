//
//  AlphaShape.metal
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

#include <metal_stdlib>
#include "../Region/RegionShape.h"
using namespace metal;

// Changes the alpha of the pixels inside a shape.
// Parameters (buffer 0), all floats. The region is the one RegionShape.h describes (0-2 and 5-7), the same as ColorRegion's. The rest:
//   3:   mode: 0 sets the alpha to the value in 4; 1 goes from alpha 1.0 at the edge of the shape to 0.0 at the center.
//   4:   the alpha mode 0 sets, 0.0 - 1.0.
//   8:   invert, 0 or 1. Not inverted, the shape is what changes and the surroundings are left alone. Inverted, the center is kept
//        and the surroundings change: mode 0 sets the alpha of every pixel outside the shape and leaves the inside alone; mode 1
//        fades from alpha 1.0 at the center to 0.0 at the edge, and everything outside the shape is
//        transparent.
// Where the shape goes beyond the image the alpha is still worked out as if the image went on, so the part that shows is the
// part of the effect that falls on the image.
// Input and output textures are premultiplied. Mode 1 multiplies the pixel's own alpha, so pixels that are already transparent
// stay that way. Mode 0 sets the alpha, so it is not kept.
kernel void AlphaShape(texture2d<float, access::read> Input [[texture(0)]],
                       texture2d<float, access::write> Output [[texture(1)]],
                       constant float *Parameters [[buffer(0)]],
                       uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Pixel = Input.read(Position);
    int Mode = int(Parameters[3] + 0.5);
    float Value = clamp(Parameters[4], 0.0, 1.0);
    bool Invert = Parameters[8] > 0.5;
    // How far out the pixel is: 0 at the center and 1 on the edge of the shape.
    float Distance = RegionDistance(Position, Parameters);
    bool Outside = Distance > 1.0;
    // How much of the pixel's own alpha is kept by the fade: 0 at the center, rising to 1 at the edge of the shape.
    float Fade = saturate(Distance);
    // The part of the image that changes is the shape, or the surroundings when inverted.
    if (Outside == Invert)
    {
        if (Mode == 0)
        {
            float3 Straight = Pixel.a > 0.0 ? Pixel.rgb / Pixel.a : float3(0.0);
            Output.write(float4(Straight * Value, Value), Position);
        }
        else
        {
            // Not inverted, this is inside the shape and the fade is used as it is. Inverted, this is outside it and nothing is kept.
            Output.write(Pixel * (Invert ? 0.0 : Fade), Position);
        }
    }
    else if (Invert && Mode == 1)
    {
        // Inverted and inside the shape: opaque at the center and fading out toward the edge.
        Output.write(Pixel * (1.0 - Fade), Position);
    }
    else
    {
        Output.write(Pixel, Position);
    }
}
