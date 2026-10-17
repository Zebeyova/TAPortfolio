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
        _ShadowSoftness ("Shadow Softness", Range(0,0.5)) = 0.1
        _ShadowTint ("Shadow Tint", Color) =  (0.55, 0.6, 0.65, 1)
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

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

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

            float _ShadowThreshlod;
            float _ShadowSoftness;
            float4 _ShadowTint;
            CBUFFER_END

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

                return output;
            }

            half4 Frag(Varyings input) : SV_Target {
                //基本贴图
                half4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv));

                //世界空间法线
                half3 normalWS = normalize(input.tangentWS * normalTS.x + input.bitangentWS * normalTS.y + input.normalWS * normalTS.z);
                //环境光
                half3 ambient = SampleSH(normalWS);
                //主光源-平行光
                Light mainLight = GetMainLight(input.shadowCoord);

                //受光范围（是否正对光源）
                half NdotL = saturate(dot(normalWS, mainLight.direction));
                //漫反射颜色
                half4 albedo = baseColor * _BaseColor;
                //直接光漫反射
                half3 directLight = mainLight.color * mainLight.distanceAttenuation * mainLight.shadowAttenuation;
                //间接光漫反射
                half3 ambientLight = ambient * _AmbientIntensity;

                // 风格化色阶
                // half lightBand = smoothstep((_ShadowThreshlod - _ShadowSoftness), (_ShadowThreshlod + _ShadowSoftness), NdotL);
                // 阴影区颜色
                // half3 shadowColor = albedo.rgb * _ShadowTint.rgb;
                // 受光区颜色
                // half3 litColor = albedo.rgb * directLight;
                // half3 finalCol = albedo.rgb * ambientLight + lerp(shadowColor, litColor, lightBand);

                //使用Ramp替代色阶
                half3 rampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(NdotL, 0.5)).rgb;

                half3 finalCol = albedo.rgb * (rampColor * directLight + ambientLight);
                return half4(finalCol, albedo.a);
            }

            ENDHLSL
        }
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}