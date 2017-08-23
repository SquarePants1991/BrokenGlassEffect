//
//  Shader.metal
//  BrokenGlassEffect
//
//  Created by wang yang on 2017/8/21.
//  Copyright © 2017年 ocean. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


#include <metal_stdlib>
using namespace metal;

struct VertexIn
{
    packed_float3  position;
    packed_float2  pointPosition;
};

struct VertexOut
{
    float4  position [[position]];
    float2  pointPosition;
    float pointSize [[ point_size ]];
};

struct Uniforms
{
    packed_float2 pointTexcoordScale;
    float pointSizeInPixel;
};

vertex VertexOut passThroughVertex(uint vid [[ vertex_id ]],
                                   const device VertexIn* vertexIn [[ buffer(0) ]],
                                   const device Uniforms& uniforms [[ buffer(1) ]],
                                   const device float4x4* transforms [[ buffer(2) ]])
{
    VertexOut outVertex;
    VertexIn inVertex = vertexIn[vid];
    outVertex.position = transforms[vid] * float4(inVertex.position, 1.0);
    outVertex.pointPosition = inVertex.pointPosition;
    outVertex.pointSize = uniforms.pointSizeInPixel;
    return outVertex;
};

constexpr sampler s(coord::normalized, address::repeat, filter::linear);

fragment float4 passThroughFragment(VertexOut inFrag [[stage_in]],
                                    float2 pointCoord  [[point_coord]],
                                     texture2d<float> diffuse [[ texture(0) ]],
                                    const device Uniforms& uniforms [[ buffer(0) ]])
{
    float2 additionUV = float2((pointCoord[0]) * uniforms.pointTexcoordScale[0], (1.0 - pointCoord[1]) * uniforms.pointTexcoordScale[1]);
    float2 uv = inFrag.pointPosition + additionUV;
    uv = float2(uv[0], uv[1]);
    float4 finalColor = diffuse.sample(s, uv);
    return finalColor;
};
