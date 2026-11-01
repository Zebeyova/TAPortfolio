Shader "Zebeyova/URP/Bush" {
    Properties {
        [MainTexture]
        _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor]
        _BaseColor ("Base Color", Color) =  (1, 1, 1, 1)
        _AlbedoTex ("Albedo Tex", 2D) = "white" {}
        _NormalTex ("Normal Tex", 2D) = "white" {}
    }

    SubShader {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
        TEXTURE2D(_AlbedoTex);        SAMPLER(sampler_AlbedoTex);
        TEXTURE2D(_NormalTex);        SAMPLER(sampler_NormalTex);

        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        float4 _BaseColor;
        CBUFFER_END
        ENDHLSL

        Pass {
            Name "Bush"
            Tags { "LightMode" = "UniversalForward" }
            Cull Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 2.0

            struct Attributes {
                float2 uv : TEXCOORD0;
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float3 tangentOS : TANGENT;
            };

            struct Varyings {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
            };

            Varyings Vert(Attributes input) {
                Varyings o;

                VertexPositionInputs posInput = GetVertexPositionInputs(input.positionOS.xyz);
                o.positionCS = posInput.positionCS;
                o.positionWS = posInput.positionWS;

                VertexNormalInputs norInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                o.normalWS = norInput.normalWS;
                o.tangentWS = norInput.tangentWS;
                o.bitangentWS = norInput.bitangentWS;

                o.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return o;
            }

            half4 Frag(Varyings input) : SV_Target {
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);

                half3 finalColor = baseColor.rgb;
                return half4(finalColor, 1.0);
            }

            ENDHLSL
        }
    }
}