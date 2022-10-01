// NoDarkness by Etok

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

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
	ui_min = 0.00001; ui_max = 1;
	ui_label = "LimitStrength";
	ui_category = "General settings";
	ui_tooltip = "Default = 0.01\n"
		"Min = 0.00001\n"
		"Max = 1.0";
> = 0.01;

texture2D TexLuma { Width = 256; Height = 256; Format = R8; MipLevels = 7; };
sampler SamplerLuma { Texture = TexLuma; };

texture2D TexAvgLuma { Format = R16F; };
sampler SamplerAvgLuma { Texture = TexAvgLuma; };

float PS_Luma(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float4 color = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0));
    return dot(color.xyz, f_StrengthCoeff);
}

float PS_AvgLuma(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return tex2Dlod(SamplerLuma, float4(0.5.xx, 0, f_TriggerRadius)).x;
}

float3 PS_Adaption(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 colorInput = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0)).xyz;
    float avgLuma = tex2Dlod(SamplerAvgLuma, float4(0.0.xx, 0, 0)).x;
    float3 color = colorInput / max(LimitStrength, avgLuma);

    switch(FuncW)
	{
		case 0:{ color = lerp(colorInput, sin(log(1 + color) - 0.5) + 0.5, (1 - avgLuma) * f_LerpCoef); break; } // Log
		case 1:{ color = lerp(colorInput, sin(atan(color) - 0.5) + 0.5, (1 - avgLuma) * f_LerpCoef); break; } // Atan
		case 2:{ color = lerp(colorInput, color, (1 - avgLuma) * f_LerpCoef); break; } // None
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
