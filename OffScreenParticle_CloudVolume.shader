/// <summary>
/// Off Screen Particle Rendering System
/// ©2015 Disruptor Beam
/// Written by Jason Booth (slipster216@gmail.com)
/// </summary>

Shader "OffScreenParticles/CloudVolume_Offscreen" 
{
   Properties 
   {
      _MainTex ("Particle Texture", 2D) = "white" {}
      _angle_bias("angle bias", Range(0.0, 0.99)) = 0.2
      _near_plane("near plane", Float) = 2
      _fade_in_distance("distance fade in", Float) = 30
      _fade_hold_distance("distace fade hold", Float) = 10000
      _fade_out_distance("distance fade out", Float) = 10000
      _color ("color", Color) = (1,1,1,1)
   }

   Category 
   {
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
            #include "UnityStandardBRDF.cginc"
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            sampler2D _CameraDepthTexture;
            float _near_plane;
            float _fade_in_distance;
            float _fade_hold_distance;
            float _fade_out_distance;
            half  _angle_bias;
            fixed4 _color;
            
            struct appdata_t 
            {
               float4 vertex     : POSITION;
               float2 texcoord   : TEXCOORD0;
               half3  normal     : NORMAL;
            };

            struct v2f 
            {
               float4 vertex        : SV_POSITION;
               float2 texcoord      : TEXCOORD0;
               float4 projPos       : TEXCOORD1;
               half   alpha         : TEXCOORD2;
            };
           
            v2f vert (appdata_t v)
            {
               v2f o;
               o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
               float3 wvp = mul(_Object2World, v.vertex);
               o.projPos = ComputeScreenPos (o.vertex);
               COMPUTE_EYEDEPTH(o.projPos.z);
               o.texcoord = v.texcoord;
               
               float3 normalDir = normalize(mul(_Object2World, float4(v.normal,0)).xyz);
               float3 camVec = _WorldSpaceCameraPos - wvp.xyz;
               o.alpha = saturate(abs(dot(normalDir, normalize(camVec))) - _angle_bias);
               o.alpha *= o.alpha;
               o.alpha *= o.alpha;

               // compute distance to camera; fade in from near plane distance -> fade in distance,
               // hold for a while, then fade out..
               float viewDist = length(camVec);
               half a1 = saturate((viewDist - _near_plane) / _fade_in_distance);
               half a2 = 1 - saturate((viewDist - _fade_in_distance - _fade_hold_distance) / _fade_out_distance); 
               o.alpha *= a1 * a2;
                
               return o;
            }

            
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.texcoord);
                // Do Z clip
				float zbuf = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
				float partZ = i.projPos.z;
				float zalpha = saturate((zbuf - partZ + 1e-2f)*10000);
				col.a = col.a * _color.a * i.alpha * zalpha; 
				// premultiply alpha
				col.rgb = _color.rgb * col.a;
           
                return col;
            }
            ENDCG 
         }
      }  
   }
   FallBack Off
}