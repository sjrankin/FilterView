//
//  ScaleYellowColor.metal
//  FilterView
//
//  Created by Stuart Rankin on 11/1/26.
//

#include <metal_stdlib>
using namespace metal;

// Set the blue to 0 and the red and green channels to the mean of the red and green channels
kernel void ScaleYellowColor(texture2d<float, access::read> Input [[texture(0)]],
                              texture2d<float, access::write> Output [[texture(1)]],
                              uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Color = Input.read(Position);
    float Yellow = (Color.r + Color.g) / 2;
    Output.write(float4(Yellow, Yellow, 0, Color.a), Position);
}
