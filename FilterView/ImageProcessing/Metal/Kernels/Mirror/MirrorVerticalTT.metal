//
//  MirrorVertical.metal
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

#include <metal_stdlib>
using namespace metal;

// Copies the top half of the image over the bottom half, flipped upside down, so the two halves meet with no seam.
// Each thread writes only its own pixel; pixels in the bottom half read from the mirrored row in the top half.
// For an odd height the center row is its own mirror and is left alone.
kernel void MirrorVerticalTT(texture2d<float, access::read> Input [[texture(0)]],
                           texture2d<float, access::write> Output [[texture(1)]],
                           uint2 Position [[thread_position_in_grid]])
{
    uint Height = Output.get_height();
    if (Position.x >= Output.get_width() || Position.y >= Height)
    {
        // Ignore invalid positions.
        return;
    }
    uint2 Source = Position;
    if (Position.y > (Height - 1) / 2)
    {
        Source.y = Height - 1 - Position.y;
    }
    Output.write(Input.read(Source), Position);
}
