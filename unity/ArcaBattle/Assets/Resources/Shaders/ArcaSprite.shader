// 아르카 캐릭터 그림용 셰이더 (그림을 화면에 그리는 작은 프로그램)
// - 번쩍임: _FlashColor 의 색으로 덮음 (a = 세기). 맞으면 하양, 반격 맞으면 빨강
// - 살랑임: 몸 위쪽(머리카락 · 망토)을 물결처럼 옆으로 조금 밀어 그림. 발 쪽은 그대로
//   _FrameRect 는 6칸 그림에서 지금 칸의 범위 → 옆 칸이 비쳐 들어오지 않게 막음
// URP 2D 렌더러와 기본 렌더러 둘 다에서 그려지도록 빛 계산 없이(Unlit) 만듦
Shader "Arca/Sprite"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite", 2D) = "white" {}
        _FlashColor ("Flash Color (a = amount)", Color) = (1,1,1,0)
        _SwayAmount ("Sway Amount (uv)", Float) = 0
        _SwaySpeed ("Sway Speed", Float) = 3.2
        _SwayWaves ("Sway Waves", Float) = 9
        _SwayStart ("Sway Start", Range(0,1)) = 0.45
        _SwayPhase ("Sway Phase", Float) = 0
        _FrameRect ("Frame UV Rect", Vector) = (0,0,1,1)
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType" = "Plane"
            "CanUseSpriteAtlas" = "True"
        }

        Cull Off
        Lighting Off
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata_t
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                fixed4 color : COLOR;
                float2 uv : TEXCOORD0;
            };

            sampler2D _MainTex;
            fixed4 _FlashColor;
            float _SwayAmount;
            float _SwaySpeed;
            float _SwayWaves;
            float _SwayStart;
            float _SwayPhase;
            float4 _FrameRect;

            v2f vert (appdata_t v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;
                o.color = v.color;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv;
                if (_SwayAmount > 0.0)
                {
                    float2 fmin = _FrameRect.xy;
                    float2 fmax = _FrameRect.zw;
                    float ly = saturate((uv.y - fmin.y) / max(1e-5, fmax.y - fmin.y));
                    float lx = saturate((uv.x - fmin.x) / max(1e-5, fmax.x - fmin.x));
                    // 위로 갈수록 더 흔들림, 등 쪽(왼쪽, 오른쪽을 보고 있으므로)이 더 흔들림
                    float w = smoothstep(_SwayStart, 1.0, ly) * lerp(1.0, 0.5, lx);
                    float t = _Time.y * _SwaySpeed + _SwayPhase;
                    float wave = sin(t + ly * _SwayWaves) * 0.7 + sin(t * 1.7 + ly * _SwayWaves * 2.3) * 0.3;
                    uv.x = clamp(uv.x + wave * _SwayAmount * w, fmin.x, fmax.x);
                }
                fixed4 c = tex2D(_MainTex, uv) * i.color;
                c.rgb = lerp(c.rgb, _FlashColor.rgb, _FlashColor.a);
                return c;
            }
            ENDCG
        }
    }

    Fallback "Sprites/Default"
}
