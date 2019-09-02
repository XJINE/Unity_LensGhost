Shader "ImageEffect/LensGhost"
{
    Properties
    {
        [HideInInspector]
        _MainTex("Texture", 2D) = "white" {}

        _GhostColorTex("Ghost Color", 2D) = "white" {}

        [KeywordEnum(ADDITIVE, SCREEN, DEBUG)]
        _COMPOSITE_TYPE("Composite Type", Float) = 0

        _Parameter("(Threhold, Intensity, Scale, Offset)", Vector) = (0.8, 1.0, 0.8, 0.0)
    }
    SubShader
    {
        CGINCLUDE

        #include "UnityCG.cginc"
        #include "Assets/Packages/Shaders/ImageFilters.cginc"

        sampler2D _MainTex;
        float4    _MainTex_ST;
        float4    _MainTex_TexelSize;
        sampler2D _GhostColorTex;
        float4    _Parameter;
        uint      _GPUIteration;

        #define BRIGHTNESS_THRESHOLD _Parameter.x
        #define INTENSITY            _Parameter.y
        #define DISPERSION_SCALE     _Parameter.z
        #define DISPERSION_OFFSET    _Parameter.w

        ENDCG

        // STEP:0
        // Debug.

        Pass
        {
            CGPROGRAM

            #pragma vertex vert_img
            #pragma fragment frag

            fixed4 frag(v2f_img input) : SV_Target
            {
                return tex2D(_MainTex, input.uv);
            }

            ENDCG
        }

        // STEP:1
        // Get resized brightness image.

        Pass
        {
            CGPROGRAM

            #pragma vertex vert_img
            #pragma fragment frag

            fixed4 frag(v2f_img input) : SV_Target
            {
                float4 color = tex2D(_MainTex, input.uv);
                float4 brightness = max(color - BRIGHTNESS_THRESHOLD, 0) * INTENSITY;

                // NOTE:
                // return brightness; is enough for make brightness image.
                // However, make masked image is important to prevent rectangular edges.

                float2 uv = float2(0.5, 0.5) - input.uv;
                float sqrLength = uv.x * uv.x + uv.y * uv.y;
                float circleMask = saturate(1 - sqrLength * 4);

                // DEBUG:
                //return circleMask;
                //return tex2D(_GhostColorTex, sqrLength / 0.25);

                return brightness * circleMask;
            }

            ENDCG
        }

        // STEP:2, 3
        // Get blurred brightness image.

        CGINCLUDE

        struct v2f_gaussian
        {
            float4 pos    : SV_POSITION;
            half2  uv     : TEXCOORD0;
            half2  offset : TEXCOORD1;
        };

        float4 frag_gaussian (v2f_gaussian input) : SV_Target
        {
            return GaussianFilter(_MainTex, _MainTex_ST, input.uv, input.offset);
        }

        ENDCG

        Pass
        {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag_gaussian

            v2f_gaussian vert(appdata_img v)
            {
                v2f_gaussian o;

                o.pos    = UnityObjectToClipPos (v.vertex);
                o.uv     = v.texcoord;
                o.offset = _MainTex_TexelSize.xy * float2(1, 0);

                return o;
            }

            ENDCG
        }

        Pass
        {
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag_gaussian

            v2f_gaussian vert(appdata_img v)
            {
                v2f_gaussian o;

                o.pos    = UnityObjectToClipPos (v.vertex);
                o.uv     = v.texcoord;
                o.offset = _MainTex_TexelSize.xy * float2(0, 1);

                return o;
            }

            ENDCG
        }

        // STEP:4
        // Get ghost image.

        Pass
        {
            CGPROGRAM

            #pragma vertex vert_img
            #pragma fragment frag

            float4 frag(v2f_img input) : SV_Target
            {
                float4 color    = tex2D(_MainTex, input.uv);
                float2 flipedUV = float2(1, 1) - input.uv;
                float2 toCenter = (float2(0.5, 0.5) - flipedUV) * DISPERSION_SCALE;

                float2 uv = float2(0.5, 0.5) - input.uv;
                float sqrLength = uv.x * uv.x + uv.y * uv.y;
                float circleMask = saturate(1 - sqrLength * 4);

                for (uint i = 0; i < _GPUIteration; i++)
                {
                    float2 scaledUV = flipedUV - toCenter * (DISPERSION_OFFSET + i);
                    color += tex2D(_MainTex, scaledUV);
                }

                return color * tex2D(_GhostColorTex, sqrLength / 0.25) * circleMask;
            }

            ENDCG
        }

        // STEP:5
        // Composite to original.

        Pass
        {
            CGPROGRAM

            #pragma vertex vert_img
            #pragma fragment frag
            #pragma multi_compile _COMPOSITE_TYPE_ADDITIVE _COMPOSITE_TYPE_SCREEN _COMPOSITE_TYPE_DEBUG

            sampler2D _CompositeTex;
            float4    _CompositeColor;

            fixed4 frag(v2f_img input) : SV_Target
            {
                float4 mainColor      = tex2D(_MainTex,      input.uv);
                float4 compositeColor = tex2D(_CompositeTex, input.uv);

                #if defined(_COMPOSITE_TYPE_SCREEN)

                return saturate(mainColor + compositeColor - saturate(mainColor * compositeColor));

                #elif defined(_COMPOSITE_TYPE_ADDITIVE)

                return saturate(mainColor + compositeColor);

                #else

                return compositeColor;

                #endif
            }

            ENDCG
        }
    }
}