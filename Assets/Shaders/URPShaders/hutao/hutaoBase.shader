Shader "Zebeyova/URP/hutaoBase" {
    Properties {
        [MainTexture]
        _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor]
        _BaseColor ("Base Color", Color) =  (1, 1, 1, 1)

        _RampTex ("Ramp Tex", 2D) = "white" {}
        _AmbientIntensity ("Ambient Intensity", Range(0, 5)) = 0
        _NormalTex ("Normal Tex", 2D) = "bump" {}
        _NormalScale ("Normal Scale", Range(0,2)) = 1

        [Space]
        [Header(Shadow)]
        [IntRange]
        _ShadowBands ("Shadow Bands", Range(1,10)) = 2
        _ShadowBrightness ("Shadow Brightness", Range(0,1)) = 0.5
        _ShadowThreshold ("Shadow Threshold", Range(0,1)) = 0.5
        _ShadowSoftness ("Shadow Softness", Range(0,0.1)) = 0.01

        [Space]
        [Header(Rim)]
        _RimColor ("Rim Color", Color) =  (1, 1, 1, 1)
        _RimIntensity ("Rim Intensity", Range(0,1)) = 0.5
        _RimThreshold ("Rim Threshlod", Range(0,1)) = 0.5
        _RimSoftness ("Rim Softness", Range(0,0.5)) = 0.1

        [Space]
        [Header(Specular)]
        _SpecularTex ("Specular Tex", 2D) = "white" {}
        _SpecularColor ("Specular Color", Color) =  (1, 1, 1, 1)
        _SpecularIntensity ("Specular Intensity", Range(0,1)) = 0.5
        _SpecularGloss ("Specular Gloss", Range(1,500)) = 32
        _SpecularThreshold ("Specular Threshold", Range(0,1)) = 0.9
        _SpecularSoftness ("Specular Softness", Range(0,0.1)) = 0.01

        [Space]
        [Header(Outline)]
        [Toggle(_OUTLINE_ON)]
        _EnableOutline ("Enable Outline ?", float) = 1
        _OutlineColor ("Outline Color", Color) =  (0, 0, 0, 1)
        _OutlineWidthMutiplier ("Outline Width", Range(0,0.05)) = 0.01
    }

    SubShader {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        TEXTURE2D(_BaseMap);        SAMPLER(sampler_BaseMap);
        TEXTURE2D(_RampTex);        SAMPLER(sampler_RampTex);
        TEXTURE2D(_NormalTex);        SAMPLER(sampler_NormalTex);
        TEXTURE2D(_SpecularTex);        SAMPLER(sampler_SpecularTex);

        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        float4 _BaseColor;
        float _AmbientIntensity;
        float _NormalScale;

        float _ShadowBands;
        float _ShadowSoftness;
        float _ShadowBrightness;
        float _ShadowThreshold;

        float4 _RimColor;
        float _RimIntensity;
        float _RimThreshold;
        float _RimSoftness;

        float4 _SpecularColor;
        float _SpecularIntensity;
        float _SpecularGloss;
        float _SpecularThreshold;
        float _SpecularSoftness;

        float4 _OutlineColor;
        float _OutlineWidthMutiplier;
        CBUFFER_END
        ENDHLSL

        Pass {
            Name "hutao"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 2.0

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
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float4 shadowCoord : TEXCOORD5;
            };

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
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, input.uv), _NormalScale);
                half3 normalWS = normalize(input.tangentWS * normalTS.x + input.bitangentWS * normalTS.y + input.normalWS * normalTS.z);
                Light mainLight = GetMainLight(input.shadowCoord);
                half3 viewDir = normalize(_WorldSpaceCameraPos - input.positionWS);

                half NdotL = dot(normalWS, mainLight.direction);
                half halfLambert = NdotL * 0.5 + 0.5;
                half3 rampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(halfLambert * mainLight.shadowAttenuation, 0.5)).rgb;
                half shadow = smoothstep(_ShadowThreshold - _ShadowSoftness, _ShadowThreshold + _ShadowSoftness, halfLambert);
                half3 litColor = baseColor.xyz * _BaseColor.xyz;
                half3 shadowColor = litColor * rampColor * _ShadowBrightness;

                half NdotV = saturate(dot(normalWS, viewDir));
                half rim = 1.0 - NdotV;
                half rimMask = smoothstep(_RimThreshold - _RimSoftness, _RimThreshold + _RimSoftness, rim);
                half3 rimlight = _RimColor.rgb * rimMask * _RimIntensity;

                half3 halfDir = normalize(viewDir + mainLight.direction);
                half NdotH = saturate(dot(normalWS, halfDir));
                half specularMaskTex = SAMPLE_TEXTURE2D(_SpecularTex, sampler_SpecularTex, input.uv).r;
                half specularIntensity = pow(NdotH, _SpecularGloss);
                half specularMask = smoothstep(_SpecularThreshold - _SpecularSoftness, _SpecularThreshold + _SpecularSoftness, specularIntensity);
                half3 specularLight = specularMaskTex * specularMask * _SpecularColor.rgb * _SpecularIntensity;

                half3 finalColor = lerp(shadowColor, litColor, shadow) + rimlight + specularLight;
                return half4(finalColor, 1.0);
            }

            ENDHLSL
        }
        Pass {
            Name "OutLine"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            Cull Front
            HLSLPROGRAM
            #pragma vertex OutlineVert
            #pragma fragment OutlineFrag

            #pragma shader_feature _OUTLINE_ON

            struct OutlineAttributes {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct OutlineVaryings {
                float4 positionCS : SV_POSITION;
            };

            OutlineVaryings OutlineVert(OutlineAttributes input) {
                OutlineVaryings o;

                float3 expandedPos = input.positionOS.xyz + input.normalOS * 0.001 * _OutlineWidthMutiplier;
                VertexPositionInputs positionInput = GetVertexPositionInputs(expandedPos);
                o.positionCS = positionInput.positionCS;
                return o;
            }
            half4 OutlineFrag(OutlineVaryings input) : SV_TARGET {
                #ifdef _OUTLINE_ON
                return _OutlineColor;
                #endif
discard;
            }
            ENDHLSL
        }
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            HLSLPROGRAM
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
    }
}