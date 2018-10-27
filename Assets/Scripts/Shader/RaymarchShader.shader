Shader "Custom/RaymarchShader"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		Tags { "Queue" = "Transparent" "RenderType"="Transparent" }
		LOD 100
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
// Upgrade NOTE: excluded shader from DX11 because it uses wrong array syntax (type[size] name)
#pragma exclude_renderers d3d11
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
            #pragma target 5.0


			struct v2f
			{
				float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                uint instId : SV_InstanceID;
			};
            
            
            // particles' data
            StructuredBuffer<float3> particleBuffer;

			v2f vert (uint vertex_id : SV_VertexID, uint instance_id : SV_InstanceID)
			{
                v2f o;
                float3 vertPosMatrix[6];
                vertPosMatrix[0] = float3(-0.5,-0.5,0);
                vertPosMatrix[1] = float3(-0.5,0.5,0);
                vertPosMatrix[2] = float3(0.5,0.5,0);
                vertPosMatrix[3] = float3(0.5,0.5,0);
                vertPosMatrix[4] = float3(0.5,-0.5,0);
                vertPosMatrix[5] = float3(-0.5,-0.5,0);
                float len = 2;
                 // [-w .. w]
                float3 pos = particleBuffer[instance_id] + vertPosMatrix[vertex_id] * len;
                o.vertex = UnityObjectToClipPos(float4(pos, 1.0));
                o.uv = vertPosMatrix[vertex_id].xy;
                o.instId = instance_id;
                return o;
			}
            // p stands for position
            float sdfSphere(float3 p, float radius)
            {
                //float s = 0.1 * frac(sin(_Time.y + p.x * 10));
                return length(p) - radius;// + s * s;
            }

            float opRepSdfSphere(float3 p, float3 repetitionPeriod, float radius)
            {
                p = (frac(p) - 0.5) * 4 - 2; //* 0.01 + (sin(_Time.y) * 0.1);
                //float3 q = fmod(p, repetitionPeriod) - 0.5 * repetitionPeriod;

                return sdfSphere(p, radius);
            }

            float trace(float3 origin, float3 ray)
            {
                float t = 0.0;
                float radius = 1.0;
                float rp = 3;
                float3 repetitionPeriod = float3(rp, rp, rp);
                for(int i = 0; i < 4; i++)
                {
                    float3 p = origin + ray * t;
                    float d = opRepSdfSphere(p, repetitionPeriod, radius);
                    t += d * 0.305;
                }
                return t;
            }
			
			fixed4 frag (v2f i) : SV_Target
			{
                float r = 0.2;
                float4 c;
                float2 uv = i.uv;
                float d = length(uv);
                uv += 0.5;
                float3 ray = normalize(float3(uv, 1.0));
                float time = sin(0.1 * _Time.y * fmod(i.instId, 37)) * -1 * fmod(i.instId, -22) * 0.2 * cos(_Time.y);
                float timeConst = 0.05;
                float opacity = 0.7;
                float2x2 transform = float2x2(1* cos(timeConst * time), -1 * sin(timeConst * time), 1 * sin(timeConst * time), 1 * cos(timeConst * time));
                //transform *= fmod((i.instId + 1), 4) * 0.5;
                ray.xz =  mul(ray.xz, transform);
                ray *= opacity;

                float3 light = float3(0, 15, 30);
                float range = 15;
                float lightDistance = distance(light, i.vertex);
                float lightPow = range / (lightDistance);


                float3 origin = float3(0, 0, time * 0.2);//_Time.y * 0.1 * (i.instId + 1));
                float t = trace(origin, ray);
                float fogt = 1.0 / (1.0 + 0.01 * t * t);
                float3 res = float3(fogt, fogt, fogt);
                float s = smoothstep(r + 0.3, r, d);

                return float4(res, clamp(s * res.x * lightPow, 0, 1));
                //return float4(1.0, 1.0, 1.0, s);
				
			}
			ENDCG
		}
	}
}
