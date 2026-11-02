//
//  ScaleCyanColor.metal
//  FilterView
//
//  Created by Stuart Rankin on 11/1/26.
//

#include <metal_stdlib>
using namespace metal;

// Set the red to 0 and the green and blue channels to the mean of the green and blue channels
kernel void ScaleCyanColor(texture2d<float, access::read> Input [[texture(0)]],
                            texture2d<float, access::write> Output [[texture(1)]],
                            uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Color = Input.read(Position);
    float Cyan = (Color.g + Color.b) / 2;
    Output.write(float4(0, Cyan, Cyan, Color.a), Position);
}
