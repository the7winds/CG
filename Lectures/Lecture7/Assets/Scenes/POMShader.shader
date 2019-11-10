Shader "Unlit/POMShader"
{
    Properties
    {
        _AlbedoTex ("Albedo", 2D) = "white" {}
        _NormalTex("Normal", 2D) = "white" {}
        _HeightTex("Height", 2D) = "white" {}
        _Sun("Sun", Vector) = (0, 0, 0)
        _Depth("Depth", Float) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float3 pos : POS0;
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 clip : SV_POSITION;
            };

            sampler2D _AlbedoTex;
            sampler2D _NormalTex;
            sampler2D _HeightTex;
            float4 _AlbedoTex_ST;

            uniform float3 _Sun;
            uniform float _Depth;

            v2f vert (appdata v)
            {
                v2f o;
                o.clip = UnityObjectToClipPos(v.vertex);
                o.pos = mul(UNITY_MATRIX_M, v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _AlbedoTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed2 toUV(fixed2 x)
            {
                return (x + 1) / 2;
            }

            float getDepth(fixed2 x)
            {
                return _Depth * tex2D(_HeightTex, toUV(x)).x;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                const int iter = 100;
                const float3 dir = normalize(i.pos.xyz - _WorldSpaceCameraPos);
                const float3 step = dir / iter;

                float depthTotal = _Depth;
                float2 uv = i.pos.xy;
                float2 prevUv = uv;

                for (int j = 0; j < iter; j++) {
                    if (depthTotal < getDepth(uv)) {
                        if (j == 0) {
                            break;
                        }

                        const float d1 = getDepth(prevUv);
                        const float d2 = getDepth(uv);
                        const float b1 = depthTotal + abs(step.z);
                        const float b2 = depthTotal;

                        const float k = (b1 - d1) / ((d2 - d1) - (b2 - b1));

                        uv = prevUv + k * step.xy;
                        break;
                    }
                    prevUv = uv;
                    uv += step.xy;
                    depthTotal -= abs(step.z);
                }

                uv = toUV(uv);
                // sample the texture
                const fixed4 col = tex2D(_AlbedoTex, uv);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                fixed3 n = tex2D(_NormalTex, uv);
                n = 2 * n - 1;

                const fixed3 sun = normalize(_Sun.xyz);

                const float light = dot(n, sun);

                return col * light;
            }
            ENDCG
        }
    }
}
