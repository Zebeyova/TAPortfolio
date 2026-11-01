Shader "Zebeyova/URP/hutaoBase" {
    Properties {
        [MainTexture]
        _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor]
        _BaseColor ("Base Color", Color) =  (1, 1, 1, 1)

        _RampTex ("Ramp Tex", 2D) = "white" {}
        _NormalTex ("Normal Tex", 2D) = "bump" {}
        _NormalScale ("Normal Scale", Range(0,2)) = 1

        [Space]
        [Header(Shadow)]
        _ShadowThreshold ("Shadow Threshold", Range(0,1)) = 0.5
        _ShadowSoftness ("Shadow Softness", Range(0,0.1)) = 0.01

        [Space]
        [Header(Rim)]
        _RimColor ("Rim Color", Color) =  (1, 1, 1, 1)
        _RimIntensity ("Rim Intensity", Range(0,1)) = 0.5
        _RimThreshold ("Rim Threshold", Range(0,1)) = 0.5
        _RimSoftness ("Rim Softness", Range(0,0.5)) = 0.1

        [Space]
        [Header(Specular)]
        [Toggle(_SPECULAR_ON)]
        _Specular ("Use Specular ?", float) = 1
        _SpecularTex ("Specular Tex", 2D) = "white" {}
        _SpecularColor ("Specular Color", Color) =  (1, 1, 1, 1)
        _SpecularIntensity ("Specular Intensity", Range(0,1)) = 0.5
        _SpecularGloss ("Specular Gloss", Range(1,500)) = 32
        _SpecularThreshold ("Specular Threshold", Range(0,1)) = 0.9
        _SpecularSoftness ("Specular Softness", Range(0,0.1)) = 0.01

        [Space]
        [Header(Anisotropic_Specular)]
        [Toggle(_ANISOTROPIC_HAIR)]
        _AnisotropicHair ("Use Anisotropic Hair Specular ?", float) = 0
        _SpecularShift ("Specular Shift 1", Range(-1,1)) = 0
        _Specular1Intensity ("Specular 1 Intensity", Range(0,1)) = 0.2
        _SpecularShift2 ("Specular Shift 2", Range(-1,1)) = 0.1
        _Specular2Intensity ("Specular 2 Intensity", Range(0,1)) = 0.2

        [Space]
        [Header(Outline)]
        [Toggle(_OUTLINE_ON)]
        _Outline ("Use Outline ?", float) = 1
        _OutlineColor ("Outline Color", Color) =  (0, 0, 0, 1)
        _OutlineWidth ("Outline Width", Range(0,1)) = 0.5
        _DistFactor ("Distance Factor", float) = 1
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
        float _NormalScale;

        float _ShadowSoftness;
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

        float _SpecularShift;
        float _Specular1Intensity;
        float _SpecularShift2;
        float _Specular2Intensity;

        float4 _OutlineColor;
        float _OutlineWidth;
        float _DistFactor;
        CBUFFER_END
        ENDHLSL

        Pass {
            Name "hutao"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma shader_feature_local _ANISOTROPIC_HAIR
            #pragma shader_feature_local _SPECULAR_ON
            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 2.0

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
            };

            //kajiya-kay 各向异性高光
            half StrandSpecular(half3 tangent, half3 halfDir, half gloss) {
                half TdotH = dot(tangent, halfDir);
                half sinTH = sqrt(1 - TdotH * TdotH);
                half dirAtten = smoothstep(-1, 0, TdotH);
                return dirAtten * pow(sinTH, gloss);
            }
            half3 ShiftTangent(half3 tangent, half3 normal, half shift) {
                return normalize(tangent + normal * shift);
            }

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
                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, input.uv), _NormalScale);
                half3 normalWS = normalize(input.tangentWS * normalTS.x + input.bitangentWS * normalTS.y + input.normalWS * normalTS.z);
                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                half3 viewDir = normalize(_WorldSpaceCameraPos - input.positionWS);

                half NdotL = dot(normalWS, mainLight.direction);
                half halfLambert = NdotL * 0.5 + 0.5;
                half3 rampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(0.5, halfLambert * mainLight.shadowAttenuation)).rgb;
                half shadow = smoothstep(_ShadowThreshold - _ShadowSoftness, _ShadowThreshold + _ShadowSoftness, halfLambert);
                half3 litColor = baseColor.xyz * _BaseColor.xyz;
                half3 shadowColor = litColor * rampColor;

                half NdotV = saturate(dot(normalWS, viewDir));
                half rim = 1.0 - NdotV;
                half rimMask = smoothstep(_RimThreshold - _RimSoftness, _RimThreshold + _RimSoftness, rim);
                half3 rimlight = _RimColor.rgb * rimMask * _RimIntensity;

                half3 specularLight = 0;
#ifdef _SPECULAR_ON
                half3 halfDir = normalize(viewDir + mainLight.direction);
                half specularMaskTex = SAMPLE_TEXTURE2D(_SpecularTex, sampler_SpecularTex, input.uv).r;
#ifdef _ANISOTROPIC_HAIR
                //第一层高光
                half3 tangent1 = ShiftTangent(input.tangentWS, input.normalWS, _SpecularShift);
                half spec1 = StrandSpecular(tangent1, halfDir, _SpecularGloss);
                //第二层高光
                half3 tangent2 = ShiftTangent(input.tangentWS, input.normalWS, _SpecularShift2);
                half spec2 = StrandSpecular(tangent2, halfDir, _SpecularGloss);

                half specTotal = (spec1 * _Specular1Intensity + spec2 * _Specular2Intensity);
                specularLight = specularMaskTex * specTotal * _SpecularColor.rgb * _SpecularIntensity;
#else
                half NdotH = saturate(dot(normalWS, halfDir));
                half specularIntensity = pow(NdotH, _SpecularGloss);
                half specularMask = smoothstep(_SpecularThreshold - _SpecularSoftness, _SpecularThreshold + _SpecularSoftness, specularIntensity);
                specularLight = specularMaskTex * specularMask * _SpecularColor.rgb * _SpecularIntensity;
#endif
#endif
                half3 finalColor = lerp(shadowColor, litColor, shadow) + rimlight + specularLight * shadow;

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
            #pragma shader_feature_local _OUTLINE_ON

            struct OutlineAttributes {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct OutlineVaryings {
                float4 positionCS : SV_POSITION;
            };

            OutlineVaryings OutlineVert(OutlineAttributes input) {
                OutlineVaryings o;

                VertexPositionInputs positionInput = GetVertexPositionInputs(input.positionOS.xyz);
                o.positionCS = positionInput.positionCS;

                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
                float2 offset = SafeNormalize(float3(TransformWorldToHClipDir(normalWS).xy, 0)).xy;

                offset *= _OutlineWidth * 2.0 / _ScreenParams.y;
                offset.x *= _ScreenParams.y / _ScreenParams.x;

                float dist = length(positionInput.positionWS - _WorldSpaceCameraPos);
                float distanceFactor = saturate(1.0 / (dist * _DistFactor));

                o.positionCS.xy += offset * o.positionCS.w * distanceFactor;
                return o;
            }
            half4 OutlineFrag(OutlineVaryings input) : SV_TARGET {
#ifndef _OUTLINE_ON
discard;
#endif
                return _OutlineColor;
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