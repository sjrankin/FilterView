//
//  KMeansPaint.metal
//  FilterView
//
//  Created by Stuart Rankin on 10/28/26.
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

// K-means painting. The clusters have been found on the CPU; this gives every pixel to the nearest cluster center and paints it.
// It must give the same positions as `KMeansFeatures.Position` in KMeansClustering.swift.
//
// Parameters (buffer 0):
//   [0] the feature space: 0 RGB, 1 Lab, 2 HSB, 3 brightness, 4 hue, 5 saturation, 6 red, 7 green, 8 blue
//   [1] the number of dimensions of a position
//   [2] the number of clusters, up to 16
//   [4 ...] the centers, three numbers each, then 16 * 3 numbers of the colors the clusters are painted, three numbers each.

constant int MaxClusters = 16;

static float Brightness709(float3 C)
{
    return clamp(0.2126 * C.r + 0.7152 * C.g + 0.0722 * C.b, 0.0, 1.0);
}

static float SaturationOf(float3 C)
{
    float Highest = max(C.r, max(C.g, C.b));
    return Highest <= 0.0 ? 0.0 : (Highest - min(C.r, min(C.g, C.b))) / Highest;
}

// Hue as a share of the color wheel, 0 to 1.
static float HueOf(float3 C)
{
    float Highest = max(C.r, max(C.g, C.b));
    float Delta = Highest - min(C.r, min(C.g, C.b));
    if (Delta <= 0.0)
    {
        return 0.0;
    }
    float Sector;
    if (Highest == C.r)
    {
        Sector = (C.g - C.b) / Delta;
    }
    else if (Highest == C.g)
    {
        Sector = (C.b - C.r) / Delta + 2.0;
    }
    else
    {
        Sector = (C.r - C.g) / Delta + 4.0;
    }
    if (Sector < 0.0)
    {
        Sector += 6.0;
    }
    return Sector / 6.0;
}

static float LinearOf(float V)
{
    return V <= 0.04045 ? V / 12.92 : pow((V + 0.055) / 1.055, 2.4);
}

static float LabCurve(float V)
{
    return V > 0.008856 ? pow(V, 1.0 / 3.0) : 7.787 * V + 16.0 / 116.0;
}

// The position of a color in the chosen feature space.
static float3 PositionOf(int Feature, float3 C)
{
    switch (Feature)
    {
        case 0:
            return C;
        case 1:
        {
            float R = LinearOf(C.r);
            float G = LinearOf(C.g);
            float B = LinearOf(C.b);
            float X = LabCurve((0.4124564 * R + 0.3575761 * G + 0.1804375 * B) / 0.95047);
            float Y = LabCurve(0.2126729 * R + 0.7151522 * G + 0.0721750 * B);
            float Z = LabCurve((0.0193339 * R + 0.1191920 * G + 0.9503041 * B) / 1.08883);
            float L = 116.0 * Y - 16.0;
            float A = 500.0 * (X - Y);
            float BB = 200.0 * (Y - Z);
            return float3(L / 100.0, (A + 128.0) / 255.0, (BB + 128.0) / 255.0);
        }
        case 2:
        {
            float Angle = HueOf(C) * 2.0 * M_PI_F;
            float Value = max(C.r, max(C.g, C.b));
            float S = SaturationOf(C);
            return float3(S * Value * cos(Angle) * 0.5 + 0.5, S * Value * sin(Angle) * 0.5 + 0.5, Value);
        }
        case 3:
            return float3(Brightness709(C), 0.0, 0.0);
        case 4:
        {
            float Angle = HueOf(C) * 2.0 * M_PI_F;
            return float3(cos(Angle) * 0.5 + 0.5, sin(Angle) * 0.5 + 0.5, 0.0);
        }
        case 5:
            return float3(SaturationOf(C), 0.0, 0.0);
        case 6:
            return float3(C.r, 0.0, 0.0);
        case 7:
            return float3(C.g, 0.0, 0.0);
        default:
            return float3(C.b, 0.0, 0.0);
    }
}

kernel void KMeansPaint(texture2d<float, access::read> Input [[texture(0)]],
                        texture2d<float, access::write> Output [[texture(1)]],
                        constant float* P [[buffer(0)]],
                        uint2 Position [[thread_position_in_grid]])
{
    if (Position.x >= Output.get_width() || Position.y >= Output.get_height())
    {
        return;
    }
    float4 Pixel = Input.read(Position);
    // Fully transparent pixels have no color and are left alone.
    if (Pixel.a <= 0.0)
    {
        Output.write(Pixel, Position);
        return;
    }
    int Feature = int(P[0]);
    int Dimensions = int(P[1]);
    int Count = min(int(P[2]), MaxClusters);
    // The image holds colors multiplied by alpha, so they are divided back out.
    float3 Color = min(Pixel.rgb / Pixel.a, float3(1.0));
    float3 Where = PositionOf(Feature, Color);
    int Best = 0;
    float BestDistance = INFINITY;
    for (int Cluster = 0; Cluster < Count; Cluster++)
    {
        float Distance = 0.0;
        for (int Axis = 0; Axis < Dimensions; Axis++)
        {
            float Difference = Where[Axis] - P[4 + Cluster * 3 + Axis];
            Distance += Difference * Difference;
        }
        if (Distance < BestDistance)
        {
            BestDistance = Distance;
            Best = Cluster;
        }
    }
    int PaintedAt = 4 + MaxClusters * 3 + Best * 3;
    float3 Painted = float3(P[PaintedAt], P[PaintedAt + 1], P[PaintedAt + 2]);
    Output.write(float4(Painted * Pixel.a, Pixel.a), Position);
}
