Shader "Zebeyova/URP/hutaoBase" {
    Properties {
        [MainTexture]
        _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor]
        _BaseColor ("Base Color", Color) =  (1, 1, 1, 1)

        _RampTex ("Ramp Tex", 2D) = "white" {}
        _AmbientIntensity ("Ambient Intensity", Range(0, 5)) = 0.25

        _ShadowBands ("Shadow Bands", float) = 1
        _ShadowSoftness ("Shadow Softness", Range(0,0.2)) = 0.1
        _ShadowBrightness ("Shadow Brightness", float) = 1
    }

    SubShader {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass {
            Name "UniversalForward"

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 2.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/AmbientOcclusion.hlsl"

            struct Attributes {
                float2 uv : TEXCOORD0;
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
                float2 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float4 shadowCoord : TEXCOORD5;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _BaseColor;
            float _AmbientIntensity;
            float _ShadowBands;
            float _ShadowSoftness;
            float _ShadowBrightness;
            CBUFFER_END

            Varyings Vert(Attributes input) {
                Varyings o;
                VertexPositionInputs positionInput = GetVertexPositionInputs(input.positionOS.xyz);
                o.positionCS = positionInput.positionCS;
                o.positionWS = positionInput.positionWS;

                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                o.normalWS = normalInput.normalWS;
                o.tangentWS = normalInput.tangentWS;
                o.bitangentWS = normalInput.bitangentWS;

                o.shadowCoord = GetShadowCoord(positionInput);

                o.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return o;
            }

            half4 Frag(Varyings input) : SV_Target {
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 normalWS = normalize(input.normalWS);
                Light mainLight = GetMainLight(input.shadowCoord);
                half NdotL = saturate(dot(normalWS, mainLight.direction));
                half4 albedo = color * _BaseColor;
                half3 ambient = SampleSH(normalWS);
                half3 indirectLight = ambient * _AmbientIntensity;

                half lighting = saturate(NdotL * mainLight.shadowAttenuation);

                half bandCount = max(round(_ShadowBands), 2.0);
                half bandIndex = min(floor(lighting * bandCount), bandCount - 1.0);
                half bandUV = bandIndex / (bandCount - 1.0);

                half3 rampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, half2(bandUV, 0.5)).rgb;

                half3 directLight = rampColor * mainLight.color;
                half3 finalRGB = albedo.rgb * (directLight + indirectLight);
                return half4(finalRGB, albedo.a);
            }

            ENDHLSL
        }
    }
}