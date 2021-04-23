//
//  Shader.metal
//  MetalDemo
//
//  Created by VislaNiap on 2021/3/29.
//

#include <metal_stdlib>
using namespace metal;

//在Metal中用[[…]]包含的这种变量实际上着色器的内置变量/内置函数
struct VertexIn{
    float4 position [[attribute(0)]];//为啥不用float3,那是因为，返回值是float4,不然还需要new一个float4
    float4 color [[attribute(1)]];
    float2 textureCoordinates [[attribute(2)]];
};
struct VertexOut{
    float4 position [[position]];//position 告诉渲染器，这个字段是用作位置信息。
    float4 color ;
    float2 textureCoordinates;
};

vertex VertexOut vertex_shader(const VertexIn  vertexIn [[stage_in]] ){
    VertexOut vertexOut;
    vertexOut.position = vertexIn.position;
    vertexOut.color = vertexIn.color;
    vertexOut.textureCoordinates = vertexIn.textureCoordinates;
    return vertexOut;
}

fragment half4 fragment_shader(const VertexOut  vertexIn [[stage_in]],
                               texture2d<float> texture [[texture(0)]]){
    constexpr sampler defaultSampler;
    float4 color = texture.sample(defaultSampler, vertexIn.textureCoordinates);
    return half4(color.r,color.g,color.b,1);
}
