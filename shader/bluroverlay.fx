texture sourceTexture;
texture blurBuffer;
float offset;        // Scaled offset value
float4 overlayColor; // color overlay
bool isInitialized;  // Initialization state

sampler SourceSampler = sampler_state {
    Texture = <sourceTexture>;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

sampler BlurBufferSampler = sampler_state {
    Texture = <blurBuffer>;
    MinFilter = Linear;
    MagFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
};

float4 PSMain(float2 texCoord : TEXCOORD0) : COLOR0 
{
    // Sample with progressive offset pattern
    float4 base = tex2D(SourceSampler, texCoord);
    
    // Apply offsets matching original vertex pattern
    float4 xOffset = tex2D(SourceSampler, texCoord + float2(offset, 0));
    float4 xyOffset = tex2D(SourceSampler, texCoord + float2(offset, offset));
    float4 yOffset = tex2D(SourceSampler, texCoord + float2(0, offset));
    
    // Combine samples (matching vertex quad weights)
    float4 color = (base + xOffset + xyOffset + yOffset) * 0.25;
    
    // Add color overlay
    color += overlayColor;
    
    // Blend with previous frame if initialized
    if (isInitialized) {
        float4 previous = tex2D(BlurBufferSampler, texCoord);
        color = lerp(color, previous, 32.0/255.0);
    }
    
    color.a = 1.0;
    return color;
}

technique BlurOverlay
{
    pass P0
    {
        PixelShader = compile ps_2_0 PSMain();
        AlphaTestEnable = false;
        AlphaBlendEnable = true;
        BlendOp = Add;
        SrcBlend = BlendFactor;
        DestBlend = InvBlendFactor;
    }
}