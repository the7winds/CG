Shader "Unlit/NormalMapShader"
{
    Properties
    {
        _AlbedoTex("Albedo", 2D) = "white" {}
        _NormalTex("Normal", 2D) = "white" {}
        _Sun("Sun", Vector) = (0, 0, 0)
    }
        SubShader
        {
            Tags { "RenderType" = "Opaque" }
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
                    float2 uv : TEXCOORD0;
                    UNITY_FOG_COORDS(1)
                    float4 clip : SV_POSITION;
                };

                sampler2D _AlbedoTex;
                sampler2D _NormalTex;
                sampler2D _HeightTex;
                float4 _AlbedoTex_ST;

                uniform float3 _Sun;

                v2f vert(appdata v)
                {
                    v2f o;
                    o.clip = UnityObjectToClipPos(v.vertex);
                    o.uv = TRANSFORM_TEX(v.uv, _AlbedoTex);
                    UNITY_TRANSFER_FOG(o,o.vertex);
                    return o;
                }

                fixed4 frag(v2f i) : SV_Target
                {
                    // sample the texture
                    const fixed4 col = tex2D(_AlbedoTex, i.uv);
                    // apply fog
                    UNITY_APPLY_FOG(i.fogCoord, col);
                    fixed3 n = tex2D(_NormalTex, i.uv);
                    n = 2 * n - 1;

                    fixed3 sun = normalize(_Sun.xyz);

                    const float light = dot(n, sun);

                    return col * light;
                }
                ENDCG
            }
        }
}
