//
//  ColorRegion.metal
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

// Changes how much color the pixels inside a shape have: 0 is fully gray and 1 is the pixel's own color, and in between the color is the
// same share of the way from gray to color.
// Parameters (buffer 0), all floats. The region is the one RegionShape.h describes (0-2 and 5-7), the same as AlphaShape's. The rest:
//   3:   mode: 0 sets the color level to the value in 4; 1 goes from level 1.0 (full color) at the edge of the shape to 0.0 (gray) at the center.
//   4:   the level mode 0 sets, 0.0 - 1.0.
//   8:   invert, 0 or 1. Not inverted, the shape is what changes and the surroundings are left alone. Inverted, the center is kept and the
//        surroundings change: mode 0 sets the level of every pixel outside the shape and leaves the inside alone; mode 1 fades from full
//        color at the center to gray at the edge, and everything outside the shape is gray.
// The gray of a pixel is its Rec. 709 brightness, as in the brightness invert kernels. The pixel's alpha is not changed.
// Input and output textures are premultiplied, so a pixel is un-premultiplied before it is changed and premultiplied again after.
kernel void ColorRegion(texture2d<float, access::read> Input [[texture(0)]],
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
    float Distance = RegionDistance(Position, Parameters);
    bool Outside = Distance > 1.0;

    // How much of the color the pixel keeps. 1 leaves it as it is.
    float Level = 1.0;
    if (Outside == Invert)
    {
        // The part that changes: the shape, or the surroundings when inverted. A fade is 0 at the center and 1 at the edge; out in the
        // surroundings of an inverted fade there is no color.
        Level = Mode == 0 ? Value : (Invert ? 0.0 : saturate(Distance));
    }
    else if (Invert && Mode == 1)
    {
        // Inverted and inside the shape: full color at the center, fading to gray toward the edge.
        Level = 1.0 - saturate(Distance);
    }
    if (Level >= 1.0 || Pixel.a <= 0.0)
    {
        Output.write(Pixel, Position);
        return;
    }
    float3 Straight = Pixel.rgb / Pixel.a;
    float Gray = dot(Straight, float3(0.2126, 0.7152, 0.0722));
    float3 Mixed = mix(float3(Gray), Straight, Level);
    Output.write(float4(Mixed * Pixel.a, Pixel.a), Position);
}
