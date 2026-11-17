//
//  Stipple.metal
//  FilterView
//
//  Created by Claude/Stuart Rankin on 11/17/26.
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

#include <metal_stdlib>
using namespace metal;

// Stipple: splits the image into regions by brightness, paints it with two colors, and scatters dots of the second color over each region.
// The brighter a region was in the original image, the more dots it gets.
// Parameters (buffer 0), all floats:
//   0:    number of brightness regions, 2 - 16. A pixel's region is its Rec. 709 brightness cut into this many equal bands. Less than 2 means
//         no regions: the dots follow the brightness of each pixel smoothly.
//   1:    the most dots a region can have, 0.0 - 1.0, as the share of its pixels that are dots. A region as bright as white gets this share;
//         darker ones get less (see 10).
//   2:    dot size in pixels, 1 - 16. Dots are squares on a grid of this size.
//   3:    seed for the random placement. The same seed always gives the same dots.
//   4-6:  red, green, blue of the base color (0.0 - 1.0): what every pixel is before dots are added. Black by default.
//   7-9:  red, green, blue of the dot color. White by default.
//   10:   tone curve exponent, 0.2 - 5. The share of dots is the brightness (or the region's brightness) raised to this power, so values above 1
//         thin out the dots in all but the brightest parts and make the image look like it is emerging from the dark. 1 is a straight line.
//   11:   texture, 0.0 - 1.0. 0 places every dot independently. More makes dots in the same row, and in the same column, tend to appear
//         together, which gives streaks and a faint lattice, as in a screen print.
// The pixel's alpha is not changed. Input and output textures are premultiplied.
// Dots are placed by hashing the pixel's grid cell with the seed, so every pixel decides on its own whether it is a dot and no pixel needs to
// see any other.

/// A well-mixed 32-bit hash of three values (PCG).
static uint StippleHash(uint3 Value)
{
    uint H = Value.x * 747796405u + Value.y * 2891336453u + Value.z * 277803737u + 2891336453u;
    H = ((H >> ((H >> 28u) + 4u)) ^ H) * 277803737u;
    return (H >> 22u) ^ H;
}

kernel void Stipple(texture2d<float, access::read> Input [[texture(0)]],
                    texture2d<float, access::write> Output [[texture(1)]],
                    constant float *Parameters [[buffer(0)]],
                    uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Pixel = Input.read(Position);
    int Bands = int(Parameters[0] + 0.5);
    float MaxDensity = clamp(Parameters[1], 0.0, 1.0);
    uint Size = uint(clamp(Parameters[2] + 0.5, 1.0, 16.0));
    uint Seed = uint(max(Parameters[3], 0.0));
    float3 Base = float3(Parameters[4], Parameters[5], Parameters[6]);
    float3 DotColor = float3(Parameters[7], Parameters[8], Parameters[9]);
    float Exponent = clamp(Parameters[10], 0.2, 5.0);
    float Texture = saturate(Parameters[11]);

    float Brightness = 0.0;
    if (Pixel.a > 0.0)
    {
        Brightness = saturate(dot(Pixel.rgb / Pixel.a, float3(0.2126, 0.7152, 0.0722)));
    }
    if (Bands >= 2)
    {
        // The region the pixel is in, 0 (darkest) to Bands - 1 (brightest). Every pixel in it is treated as being as bright as the middle of
        // the region, so a few regions give a coarse version of the smooth result and more regions get closer and closer to it.
        Bands = min(Bands, 16);
        Brightness = (float(min(int(Brightness * float(Bands)), Bands - 1)) + 0.5) / float(Bands);
    }
    float Density = MaxDensity * pow(Brightness, Exponent);

    uint2 Cell = Position / Size;
    float Random = float(StippleHash(uint3(Cell, Seed))) / 4294967295.0;
    if (Texture > 0.0)
    {
        // One value for the whole row of cells and one for the whole column. Averaging them gives a pattern of streaks and crossings that
        // is mixed into each cell's own random value.
        float Row = float(StippleHash(uint3(0xFFFFu, Cell.y, Seed))) / 4294967295.0;
        float Column = float(StippleHash(uint3(Cell.x, 0xFFFFu, Seed))) / 4294967295.0;
        Random = mix(Random, 0.5 * (Row + Column), Texture * 0.6);
    }
    float3 Color = Random < Density ? DotColor : Base;
    Output.write(float4(Color * Pixel.a, Pixel.a), Position);
}
