Shader "Custom/BBParticle" {

        Properties
    {
        //_r("Red Factor", Float) = 0.1
        //_g("Green Factor", Float) = 0.1
        //_b("Blue Factor", Float) = 0.1
        _a("Alpha Factor", Float) = 0.1
        _lightRange("Light Range", Float) = 5.0
        _lightIntensity("Light Intensity", float) = 1.0
        _lightX("Light X", float) = 1.0
        _lightY("Light Y", float) = 1.0
        _lightZ("Light Z", float) = 1.0
        _lightR("Light R", float) = 1.0
        _lightG("Light G", float) = 1.0
        _lightB("Light B", float) = 1.0
        _focusDistance("Focus Distance", float) = 800.0
        _dof("dof", float) = 200.0
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader {
        Pass {
        Tags { "Queue" = "Transparent" "RenderType"="Transparent" "DisableBatching"="True"}
        LOD 100
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha


        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma vertex vert
        #pragma fragment frag


        #include "UnityCG.cginc"
        #include "SimplexNoise3D.cginc"

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 5.0

        struct Particle{
            float3 position;
            float3 velocity;
            float life;
        };
        
        struct PS_INPUT{
            float4 position : SV_POSITION;
            float4 color : COLOR;
            float2 uv : TEXCOORD0;
            uint instId : INSTID;
            uint vertId : VERTID;
            float life : LIFE;
        };
        float _r, _g, _b, _a, _lightX, _lightY, _lightZ, _lightR, _lightG, _lightB;
        float _lightRange, _lightIntensity;
        float _focusDistance, _dof;
        // particles' data
        StructuredBuffer<Particle> particleBuffer;

        uint Hash(uint s)
        {
            s ^= 2747636419u;
            s *= 2654435769u;
            s ^= s >> 16;
            s *= 2654435769u;
            s ^= s >> 16;
            s *= 2654435769u;
            return s;
        }

        float Random(uint seed)
        {
            return float(Hash(seed)) / 4294967295.0; // 2^32-1
        }


        PS_INPUT vert(uint vertex_id : SV_VertexID, uint instance_id : SV_InstanceID)
        {
            PS_INPUT o = (PS_INPUT)0;

            float life = particleBuffer[instance_id].life;

            // Position

            //o.position = UnityObjectToClipPos(float4(pos, 1.0));
            float3 vertPosMatrix[6];
            vertPosMatrix[0] = float3(-0.5,-0.5,0);
            vertPosMatrix[1] = float3(-0.5,0.5,0);
            vertPosMatrix[2] = float3(0.5,0.5,0);
            vertPosMatrix[3] = float3(0.5,0.5,0);
            vertPosMatrix[4] = float3(0.5,-0.5,0);
            vertPosMatrix[5] = float3(-0.5,-0.5,0);
            float len = 150.0;
            // vertex position in world space
            float3 vertexPosW = particleBuffer[instance_id].position + vertPosMatrix[vertex_id] * len;
            float4x4 mv = UNITY_MATRIX_MV;

            // billboard center in view space
            float4 bbCenterV = mul(mv, float4(particleBuffer[instance_id].position.x, particleBuffer[instance_id].position.y, particleBuffer[instance_id].position.z, 1.0));
            // vertex position in view space
            float4 vertPosV = bbCenterV + float4(vertPosMatrix[vertex_id] * len, 1);
            // final position in camera space
            o.position = mul(UNITY_MATRIX_P, vertPosV);
            o.uv = vertPosMatrix[vertex_id].xy;
            o.vertId = vertex_id;
            o.instId = instance_id;
            o.life = particleBuffer[instance_id].life;

            // Color
            // Distance to the light:
            float lightDist = distance(vertexPosW, float3(_lightX, _lightY, _lightZ));
            float r = clamp(_lightRange / lightDist  * _lightR * _lightIntensity, 0, 2);
            float g = clamp(_lightRange / lightDist * _lightG * _lightIntensity, 0, 2);
            float b = clamp(_lightRange / lightDist * _lightB * _lightIntensity, 0, 2);
            o.color = fixed4(clamp(r * r, 0, 1), 
                clamp(g * g, 0, 1), 
                clamp(b * b, 0, 1), 
                clamp(life / 50.0 * _a, 0, 1));

            return o;
        }

        float3 rgb2hsv(float3 c) {
          float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
          float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
          float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

          float d = q.x - min(q.w, q.y);
          float e = 1.0e-10;
          return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
        }

        float3 hsv2rgb(float3 c) {
          c = float3(c.x, clamp(c.yz, 0.0, 1.0));
          float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
          float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
          return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
        }

        float sdfSphere(float3 p, float radius)
        {
            //float s = 0.1 * frac(sin(_Time.y + p.x * 10));
            return length(p) - radius;// + s * s;
        }

        float opRepSdfSphere(float3 p, float3 repetitionPeriod, float radius)
        {
            p = (frac(p) - 0.15) * 5 - 1; //* 0.01 + (sin(_Time.y) * 0.1);
            //float3 q = fmod(p, repetitionPeriod) - 0.5 * repetitionPeriod;

            return sdfSphere(p, radius);
        }

        float trace(float3 origin, float3 ray)
        {
            float t = 0.0;
            float radius = 0.2;
            float rp = 3;
            float3 repetitionPeriod = float3(rp, rp, rp);
            for(int i = 0; i < 8; i++)
            {
                float3 p = origin + ray * t;
                float d = opRepSdfSphere(p, repetitionPeriod, radius);
                t += d * 1.505;
            }
            return t;
        }

        float4 frag(PS_INPUT i) : COLOR
        {
            /*
            float vertLuminosityMatrix[6];
            vertLuminosityMatrix[0] = 0.5;
            vertLuminosityMatrix[1] = 1.0;
            vertLuminosityMatrix[2] = 0.5;
            vertLuminosityMatrix[3] = 0.5;
            vertLuminosityMatrix[4] = 0.0;
            vertLuminosityMatrix[5] = 0.5;

            */
            float2 uv = i.uv;
            float r = 0.1;
            float d = length(i.uv);
            uv += 0.5;
            float3 ray = normalize(float3(uv, 1.0));
            float time = sin(0.02 * _Time.y * fmod(i.instId, 37)) * -1 * fmod(i.instId, -22) * 0.05 * cos(_Time.y) + 1.2;
            float timeConst = 0.001;
            // Dof
            //float cameraToVertex = distance(_WorldSpaceCameraPos, particleBuffer[i.instId].position); 
            //float vertexToFocus = max(abs(_focusDistance - cameraToVertex) - 0.5 * _dof, 0);
            //float offFocus = abs(cameraToVertex - _focusDistance);
            //float maxOffFocus = _dof;
            //float opacity = 0.5 - max(1 - offFocus/maxOffFocus, 0.4);//max(max(vertexToFocus / _focusDistance), 1.0) * 0.3, 0.3);
            float opacity = 0.1;
            float mult = 1 - opacity;
            float2x2 transform = float2x2(1* cos(timeConst * time), -1 * sin(timeConst * time), 1 * sin(timeConst * time), 1 * cos(timeConst * time));
            transform *= fmod((i.instId + 1), 4) * 0.5;
            ray.xz =  mul(ray.xz, transform);
            ray *= opacity;

            //float3 light = float3(0, 15, 30);
            //float range = 15;
            //float lightDistance = distance(light, i.vertex);
            //float lightPow = range / (lightDistance);


            float3 origin = float3(0, 0, -time * 0.2);//time * 0.2);//_Time.y * 0.1 * (i.instId + 1));
            float t = trace(origin, ray);
            float fogt = 1.0 / (1.0 + 0.1 * t * t);
            float3 res = float3(fogt, fogt, fogt);
            float s = smoothstep(r + 0.4, r, d);
            float rnd = Random(fmod(i.instId, 4));
            float hue = rnd + 0.1;
            float sat = 0.5;
            float val = 2.5;//vertLuminosityMatrix[i.vertId] * length(i.uv + 0.5);
            float3 c = hsv2rgb(float3(hue, sat, val));
            //c *= mult * mult;
            //float4 a = snoise(i.position.xyz * 0.1);
            //float gs = clamp((a.x * a.y * a.z) + 0.4, 0.0, 1.0);
            //a.w *= 0.2;
            //return float4(c.x, c.y, c.z, s);
            return float4(res * i.color, s * res.x);//s * res.x);
        }


        ENDCG
        }
    }
    FallBack Off
}