// SPDX-License-Identifier: GPL-3.0-or-later

#include <metal_stdlib>
using namespace metal;

struct RevivalWorldVertex {
    float4 position;
    float4 textureAndLightmapUV;
    float4 presentation;
    float4 surfaceColor;
};

struct RevivalWorldUniforms {
    float4x4 worldToClip;
};

struct RevivalWorldRaster {
    float4 position [[position]];
    float2 textureUV;
    float2 lightmapUV;
    float opacity;
    float tintMode;
    float4 surfaceColor;
};

vertex RevivalWorldRaster revivalWorldVertex(
    uint vertexID [[vertex_id]],
    device const RevivalWorldVertex *vertices [[buffer(0)]],
    constant RevivalWorldUniforms &uniforms [[buffer(1)]])
{
    RevivalWorldVertex sourceVertex = vertices[vertexID];
    RevivalWorldRaster output;
    output.position = uniforms.worldToClip * sourceVertex.position;
    output.textureUV = float2(
        sourceVertex.textureAndLightmapUV.x,
        1.0 - sourceVertex.textureAndLightmapUV.y
    );
    output.lightmapUV = float2(
        sourceVertex.textureAndLightmapUV.z,
        1.0 - sourceVertex.textureAndLightmapUV.w
    );
    output.opacity = sourceVertex.presentation.x;
    output.tintMode = sourceVertex.presentation.z;
    output.surfaceColor = sourceVertex.surfaceColor;
    return output;
}

fragment float4 revivalWorldFragment(
    RevivalWorldRaster input [[stage_in]],
    texture2d<float> baseTexture [[texture(0)]],
    texture2d<float> lightmapTexture [[texture(1)]],
    sampler baseSampler [[sampler(0)]],
    sampler lightmapSampler [[sampler(1)]])
{
    float4 sampled = baseTexture.sample(baseSampler, input.textureUV);
    float4 base;
    if (input.surfaceColor.w > 0.5) {
        base = float4(input.surfaceColor.rgb, 1.0);
    } else if (input.tintMode > 0.5) {
        base = float4(sampled.rgb * input.surfaceColor.rgb, sampled.a);
    } else {
        base = sampled;
    }
    float3 lightmap = lightmapTexture.sample(
        lightmapSampler,
        input.lightmapUV
    ).rgb;
    return float4(base.rgb * lightmap, base.a * input.opacity);
}
