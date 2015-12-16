/// <summary>
/// Off Screen Particle Rendering System
/// ©2015 Disruptor Beam
/// Written by Jason Booth (slipster216@gmail.com)
/// </summary>


using UnityEngine;
using System.Collections;
using System;

[RequireComponent(typeof(Camera))]
public class OffScreenParticleCamera : MonoBehaviour
{
   [Tooltip("Layer to render in low resolution")]
   public LayerMask downsampleLayers;
   public enum Factor
   {
      Full = 0,
      Half = 2,
      Quarter = 4,
      Eighth = 8
   }
   [Tooltip("How much should we scale down the rendering. Lower scales have greater chances of artifacting, but better performance")]
	public Factor factor = Factor.Half;
   [Tooltip("Depth threshold; essentially an edge width for when to use standard bilinear instead of uv offsets")]
   [Range(0.0001f, 0.01f)]
   public float depthThreshold = 0.005f;
   [Tooltip("Clear color for particle camera")]
	public Color clearColor = new Color(0, 0, 0, 0);
   [Tooltip("Shader for downsampling")]
	public Shader downsampleDepthFastShader;
   [Tooltip("Shader for upsampling")]
	public Shader compositeShader;
	private Material compositeMaterial;
	private Material downsampleFastMaterial;
	private Camera shaderCamera;
	private Camera mCamera;

   [Serializable]
   public class DebugOptions
   {
      [Tooltip("Draws buffers in top-left side of screen for debugging")]
      public bool debugDrawBuffers;
   }
   
   public DebugOptions debugOptions = new DebugOptions();

   void Awake()
   {
      mCamera = GetComponent<Camera>();
      mCamera.depthTextureMode |= DepthTextureMode.Depth;
   }
   
   RenderTexture DownsampleDepth(int ssX, int ssY, Texture src, Material mat, int downsampleFactor)
   {
      Vector2 offset = new Vector2(1.0f / ssX, 1.0f / ssX);
      ssX /= downsampleFactor;
      ssY /= downsampleFactor;
      RenderTexture lowDepth = RenderTexture.GetTemporary(ssX, ssY, 0);
      mat.SetVector("_PixelSize", offset);
      mat.SetFloat("_MSAA", QualitySettings.antiAliasing > 0 ? 1.0f : 0.0f);
      Graphics.Blit(src, lowDepth, mat);
      
      return lowDepth;
   }
   
   void OnDisable()
   {
      if (compositeMaterial != null)
      {
         DestroyImmediate(compositeMaterial);
         DestroyImmediate(downsampleFastMaterial);
      }
   }

   void EnforceCamera()
   {
      shaderCamera.CopyFrom(mCamera);
      shaderCamera.renderingPath = RenderingPath.Forward; // force forward
      shaderCamera.cullingMask = downsampleLayers;
      shaderCamera.clearFlags = CameraClearFlags.Nothing;
      shaderCamera.depthTextureMode = DepthTextureMode.None;
      shaderCamera.useOcclusionCulling = false;
      clearColor.a = 0;
      shaderCamera.backgroundColor = clearColor;
      shaderCamera.clearFlags = CameraClearFlags.Color;
   }

   void OnRenderImage(RenderTexture src, RenderTexture dest)
   {
      // make sure everything is assigned correctly
      if (!enabled || compositeShader == null || downsampleDepthFastShader == null)
      {
         if (compositeShader == null)
         {
            Debug.Log("OffScreenParticle: composite shader not assigned");
         }
         if (downsampleDepthFastShader == null)
         {
            Debug.Log("OffScreenParticle: downsample shader not assigned");
         }
         Graphics.Blit(src, dest);
         return;
      }
      
      Profiler.BeginSample("Off-Screen Particles");
      // setup materials
      if (compositeMaterial == null)
      {
         compositeMaterial = new Material(compositeShader);
      }
      if (downsampleFastMaterial == null)
      {
         downsampleFastMaterial = new Material(downsampleDepthFastShader);
      }

      // setup cameras
      if (shaderCamera == null)
      {
         shaderCamera = new GameObject("ParticleCam", typeof(Camera)).GetComponent<Camera>();
         shaderCamera.enabled = false;
         shaderCamera.transform.parent = this.transform;
         shaderCamera.targetTexture = dest;
      }

      // just render into the frame buffer if full..
      if (factor == Factor.Full)
      {
         Graphics.Blit(src, dest);

         shaderCamera.Render();
         Profiler.EndSample();
         return;
      }



      Profiler.BeginSample("Downsample Depth Fast");
      RenderTexture lowDepth = DownsampleDepth(Screen.width, Screen.height, src, downsampleFastMaterial, (int)factor);
      Profiler.EndSample();

      Shader.SetGlobalTexture("_CameraDepthLowRes", lowDepth);

      // render particles into buffer
      Profiler.BeginSample("Render Particles");
      RenderTexture particlesRT = RenderTexture.GetTemporary(Screen.width / (int)factor, Screen.height / (int)factor, 0);
      EnforceCamera();
      shaderCamera.targetTexture = particlesRT;
      shaderCamera.Render();

      Profiler.EndSample();

      // composite to screen
      Vector2 pixelSize = new Vector2(1.0f / lowDepth.width, 1.0f / lowDepth.height);
      compositeMaterial.SetVector("_LowResPixelSize", pixelSize);
      compositeMaterial.SetVector ("_LowResTextureSize", new Vector2(lowDepth.width, lowDepth.height));
      compositeMaterial.SetFloat("_DepthMult", 32.0f);
	   compositeMaterial.SetFloat("_Threshold", depthThreshold);
      compositeMaterial.SetTexture("_ParticleRT", particlesRT);
      Profiler.BeginSample("Blit");
      Graphics.Blit(src, dest);
      Profiler.EndSample();
      Profiler.BeginSample("Composite");
      Graphics.Blit(particlesRT, dest, compositeMaterial);
      Profiler.EndSample();


      
      if (debugOptions.debugDrawBuffers)
      {
         GL.PushMatrix();
         GL.LoadPixelMatrix(0, Screen.width, Screen.height, 0);
         Graphics.DrawTexture(new Rect(0, 0, 128, 128), lowDepth);
         Graphics.DrawTexture(new Rect(0, 128, 128, 128), src);
         Graphics.DrawTexture(new Rect(128, 128, 128, 128), particlesRT);
         GL.PopMatrix();
      }

      // cleanup
      RenderTexture.ReleaseTemporary(particlesRT);
      RenderTexture.ReleaseTemporary(lowDepth);
      Profiler.EndSample();
      
   }
}
