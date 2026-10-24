Shader "Zebeyova/URP/StylizedLight" {
    Properties {
        [MainTexture]
        _BaseMap ("Base Map", 2D) = "white" {}
        [MainColor]
        _BaseColor ("Base Color", Color) =  (1, 1, 1, 1)
        [NormalMap]
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _RampTex ("Ramp Tex", 2D) = "white" {}

        _AmbientIntensity ("Ambient Intensity", Range(0, 5)) = 0.25

        _ShadowThreshold ("Shadow Threshold", Range(0,1)) = 0.5
        _ShadowSoftness ("Shadow Softness", Range(0,0.2)) = 0.1
        _ShadowTint ("Shadow Tint", Color) =  (0.75, 0.8, 0.85, 1)

        _RimColor ("Rim Color", Color) =  (0.5, 0.7, 1, 1)
        _RimPower ("Rim Power", Range(0.5,8)) = 3
        _RimStrength ("Rim Strength", Range(0,2)) = 0.25

        _SpecularColor ("Specular Color", Color) =  (1, 1, 1, 1)
        _SpecularPower ("Specular Power", Range(1,128)) = 32
        _SpecularStrength ("Specular Strength", Range(0,1)) = 1
    }

    SubShader {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM

            #pragma vertex Vert
            #pragma fragment Frag
            #pragma target 2.0

            //主光
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            //附加光
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            //雾效
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            //光照
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            //环境光
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/AmbientOcclusion.hlsl"

            struct Attributes {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD4;
                float3 bitangentWS : TEXCOORD5;
                float4 shadowCoord : TEXCOORD3;
                half fogFactor : TEXCOORD6;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseMap_ST;
            float4 _BaseColor;
            float _AmbientIntensity;

            float _ShadowThreshold;
            float _ShadowSoftness;
            float4 _ShadowTint;

            float4 _RimColor;
            float _RimPower;
            float _RimStrength;

            float4 _SpecularColor;
            float _SpecularPower;
            float _SpecularStrength;
            CBUFFER_END

            half3 AdditionalLight(half3 positionWS, half3 normalWS) {
                half3 additionalLightCol = 0;
                #if defined(_ADDITIONAL_LIGHTS)
                uint addLightCount = GetAdditionalLightsCount();

                LIGHT_LOOP_BEGIN(addLightCount)

                Light additionalLight = GetAdditionalLight(lightIndex, positionWS, half4(1, 1, 1, 1));
                half additionalNdotL = saturate(dot(normalWS, additionalLight.direction));
                half3 additionalRampCol = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(additionalNdotL, 0.5)).rgb;
                half additionalShadowBand = smoothstep((_ShadowThreshold - _ShadowSoftness), (_ShadowThreshold + _ShadowSoftness), additionalNdotL);
                additionalRampCol = lerp(additionalRampCol * _ShadowTint.rgb, additionalRampCol, additionalShadowBand);

                additionalLightCol += additionalRampCol * additionalLight.color * additionalLight.distanceAttenuation * additionalLight.shadowAttenuation;

                LIGHT_LOOP_END
                #endif

                return additionalLightCol;
            }

            Varyings Vert(Attributes input) {
                Varyings output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;

                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = normalInput.normalWS;
                output.tangentWS = normalInput.tangentWS;
                output.bitangentWS = normalInput.bitangentWS;

                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.shadowCoord = GetShadowCoord(vertexInput);
                output.fogFactor = ComputeFogFactor(output.positionCS.z);

                return output;
            }

            half4 Frag(Varyings input) : SV_Target {
                //基本贴图
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv));

                //世界空间法线
                half3 normalWS = normalize(input.tangentWS * normalTS.x + input.bitangentWS * normalTS.y + input.normalWS * normalTS.z);
                //世界空间视线方向
                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                //环境光
                half3 ambient = SampleSH(normalWS);
                //主光源-平行光
                Light mainLight = GetMainLight(input.shadowCoord);

                //受光范围（是否正对光源）
                half NdotL = saturate(dot(normalWS, mainLight.direction));
                //视线范围（是否正对视线方向）
                half NdotV = saturate(dot(normalWS, viewDirWS));

                //漫反射颜色
                half4 albedo = baseColor * _BaseColor;
                //直接光漫反射
                half3 directLight = mainLight.color * mainLight.distanceAttenuation * mainLight.shadowAttenuation;
                //间接光漫反射
                half3 ambientLight = ambient * _AmbientIntensity;
                //附加光源
                half3 additionalLightCol = AdditionalLight(input.positionWS, normalWS);

                //Blinn-phong
                half3 halfDir = normalize(mainLight.direction + viewDirWS);
                half NdotH = saturate(dot(normalWS, halfDir));

                half specular = pow(NdotH, _SpecularPower) * _SpecularStrength;
                half3 specularColor = specular * _SpecularColor.rgb * directLight;

                // 风格化色阶
                half3 rampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(NdotL, 0.5)).rgb;
                half shadowBand = smoothstep((_ShadowThreshold - _ShadowSoftness), (_ShadowThreshold + _ShadowSoftness), NdotL);
                // 阴影区颜色
                half3 shadowRampCol = rampColor * _ShadowTint.rgb;
                rampColor = lerp(shadowRampCol, rampColor, shadowBand);

                half3 litColor = rampColor * mainLight.color * mainLight.distanceAttenuation + ambientLight;
                half3 shadowColor = ambientLight * _ShadowTint.rgb;
                half3 mainLightColor = lerp(shadowColor, litColor, mainLight.shadowAttenuation);

                //边缘光
                half rim = pow(1.0 - NdotV, _RimPower);
                half3 rimColor = (rim * _RimColor.rgb * _RimStrength);

                // half3 finalColor = albedo.rgb * (rampColor * directLight + ambientLight + additionalLightCol) + rimColor + specularColor;
                half3 finalColor = albedo.rgb * (mainLightColor + additionalLightCol) + rimColor + specularColor;
                finalColor = MixFog(finalColor, input.fogFactor);
                return half4(finalColor, albedo.a);
            }

            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
