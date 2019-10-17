Shader "Unlit/HW"
{
    Properties
    {
        _MainTex ("Texture", Cube) = "white" {}
		_SamplesN("Samples", Int) = 3
		_Source("Source", Vector) = (0, 0, 1)
		_Mirror("Mirror", Int) = 0
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
				float3 normal : NORMAL;
			};

            struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 normal : NORMAL;
				float3 look : LOOK;
			};

			uniform int _SamplesN;
			samplerCUBE _MainTex;
			uniform float3 _Source;
			uniform int _Mirror;

			uint Hash(uint s)
			{
				uint ss = s;
				s ^= 2747636419u;
				s *= 2654435769u;
				s ^= s >> 16;
				s *= 2654435769u;
				s ^= ss << 16;
				s *= 2654435769u;
				return s;
			}

			float Random(uint seed)
			{
				return float(Hash(seed)) / 4294967295.0; // 2^32-1
			}

			float uniformR(uint seed, float l, float r) {
				return Random(seed) * (r - l) + l;
			}

			float3 randomSphere(uint i)
			{
				i *= 3;
				float r1 = uniformR(i + 0, 0, 3.14);
				float r2 = uniformR(i + 1, 0, 6.28);

				float x = sin(r1) * cos(r2);
				float y = sin(r1) * sin(r2);
				float z = cos(r1);

				float3 v = float3(x, y, z);

				return v;
			}

			float3 randomHalfSphere(uint i, float3 n, float3 dir)
			{
				float3 v = randomSphere(i);
				v = normalize(v);

				if (dot(v, n) < 0) {
					return -v;
				}

				return v;
			}

			float3 reflect(float3 v, float3 n)
			{
				return v - 2 * n * dot(v, n);
			}

			float mirror(float3 dir, float3 w, float3 n)
			{
				dir = -reflect(dir, n);
				dir = normalize(dir);
				w = normalize(w);

				float dist = dot(dir, w);

				if (dist > 0.7) {
					return 5 / float(_SamplesN);
				}

				return 0;
			}


			float4 diffuse(float3 l, float3 w, float3 n)
			{
				l = reflect(l, n);
				l = normalize(l);
				w = normalize(w);

				// float dist = dot(l, -w);
				return 1 / float(_SamplesN);
			}

			float4 incommingLight(float3 l)
			{
				l = normalize(l);
				l = 2 * l + 1;
				return texCUBE(_MainTex, l);
			}

			float F(float3 dir, float3 w, float3 n)
			{
				if (_Mirror == 1) {
					return mirror(dir, w, n);
				}
				
				return diffuse(dir, w, n);				
			}

			float4 light(float3 dir, float3 n)
			{
				float4 r = 0;
				
				for (int i = 0; i < _SamplesN; i++) {
					float3 wr = randomHalfSphere(i, n, -reflect(dir, n));
					r += incommingLight(wr) * F(dir, -wr, n) * dot(wr, n);
				}

				// r /= (float)_SamplesN;
				// r *= dot(_Source, n);

				// debug
				// r = incommingLight(reflect(dir, n));
				// r = incommingLight(-n);

				return r;
			}

            v2f vert (appdata v)
            {
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.look = v.vertex - _WorldSpaceCameraPos;
				o.normal = v.normal;
				return o;
            }

			fixed4 frag(v2f i) : SV_Target
			{
				// return texCUBE(_MainTex, reflect(i.look, i.normal));
				return light(i.look, i.normal);
            }
            ENDCG
        }
    }
}
