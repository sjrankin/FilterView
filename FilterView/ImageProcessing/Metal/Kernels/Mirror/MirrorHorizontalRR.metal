//
//  MirrorHorizontalRR.metal
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

#include <metal_stdlib>
using namespace metal;

// Copies the right half of the image over the left half, flipped left to right, so the two halves meet with no seam.
// Each thread writes only its own pixel; pixels in the left half read from the mirrored column in the right half.
// For an odd width the center column is its own mirror and is left alone.
kernel void MirrorHorizontalRR(texture2d<float, access::read> Input [[texture(0)]],
                   texture2d<float, access::write> Output [[texture(1)]],
                   uint2 Position [[thread_position_in_grid]])
{
    uint Width = Output.get_width();
    if (Position.x >= Width || Position.y >= Output.get_height())
    {
        // Ignore invalid positions.
        return;
    }
    uint2 Source = Position;
    if (Position.x < Width / 2)
    {
        Source.x = Width - 1 - Position.x;
    }
    Output.write(Input.read(Source), Position);
}
