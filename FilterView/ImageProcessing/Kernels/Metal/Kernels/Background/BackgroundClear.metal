//
//  BackgroundClear.metal
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
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
using namespace metal;

// Replaces every pixel close to a target color with a replacement color.
// Parameters (buffer 0), all floats:
//   0-3: target color (red, green, blue, alpha), straight (not premultiplied), 0.0 - 1.0.
//   4-7: replacement color (red, green, blue, alpha), straight, 0.0 - 1.0. An alpha of 0 makes matching pixels transparent.
//   8:   normal tolerance, 0.0 - 1.0. 0.0 matches only the exact target color; 1.0 matches every color.
//   9:   ignore alpha, 0 or 1. At 1 only the red, green, and blue of the pixel and of the target are compared, so a half-transparent black
//        pixel matches black as well as an opaque one does. A pixel with an alpha of 0 has no color of its own (premultiplied it is just
//        black), so it is never matched.
//   10:  keep alpha, 0 or 1. At 1 a matched pixel keeps its own alpha and only its color is replaced, so the replacement color's alpha is not
//        used. Otherwise the replacement is written as it is, alpha included.
// Input and output textures are premultiplied, so pixels are un-premultiplied before they are compared and the
// replacement is premultiplied before it is written.
kernel void BackgroundClear(texture2d<float, access::read> Input [[texture(0)]],
                            texture2d<float, access::write> Output [[texture(1)]],
                            constant float *Parameters [[buffer(0)]],
                            uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Pixel = Input.read(Position);
    float4 Straight = Pixel;
    if (Pixel.a > 0.0)
    {
        Straight.rgb = Pixel.rgb / Pixel.a;
    }
    float4 Target = float4(Parameters[0], Parameters[1], Parameters[2], Parameters[3]);
    float4 Replacement = float4(Parameters[4], Parameters[5], Parameters[6], Parameters[7]);
    float Tolerance = clamp(Parameters[8], 0.0, 1.0);
    bool IgnoreAlpha = Parameters[9] > 0.5;
    // Distance between the colors as a fraction of the largest possible distance: 2.0 across four channels, or the square root of 3
    // across the three color channels when alpha is ignored.
    float Distance = IgnoreAlpha ? length(Straight.rgb - Target.rgb) / sqrt(3.0) : length(Straight - Target) / 2.0;
    // A fully transparent pixel has no color to compare when alpha is ignored.
    bool HasColor = !IgnoreAlpha || Pixel.a > 0.0;
    bool KeepAlpha = Parameters[10] > 0.5;
    if (HasColor && Distance <= Tolerance)
    {
        float Alpha = KeepAlpha ? Pixel.a : Replacement.a;
        Output.write(float4(Replacement.rgb * Alpha, Alpha), Position);
    }
    else
    {
        Output.write(Pixel, Position);
    }
}
