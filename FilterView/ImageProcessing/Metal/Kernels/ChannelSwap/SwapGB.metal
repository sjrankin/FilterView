//
//  SwapGB.metal
//  FilterView
//
//  Created by Stuart Rankin on 10/29/26.
//

#include <metal_stdlib>
using namespace metal;

// Inverts only the blue channel.
kernel void SwapGB(texture2d<float, access::read> Input [[texture(0)]],
                   texture2d<float, access::write> Output [[texture(1)]],
                   uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Color = Input.read(Position);
    Output.write(float4(Color.r, Color.b, Color.g, Color.a), Position);
}
