#include "mta-helper.fx"

float3 ambient = float3(0.1,0.1,0.1);
float4 dayparam = float4(1,1,1,1);
float4 nightparam = float4(0,0,0,0);
float3 surfProps = float3(16.0f, 0.0, 0.0);

texture tex < string textureState="0,Texture"; >;


sampler2D Sample = sampler_state
{
    Texture = (tex);
};

struct VSInput
{
    float3 Position : POSITION0;
    float2 TexCoord : TEXCOORD0;
    float4 NightColor : COLOR0;
    float4 DayColor : COLOR1;
};

struct PSInput
{
    float4 Position : POSITION0;
    float2 Texcoord : TEXCOORD0;
    float4 Color : COLOR0;
};

PSInput VertexShaderFunction(VSInput VS)
{
    PSInput PS = (PSInput)0;

    // Calculate position
    PS.Position = mul(float4(VS.Position, 1), gWorldViewProjection);

    // Transform texture coordinates
    //PS.Texcoord0.xy = mul(gTexMatrix, float4(VS.TexCoord, 0.0, 1.0)).xy;

    // Calculate day/night color transition
    PS.Color = VS.DayColor * dayparam + VS.NightColor * nightparam;

    // Apply material color and scaling
    //PS.Color *= gMaterialColor / gShaderParams.x;

    // Add ambient lighting
    PS.Color.rgb += ambient * 128.0/255.0;

    // Calculate fog factor
    //PS.Texcoord0.z = clamp((PS.Position.w - gFogData.y) * gFogData.z, gFogData.w, 1.0);
    PS.Texcoord = VS.TexCoord;

    return PS;
}


// float4 main(PS_INPUT IN) : COLOR
// {
// 	return tex2D(Sample, IN.texcoord0.xy) ;
// }
technique simplePS
{
    pass P0
    {
        VertexShader = compile vs_2_0 VertexShaderFunction();
    }

}
