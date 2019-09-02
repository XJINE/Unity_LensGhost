using System.Collections.Generic;
using UnityEngine;

public class LensGhost : ImageEffectBase
{
    #region Enum

    public enum CompositeType
    {
        _COMPOSITE_TYPE_ADDITIVE = 0,
        _COMPOSITE_TYPE_SCREEN   = 1,
        _COMPOSITE_TYPE_DEBUG    = 2
    }

    #endregion Enum

    #region Field

    private static Dictionary<CompositeType, string> CompositeTypes = new Dictionary<CompositeType, string>()
    {
        { CompositeType._COMPOSITE_TYPE_ADDITIVE, CompositeType._COMPOSITE_TYPE_ADDITIVE.ToString() },
        { CompositeType._COMPOSITE_TYPE_SCREEN,   CompositeType._COMPOSITE_TYPE_SCREEN.ToString()   },
        { CompositeType._COMPOSITE_TYPE_DEBUG,    CompositeType._COMPOSITE_TYPE_DEBUG.ToString()    }
    };

    public LensGhost.CompositeType compositeType = LensGhost.CompositeType._COMPOSITE_TYPE_SCREEN;

    [Range(0, 2)] // To considered HDR.
    public float threshold = 1;

    [Range(0, 10)]
    public float intensity = 1;

    [Range(1, 16)]
    public int divide = 3;

    public float dispersionScale = 0.7f;

    public float dispersionOffset = 0f;

    [Range(1, 5)]
    public int cpuIteration = 3;

    [Range(1, 10)]
    public int gpuIteration = 5;

    public    Gradient  ghostColor;
    protected Gradient  ghostColorPrev;
    public Texture2D ghostColorTex;
    protected int       ghostColorTexWidth = 32;

    private int idCompositeTex  = 0;
    private int idGhostColorTex = 0;
    private int idParameter     = 0;
    private int idGPUIteration  = 0;

    #endregion Field

    #region Method

    protected override void Start()
    {
        base.Start();

        this.idCompositeTex  = Shader.PropertyToID("_CompositeTex");
        this.idGhostColorTex = Shader.PropertyToID("_GhostColorTex");
        this.idParameter     = Shader.PropertyToID("_Parameter");
        this.idGPUIteration  = Shader.PropertyToID("_GPUIteration");

        this.ghostColorPrev = this.ghostColor;
        this.ghostColorTex = new Texture2D(this.ghostColorTexWidth, 1, TextureFormat.ARGB32, false);
    }

    protected override void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        var descriptor = new RenderTextureDescriptor(source.width / this.divide,
                                                     source.height / this.divide,
                                                     source.format);
        RenderTexture tempTex1 = RenderTexture.GetTemporary(descriptor);
        RenderTexture tempTex2 = RenderTexture.GetTemporary(descriptor);

        UpdateGhostColorTex();

        base.material.SetTexture(this.idGhostColorTex, this.ghostColorTex);
        base.material.SetVector(this.idParameter, new Vector4(this.threshold,
                                                              this.intensity,
                                                              this.dispersionScale,
                                                              this.dispersionOffset));

        // STEP:1
        // Get resized brightness image.

        Graphics.Blit(source, tempTex1, base.material, 1);

        // DEBUG:

        //Graphics.Blit(tempTex1, destination, base.material, 0);
        //RenderTexture.ReleaseTemporary(tempTex1);
        //RenderTexture.ReleaseTemporary(tempTex2);
        //return;

        // STEP:2
        // Get blurred brightness image.

        Graphics.Blit(tempTex1, tempTex2, base.material, 2);
        Graphics.Blit(tempTex2, tempTex1, base.material, 3);

        // DEBUG:

        //Graphics.Blit(tempTex1, destination, base.material, 0);
        //RenderTexture.ReleaseTemporary(tempTex1);
        //RenderTexture.ReleaseTemporary(tempTex2);
        //return;

        // STEP:3
        // Get ghost image.

        base.material.SetInt(this.idGPUIteration, this.gpuIteration);

        for (int x = 0; x < this.cpuIteration; x++)
        {
            Graphics.Blit(tempTex1, tempTex2, base.material, 4);
            RenderTexture temp = tempTex1;
            tempTex1 = tempTex2;
            tempTex2 = temp;
        }

        // STEP:4
        // Composite.

        base.material.EnableKeyword(LensGhost.CompositeTypes[this.compositeType]);
        base.material.SetTexture(this.idCompositeTex, tempTex1);

        Graphics.Blit(source, destination, base.material, 5);

        // STEP:5
        // Close.

        base.material.DisableKeyword(LensGhost.CompositeTypes[this.compositeType]);

        RenderTexture.ReleaseTemporary(tempTex1);
        RenderTexture.ReleaseTemporary(tempTex2);
    }

    protected virtual void OnDisable()
    {
        #if UNITY_EDITOR
        DestroyImmediate(this.ghostColorTex);
        #else
        Destroy(this.ghostColorTex);
        #endif
    }

    protected void UpdateGhostColorTex()
    {
        if (this.ghostColorTex == null)
        {
            this.ghostColorTex = new Texture2D
            (this.ghostColorTexWidth, 1, TextureFormat.ARGB32, false);
        }

        for (int x = 0; x < this.ghostColorTexWidth; x++)
        {
            this.ghostColorTex.SetPixel
            (x, 1, this.ghostColor.Evaluate((float)x / this.ghostColorTexWidth));
        }

        this.ghostColorTex.Apply();
    }

    #endregion Method
}