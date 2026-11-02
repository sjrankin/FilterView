//
//  BackgroundClear.metal
//  FilterView
//
//  Created by Stuart Rankin on 11/2/26.
//

#include <metal_stdlib>
using namespace metal;

// Replaces every pixel close to a target color with a replacement color.
// Parameters (buffer 0), all floats:
//   0-3: target color (red, green, blue, alpha), straight (not premultiplied), 0.0 - 1.0.
//   4-7: replacement color (red, green, blue, alpha), straight, 0.0 - 1.0. An alpha of 0 makes matching pixels transparent.
//   8:   normal tolerance, 0.0 - 1.0. 0.0 matches only the exact target color; 1.0 matches every color.
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
    // Distance between the colors as a fraction of the largest possible distance (2.0 across four channels).
    float Distance = length(Straight - Target) / 2.0;
    if (Distance <= Tolerance)
    {
        Output.write(float4(Replacement.rgb * Replacement.a, Replacement.a), Position);
    }
    else
    {
        Output.write(Pixel, Position);
    }
}
