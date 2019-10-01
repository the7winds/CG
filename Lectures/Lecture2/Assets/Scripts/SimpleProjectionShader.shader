Shader "Custom/BrokenShader"
{
    Properties
    {
		_XTex("Albedo (RGB)", 2D) = "white" {}
		_YTex("Albedo (RGB)", 2D) = "white" {}
		_ZTex("Albedo (RGB)", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Pass
        {
            // indicate that our pass is the "base" pass in forward
            // rendering pipeline. It gets ambient and main directional
            // light data set up; light direction in _WorldSpaceLightPos0
            // and color in _LightColor0
            Tags {"LightMode"="ForwardBase"}
        
            CGPROGRAM
            #pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc" // for UnityObjectToWorldNormal
            #include "UnityLightingCommon.cginc" // for _LightColor0

            struct v2f
            {
                float4 pos : SV_POSITION;
				float3 x : ORIG;
                fixed3 normal : NORMAL;
            };

            v2f vert (appdata_base v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
				o.x = v.vertex;
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }
            
            sampler2D _XTex;
			sampler2D _YTex;
			sampler2D _ZTex;

			fixed4 frag(v2f i) : SV_Target
			{
				half nl = max(0, dot(i.normal, _WorldSpaceLightPos0.xyz));
				half3 light = nl * _LightColor0;
				light += ShadeSH9(half4(i.normal, 1));

				float3 x = i.x;
				float3 n = i.normal;

				float4 cx = tex2D(_XTex, x.zy);
				float4 cy = tex2D(_YTex, x.xz);
				float4 cz = tex2D(_ZTex, x.xy);

				n = n * n;
                float3 col = n.x * cx + n.y * cy + n.z * cz;

				col *= light;

				return float4(col, 1);
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
