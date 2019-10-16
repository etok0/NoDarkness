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
		"Default = 1";
> = 1.0;

uniform float f_LerpCoef< __UNIFORM_SLIDER_FLOAT1
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Alpha";
	ui_category = "General settings";
	ui_tooltip = "actually thats not alpha dude =\\\n"
		"this number used in linear interpolation... but dont pls tell to anybody";
> = 1.0;

uniform float LimitStrength <
	ui_min = 0.000001; ui_max = 1;
	ui_label = "LimitStrength";
	ui_category = "General settings";
	ui_tooltip = "Default = 0.000001\n"
		"Min = 0.000001\n"
		"Max = 1.0";
> = 0.000001;


uniform bool Enable_log <
	ui_tooltip = "To prevent Clipping";
ui_category = "To prevent Clipping";
> = false;

uniform bool Enable_atan <
	ui_tooltip = "To prevent Clipping";
ui_category = "To prevent Clipping";
> = false;

uniform bool Enable_tanh <
	ui_tooltip = "To prevent Clipping";
ui_category = "To prevent Clipping";
> = true;

texture2D TexLuma { Width = 256; Height = 256; Format = R8; MipLevels = 7; };
texture2D TexAvgLuma { Format = R16F; };

sampler SamplerLuma { Texture = TexLuma; };
sampler SamplerAvgLuma { Texture = TexAvgLuma; };

float PS_Luma(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float4 color = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0));
    return dot(color.xyz, float3(f_StrengthCoeff.xxx));
}

float PS_AvgLuma(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    return tex2Dlod(SamplerLuma, float4(0.5.xx, 0, f_TriggerRadius)).x;
}

float3 PS_Adaption(float4 pos : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
	float avgLuma = max(LimitStrength, tex2Dlod(SamplerAvgLuma, float4(0.0.xx, 0, 0)).x);
	float3 colorInput = tex2Dlod(ReShade::BackBuffer, float4(texcoord, 0, 0)).rgb;

	float3 color = colorInput / avgLuma;
	   
	if (Enable_log == true)
	{
		color = log(1 + color);
	}

	if (Enable_atan == true)
	{
		color = atan(color);
	}		

	if (Enable_tanh == true)
	{
		color = tanh(color);
	}

	return lerp(colorInput, color, f_LerpCoef);
}

technique NoDarkness
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
