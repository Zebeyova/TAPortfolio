Shader "Zebeyova/URP/BushLeaves" {
    Properties {
        [MainTexture]
        _AlbedoTex ("Albedo Tex", 2D) = "white" {}
        [MainColor]
        _BaseColor ("Base Color", Color) =  (1, 1, 1, 1)

        _NormalTex ("Normal Tex", 2D) = "bump" {}
        _NormalScale ("Normal Scale", Range(0,2)) = 1

        _CutOff ("Cut Off", Range(0,1)) = 0.5

        _RampTex ("Ramp Tex", 2D) = "white" {}
        _AmbientIntensity ("Ambient Intensity", float) = 1
        _LightIntensity ("Light Intensity", float) = 1

        [Space]
        [Header(HeightGradient)]
        [Toggle(_INVERT_GRADIENT)]
        _InvertGradient ("Invert Gradient", Float) = 0
        _GradientColor ("Gradient Color", Color) =  (0.3, 0.5, 0.2, 1)
        _GradientCenter ("Gradient Center (World Y)", Range(0,1)) = 0
        _GradientRange ("Gradient Range", Float) = 2
    }

    SubShader {
        Tags { "Queue" = "AlphaTest" "RenderType" = "TransparentCutout" "RenderPipeline" = "UniversalPipeline" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        TEXTURE2D(_AlbedoTex);        SAMPLER(sampler_AlbedoTex);
        TEXTURE2D(_NormalTex);        SAMPLER(sampler_NormalTex);
        TEXTURE2D(_RampTex);        SAMPLER(sampler_RampTex);

        CBUFFER_START(UnityPerMaterial)
        float4 _AlbedoTex_ST;
        float4 _BaseColor;
        float _NormalScale;

        float _CutOff;

        float _AmbientIntensity;
        float _LightIntensity;

        float4 _GradientColor;
        float _GradientCenter;
        float _GradientRange;
        CBUFFER_END
        ENDHLSL

        Pass {
            Name "Bush"
            Tags { "LightMode" = "UniversalForward" }
            Cull Off

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 3.0
            #pragma shader_feature_local _INVERT_GRADIENT
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

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

            Varyings Vert(Attributes input) {
                Varyings o;

                VertexPositionInputs posInput = GetVertexPositionInputs(input.positionOS.xyz);
                o.positionCS = posInput.positionCS;
                o.positionWS = posInput.positionWS;

                VertexNormalInputs norInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                o.normalWS = norInput.normalWS;
                o.tangentWS = norInput.tangentWS;
                o.bitangentWS = norInput.bitangentWS;

                o.uv = TRANSFORM_TEX(input.uv, _AlbedoTex);
                return o;
            }

            half4 Frag(Varyings input, FRONT_FACE_TYPE isFrontFace : FRONT_FACE_SEMANTIC) : SV_Target {
                half4 albedoColor = SAMPLE_TEXTURE2D(_AlbedoTex, sampler_AlbedoTex, input.uv);
                clip(albedoColor.a - _CutOff);
                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, input.uv), _NormalScale);
                half3 normalWS = normalize(input.tangentWS * normalTS.x + input.bitangentWS * normalTS.y + input.normalWS * normalTS.z);
                // 双面渲染时，背面三角形需要反转法线方向
                normalWS = IS_FRONT_VFACE(isFrontFace, normalWS, -normalWS);

                float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                Light mainLight = GetMainLight(shadowCoord);

                half NdotL = dot(normalWS, mainLight.direction);
                half halfLambert = NdotL * 0.5 + 0.5;
                half lightCoord = halfLambert * mainLight.shadowAttenuation;
                half3 rampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(lightCoord, 0.5)).rgb;

                half3 baseColor = albedoColor.rgb * _BaseColor.rgb;
                half3 ambient = SampleSH(normalWS) * _AmbientIntensity;

                // 高度渐变：根据世界空间 Y 坐标，在底部混合 _GradientColor
                half heighOS = TransformWorldToObject(input.positionWS).y;
                half heightFactor = saturate((heighOS - _GradientCenter) / max(_GradientRange, 0.01));
#ifdef _INVERT_GRADIENT
                heightFactor = 1.0 - heightFactor;
#endif
                half3 gradientTint = lerp(_GradientColor.rgb, half3(1, 1, 1), heightFactor);
                half3 finalColor = (mainLight.color * _LightIntensity * rampColor + ambient) * baseColor * gradientTint;

                return half4(finalColor, 1.0);
            }

            ENDHLSL
        }
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On
            ZTest LEqual
            ColorMask  0
            Cull Off

            HLSLPROGRAM
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #pragma target 2.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct ShadowAttributes {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct ShadowVaryings {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            float4 GetShadowPositionHClip(ShadowAttributes input) {
                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(input.normalOS);

#if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 lightDirectionWS = normalize(_LightPosition - positionWS);
#else
                float3 lightDirectionWS = _LightDirection;
#endif
                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

#if UNITY_REVERSED_Z
                positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#else
                positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
#endif
                return positionCS;
            }

            ShadowVaryings ShadowVert(ShadowAttributes input) {
                ShadowVaryings o;
                o.uv = TRANSFORM_TEX(input.uv, _AlbedoTex);
                o.positionCS = GetShadowPositionHClip(input);
                return o;
            }

            half4 ShadowFrag(ShadowVaryings input) : SV_TARGET {
                half alpha = SAMPLE_TEXTURE2D(_AlbedoTex, sampler_AlbedoTex, input.uv).a;
                clip(alpha - _CutOff);
                return 0;
            }
            ENDHLSL
        }
    }
}