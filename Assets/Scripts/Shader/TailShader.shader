// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Hidden/TailShader"
{
	Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _PrevFrame("Previous Frame", 2D) = "black" {}
        _MaxTransparency("Max Transparency", Float) = 1.0
    }
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }
            
            sampler2D _MainTex;
            sampler2D _PrevFrame;
            float _MaxTransparency;

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                fixed4 prev = tex2D(_PrevFrame, i.uv);
                //col = lerp(prev, col, _MaxTransparency);
                col.rgb += _MaxTransparency * prev.rgb;
                col.r = min(col.r, 1.0f);
                col.g = min(col.g, 1.0f);
                col.b = min(col.b, 1.0f);
                return col;
            }
            ENDCG
        }
	}
}
