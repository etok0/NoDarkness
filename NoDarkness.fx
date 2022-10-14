// NoDarkness by Etok

#include "ReShade.fxh"
#include "ReShadeUI.fxh"


uniform bool EnableNormals < ui_category = "Normals";
	ui_label = "Enable Normals";
	ui_tooltip =
		"Enables normals\n"
		"\nDefault: On";
> = true;

uniform float f_NormalLerpCoef < __UNIFORM_SLIDER_FLOAT1
    ui_min = 0.0; ui_max = 1.0;
	ui_label = "Alpha";
    ui_category = "Normals";
	ui_tooltip = "this number used in linear interpolation\n"
		"Default = 0.8";
> = 0.8;

uniform bool EnableExposure < ui_category = "General settings";
	ui_label = "Enable Exposure";
	ui_tooltip =
		"Enables Exposure stuff\n"
		"\nDefault: On";
> = true;

uniform float f_TriggerRadius < __UNIFORM_SLIDER_FLOAT1
    ui_label = "Radius";
    ui_tooltip = "Screen area\n"
                 "1 = only the center of the image is used\n"
                 "7 = the whole image is used";
    ui_category = "General settings";
    ui_min = 1.0;
    ui_max = 7.0;
    ui_step = 0.25;
> = 7.0;

uniform float f_StrengthCoeff < __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.1; ui_max = 5.0;
	ui_label = "Strength Divider";
	ui_category = "General settings";
	ui_tooltip = "Smaller = Stronger\n"
		"Default = 2";
> = 2.0;

uniform float f_LerpCoef< __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Alpha";
	ui_category = "General settings";
	ui_tooltip = "this number used in linear interpolation\n"
		"Default = 0.8";
> = 0.8;

uniform int FuncW < __UNIFORM_RADIO_INT1
	ui_label = "Function to reduce clipping of whites";
	ui_tooltip = "";
	ui_items = "Log()\0Atan()\0None\0";
	ui_category = "Function to reduce clipping of whites";
> = 0;

uniform float LimitStrength <
	ui_min = 0.0001; ui_max = 1;
	ui_label = "LimitStrength";
	ui_category = "General settings";
	ui_tooltip = "Default = 0.02\n"
		"Min = 0.0001\n"
		"Max = 1.0";
> = 0.02;

texture2D TexLuma { Width = 256; Height = 256; Format = R8; MipLevels = 7; };
sampler SamplerLuma { Texture = TexLuma; };

texture2D TexAvgLuma { Format = R16F; };
sampler SamplerAvgLuma { Texture = TexAvgLuma; };

#define LumCoeff float3(0.212656, 0.715158, 0.072186)

float PS_Luma(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float4 color = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0));
    return dot(color.xyz, f_StrengthCoeff);
}

float PS_AvgLuma(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return tex2Dlod(SamplerLuma, float4(0.5.xx, 0, f_TriggerRadius)).x;
}

float GetLinearizedDepth(float2 texcoord)
{
    return tex2Dlod(ReShade::DepthBuffer, float4(texcoord, 0, 0)).x;
}

float3 PS_Adaption(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 colorInput = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0)).xyz;
    float avgLuma = tex2Dlod(SamplerAvgLuma, float4(0,0,0,0)).x;
    float xam = 1 - avgLuma;
    float3 color;
    if (EnableExposure) color = colorInput / max(LimitStrength, avgLuma);
    else color = colorInput;

    if (EnableNormals)
    {
        float3 offset = float3(BUFFER_PIXEL_SIZE, 0.0);
	float2 posCenter = texcoord.xy;
	float2 posNorth  = posCenter - offset.zy;
	float2 posEast   = posCenter + offset.xz;

	float3 vertCenter = float3(posCenter - 0.5, 1) * GetLinearizedDepth(posCenter);
	float3 vertNorth  = float3(posNorth - 0.5,  1) * GetLinearizedDepth(posNorth);
	float3 vertEast   = float3(posEast - 0.5,   1) * GetLinearizedDepth(posEast);

        float3 norm = dot((normalize(cross(vertCenter - vertNorth, vertCenter - vertEast)) * 0.5 + 0.5).xyz, LumCoeff);
        color = lerp(color, pow(max(LimitStrength, color), norm), f_NormalLerpCoef);        
    }

    switch(FuncW)
    {
        case 0:{ color = lerp(colorInput, log(1 + color), xam * f_LerpCoef); break; } // Log
        case 1:{ color = lerp(colorInput, sin(atan(color) - 0.5) + 0.5, xam * f_LerpCoef); break; } // Atan
        case 2:{ color = lerp(colorInput, color, xam * f_LerpCoef); break; } // None
    }
    
    return color;
}

technique NoDarkness<ui_tooltip = "Variation of Auto-Exposure by Etok";>
{
    pass Luma
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Luma;
        RenderTarget = TexLuma;
    }
    
    pass AvgLuma
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_AvgLuma;
        RenderTarget = TexAvgLuma;
    }

    pass Adaption
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_Adaption;
    }
}
