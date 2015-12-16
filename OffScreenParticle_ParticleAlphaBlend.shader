/// <summary>
/// Off Screen Particle Rendering System
/// ©2015 Disruptor Beam
/// Written by Jason Booth (slipster216@gmail.com)
/// </summary>

// example of a alpha-blend shader. Note, offscreen rendering requires premultiplied alpha and manual z-testing
// both of which can be done in the pixel shader.

Shader "OffScreenParticles/AlphaBlend" 
{
	Properties {
	   _TintColor ("Tint Color", Color) = (0.5,0.5,0.5,0.5)
	   _MainTex ("Particle Texture", 2D) = "white" {}
      _InvFade ("Soft Particles Factor", Range(0.01,3.0)) = 1.0
	}

Category {
   Tags { "Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" }
   Blend One OneMinusSrcAlpha // note, we use premultiplied alpha, so 1 (1-src)
   Cull Off Lighting Off ZWrite Off
   SubShader 
   {
      Pass 
      {
      
         CGPROGRAM
         #pragma vertex vert
         #pragma fragment frag
         
         #include "UnityCG.cginc"

         sampler2D _MainTex;
         sampler2D _CameraDepthTexture;

         fixed4 _TintColor;
         float _InvFade;
         
         struct appdata_t {
            float4 vertex : POSITION;
            fixed4 color : COLOR;
            float2 texcoord : TEXCOORD0;
         };

         struct v2f {
            float4 vertex : SV_POSITION;
            fixed4 color : COLOR;
            float2 texcoord : TEXCOORD0;
            float4 projPos : TEXCOORD1;
         };
         
         float4 _MainTex_ST;

         v2f vert (appdata_t v)
         {
            v2f o;
            o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
            o.projPos = ComputeScreenPos (o.vertex);
            o.color = v.color;
            o.texcoord = v.texcoord;
            return o;
         }


         fixed4 frag (v2f i) : SV_Target
         {
            fixed4 col = i.color * _TintColor * tex2D(_MainTex, i.texcoord);
            // Do Z clip
            
            float zbuf = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
			   float partZ = i.projPos.z;
			   float zalpha = saturate((zbuf - partZ + 1e-2f)*10000);
            // soft particle
            float fade = saturate (_InvFade * (zbuf-partZ));
            col.a *= zalpha * fade;
            // premultiply alpha
            col.rgb *= col.a;
        
            return col;
         }
         ENDCG 
      }
   }  
}
}