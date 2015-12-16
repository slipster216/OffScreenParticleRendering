/// <summary>
/// Off Screen Particle Rendering System
/// ©2015 Disruptor Beam
/// Written by Jason Booth (slipster216@gmail.com)
///
///   Uses nearest depth upsampling to resolve a low res buffer to a high res buffer with minimal artifacts
///
/// </summary>

Shader "Hidden/OffScreenParticles/Upsample"
{
	SubShader 
	{
		Pass 
		{
			ZTest Always Cull Off ZWrite Off Fog { Mode Off }
			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
         #pragma shader_feature HQUPSAMPLE
			#include "UnityCG.cginc"
			
			sampler2D _ParticleRT;
			sampler2D _CameraDepthLowRes;
			sampler2D _CameraDepthTexture;
			float2 _LowResPixelSize;
			float2 _LowResTextureSize;
			float _DepthMult;
			float _Threshold;
			sampler2D _MainTex;
			float4 _MainTex_TexelSize;

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 pos : SV_POSITION;
				float2 uv00 : TEXCOORD1;
				float2 uv10 : TEXCOORD2;
				float2 uv01 : TEXCOORD3;
				float2 uv11 : TEXCOORD4;
			};
			
			v2f vert (float4 pos : POSITION, float2 uv : TEXCOORD0)
			{
				v2f o;
				o.pos = mul(UNITY_MATRIX_MVP, pos);
				o.uv = uv;
				   
				// shift pixel by a half pixel, then create other uvs..
				o.uv00 = uv - 0.5 * _LowResPixelSize;
            o.uv10 = o.uv00 + float2(_LowResPixelSize.x, 0.0);
            o.uv01 = o.uv00 + float2(0.0, _LowResPixelSize.y);
            o.uv11 = o.uv00 + _LowResPixelSize;

			   return o;
			}
			
			// There are a number of techniques in the wild for dealing with the upsampling. I tried several,
			// and settled on this branchless variant I rolled myself. It's faster than any of the other
			// variants I looked into, and the artifacting on 1/4 or is barely noticable. It breaks down
			// a bit on 1/8; you could likely fix this by upsampling in stages, but for our game it wasn't
			// noticable enough to matter. 
			fixed4 ClosestDepthFast(v2f i)
			{
				// sample low res depth at pixel offsets
				float z00 = DecodeFloatRGBA(tex2D(_CameraDepthLowRes, i.uv00));
				float z10 = DecodeFloatRGBA(tex2D(_CameraDepthLowRes, i.uv10));
				float z01 = DecodeFloatRGBA(tex2D(_CameraDepthLowRes, i.uv01));
				float z11 = DecodeFloatRGBA(tex2D(_CameraDepthLowRes, i.uv11));

				float zfull = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv));

				// compute distances between low and high res
				float dist00 = abs(z00-zfull);
				float dist10 = abs(z10-zfull);
				float dist01 = abs(z01-zfull);
				float dist11 = abs(z11-zfull);

				// pack uv and distance into float3 to prepare for fast selection
				// note, this could be sped up by packing into a float4 for each
				// component and doing the select that way..
				float3 uvd00 = float3(i.uv00, dist00);
				float3 uvd10 = float3(i.uv10, dist10);
				float3 uvd01 = float3(i.uv01, dist01);
				float3 uvd11 = float3(i.uv11, dist11);

				// using saturate and a muladd *should* be faster than step, since no
				// branch is required.
				float3 finalUV = lerp(uvd10, uvd00, saturate(99999*(uvd10.z-uvd00.z)));
				finalUV = lerp(uvd01, finalUV, saturate(99999*(uvd01.z -finalUV.z)));
				finalUV = lerp(uvd11, finalUV, saturate(99999*(uvd11.z-finalUV.z)));
				            
            float maxDist = max(max(max(dist00, dist10), dist01), dist11) - _Threshold;

            // finally, lerp between the original UV and the edge uv based on the max distance
            fixed r = saturate(maxDist*99999);
            float2 uv = lerp(i.uv, finalUV.xy, r);
            return tex2D(_ParticleRT, uv);
			}
         
			fixed4 frag (v2f i) : SV_Target
			{
				return ClosestDepthFast(i);
			}
			ENDCG
		}
	}
	Fallback Off
}