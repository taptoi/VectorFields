Shader "Custom/Particle" {

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
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader {
        Pass {
        Tags{ "RenderType" = "Opaque" }
        LOD 200
        Blend SrcAlpha one


        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma vertex vert
        #pragma fragment frag


        #include "UnityCG.cginc"

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
            float life : LIFE;
        };
        float _r, _g, _b, _a, _lightX, _lightY, _lightZ, _lightR, _lightG, _lightB;
        float _lightRange, _lightIntensity;
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

            float3 pos = particleBuffer[instance_id].position;
            float life = particleBuffer[instance_id].life;


            // Position

            o.position = UnityObjectToClipPos(float4(pos, 1.0));
            o.position += vertex_id * 0.1;
            float dist = length(ObjSpaceViewDir(o.position));
            //float rnd = Random(vertex_id) * 0.1 * dist;
            //o.position.x -= 0.1 * dist % vertex_id * rnd;
            //o.position.y -= 0.1 * dist % vertex_id * 0.2 * Random(rnd);
            //o.position.z -= 0.1 * dist % vertex_id * 0.04 * rnd;

            // Color
            // Distance to the light:
            float lightDist = distance(pos, float3(_lightX, _lightY, _lightZ));
            float r = clamp(_lightRange / lightDist  * _lightR * _lightIntensity, 0, 2);
            float g = clamp(_lightRange / lightDist * _lightG * _lightIntensity, 0, 2);
            float b = clamp(_lightRange / lightDist * _lightB * _lightIntensity, 0, 2);
            o.color = fixed4(clamp(r * r, 0, 1), 
                clamp(g * g, 0, 1), 
                clamp(b * b, 0, 1), 
                clamp(life / 50.0 * _a, 0, 1));

            return o;
        }

        float4 frag(PS_INPUT i) : COLOR
        {
            return i.color;
        }


        ENDCG
        }
    }
    FallBack Off
}