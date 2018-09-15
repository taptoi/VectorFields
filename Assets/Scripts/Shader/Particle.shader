Shader "Custom/Particle" {

        Properties
    {
        _r("Red Factor", Float) = 0.1
        _g("Green Factor", Float) = 0.1
        _b("Blue Factor", Float) = 0.1
        _a("Alpha Factor", Float) = 0.1
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
        float _r, _g, _b, _a;

        // particles' data
        StructuredBuffer<Particle> particleBuffer;


        PS_INPUT vert(uint vertex_id : SV_VertexID, uint instance_id : SV_InstanceID)
        {
            PS_INPUT o = (PS_INPUT)0;

            // Color
            float3 pos = particleBuffer[instance_id].position 
                        + min(vertex_id, 1) * 0.1 * particleBuffer[instance_id].velocity;
            float life = particleBuffer[instance_id].life;
            o.color = fixed4(clamp(life / 50 + _r, 0, 1), 
                            clamp(life / 50 + _g, 0, 1), 
                            clamp(life / 50 + _b, 0, 1), 
                            clamp(life / 50.0 * _a, 0, 1));

            // Position
            o.position = UnityObjectToClipPos(float4(pos, 1.0f));

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