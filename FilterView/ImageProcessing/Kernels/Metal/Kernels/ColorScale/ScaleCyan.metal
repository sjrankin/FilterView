//
//  ScaleCyan.metal
//  FilterView
//
//  Created by Stuart Rankin on 11/1/26.
//

#include <metal_stdlib>
using namespace metal;

// Populate all channels with the mean of the blue and green channels (eg, cyan).
kernel void ScaleCyan(texture2d<float, access::read> Input [[texture(0)]],
                     texture2d<float, access::write> Output [[texture(1)]],
                     uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Color = Input.read(Position);
    float Cyan = (Color.g + Color.b) / 2;
    Output.write(float4(Cyan, Cyan, Cyan, Color.a), Position);
}

