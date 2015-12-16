/// <summary>
/// Off Screen Particle Rendering System
/// ©2015 Disruptor Beam
/// Written by Jason Booth (slipster216@gmail.com)
/// </summary>

Shader "Hidden/OffScreenParticles/DepthDownsampleFast"
{

	CGINCLUDE
		
	#include "UnityCG.cginc"
	
	struct v2f {
		float4 pos : SV_POSITION;
		float2 uv : TEXCOORD0;
	};
		
	sampler2D _CameraDepthTexture;
	float2 _PixelSize;
	float4 _MainTex_TexelSize;
   fixed _MSAA;
		
	v2f vert( appdata_img v ) 
	{
		v2f o;
		o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
		o.uv =  v.texcoord.xy;
		
      
		#if UNITY_UV_STARTS_AT_TOP
      // the standard Unity if _MainTex_TexelSize doesn't work here, so we do this ourselves
      if (_MSAA > 0)
			o.uv.y = 1.0f - v.texcoord.y;
		#endif
		
		return o;
	}
	
	half4 frag(v2f i) : SV_Target 
	{
		float d = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv));
		if(d>0.99999)
			return half4(1,1,1,1);
		else
			return EncodeFloatRGBA(d); 
	}

	ENDCG
	
Subshader {
	
 Pass {
	  ZTest Always Cull Off ZWrite Off

      CGPROGRAM
      #pragma vertex vert
      #pragma fragment frag
      ENDCG
  }
}

Fallback off
	
} // shader