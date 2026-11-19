using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Arca.Battle
{
    /// <summary>색 · 글꼴 · 코드로 그리는 UI 그림 (금테 판, 막대, 동그라미)</summary>
    public static class UiKit
    {
        public static readonly Color Night = Hex("#14132B");
        public static readonly Color Panel = Hex("#1D1C3D");
        public static readonly Color Gold = Hex("#E6C379");
        public static readonly Color Ink = Hex("#EFE9DC");
        public static readonly Color TextMuted = new Color(0.937f, 0.914f, 0.863f, 0.62f);
        public static readonly Color HeroHp = Hex("#6FD08C");
        public static readonly Color MonsterHp = Hex("#E8655A");
        public static readonly Color AllyHp = Hex("#7FC4E8");
        public static readonly Color BarBack = Hex("#0E0D22");
        public static readonly Color Crit = Hex("#FFD24A");

        public static Color Hex(string hex)
        {
            ColorUtility.TryParseHtmlString(hex, out var c);
            return c;
        }

        // ---------- 글꼴 ----------
        static Font title, body, bodyBold;

        /// <summary>제목: 고운바탕</summary>
        public static Font TitleFont => title != null ? title : (title = LoadFont("Fonts/GowunBatang-Bold"));
        /// <summary>본문: Noto Sans KR</summary>
        public static Font BodyFont => body != null ? body : (body = LoadFont("Fonts/NotoSansKR-Regular"));
        public static Font BodyBold => bodyBold != null ? bodyBold : (bodyBold = LoadFont("Fonts/NotoSansKR-Bold"));

        static Font LoadFont(string path)
        {
            var f = Resources.Load<Font>(path);
            if (f != null) return f;
            Debug.LogWarning("[Arca] 글꼴을 찾지 못해 컴퓨터 글꼴을 씀: " + path);
            return Font.CreateDynamicFontFromOSFont(new[] { "Apple SD Gothic Neo", "Malgun Gothic", "Noto Sans CJK KR", "Arial" }, 32);
        }

        // ---------- 코드로 그리는 그림 ----------
        static Sprite roundPanel, roundBar, circle, white, shadow, bubble;

        /// <summary>금테 남색 판 (9칸 나눔으로 늘려 씀)</summary>
        public static Sprite RoundPanel => roundPanel != null ? roundPanel : (roundPanel = MakeRounded(96, 30, 4f, Panel, Gold));
        /// <summary>둥근 막대 (흰색, Image 색으로 칠함)</summary>
        public static Sprite RoundBar => roundBar != null ? roundBar : (roundBar = MakeRounded(48, 22, 0f, Color.white, Color.white));
        public static Sprite Circle => circle != null ? circle : (circle = MakeCircle(128));
        public static Sprite White => white != null ? white : (white = MakeWhite());
        /// <summary>발밑 그림자 (타원, 가장자리 흐림)</summary>
        public static Sprite Shadow => shadow != null ? shadow : (shadow = MakeShadow(128));
        /// <summary>말풍선 판</summary>
        public static Sprite Bubble => bubble != null ? bubble : (bubble = MakeRounded(64, 26, 3f, new Color(1f, 0.98f, 0.92f, 0.96f), Gold));

        static Sprite MakeWhite()
        {
            var t = new Texture2D(4, 4, TextureFormat.RGBA32, false);
            var px = new Color32[16];
            for (int i = 0; i < px.Length; i++) px[i] = new Color32(255, 255, 255, 255);
            t.SetPixels32(px);
            t.Apply();
            return Sprite.Create(t, new Rect(0, 0, 4, 4), new Vector2(0.5f, 0.5f), 4);
        }

        static Sprite MakeRounded(int size, int radius, float border, Color fill, Color edge)
        {
            var t = new Texture2D(size, size, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear };
            var px = new Color[size * size];
            float r = radius;
            for (int y = 0; y < size; y++)
                for (int x = 0; x < size; x++)
                {
                    float cx = Mathf.Clamp(x + 0.5f, r, size - r);
                    float cy = Mathf.Clamp(y + 0.5f, r, size - r);
                    float d = Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(cx, cy));
                    float a = Mathf.Clamp01(r - d + 0.5f);
                    Color c = fill;
                    if (border > 0f)
                    {
                        float e = Mathf.Clamp01((d - (r - border)) + 0.5f);
                        c = Color.Lerp(fill, edge, e);
                    }
                    c.a *= a;
                    px[y * size + x] = c;
                }
            t.SetPixels(px);
            t.Apply();
            float b = radius + 2;
            return Sprite.Create(t, new Rect(0, 0, size, size), new Vector2(0.5f, 0.5f), 100, 0, SpriteMeshType.FullRect, new Vector4(b, b, b, b));
        }

        static Sprite MakeCircle(int size)
        {
            var t = new Texture2D(size, size, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            var px = new Color[size * size];
            float r = size * 0.5f;
            for (int y = 0; y < size; y++)
                for (int x = 0; x < size; x++)
                {
                    float d = Vector2.Distance(new Vector2(x + 0.5f, y + 0.5f), new Vector2(r, r));
                    px[y * size + x] = new Color(1, 1, 1, Mathf.Clamp01(r - d));
                }
            t.SetPixels(px);
            t.Apply();
            return Sprite.Create(t, new Rect(0, 0, size, size), new Vector2(0.5f, 0.5f), size);
        }

        static Sprite MakeShadow(int size)
        {
            var t = new Texture2D(size, size / 2, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            int h = size / 2;
            var px = new Color[size * h];
            for (int y = 0; y < h; y++)
                for (int x = 0; x < size; x++)
                {
                    float dx = (x + 0.5f) / size * 2f - 1f;
                    float dy = (y + 0.5f) / h * 2f - 1f;
                    float d = Mathf.Sqrt(dx * dx + dy * dy);
                    float a = Mathf.Clamp01(1f - d);
                    px[y * size + x] = new Color(0.03f, 0.02f, 0.08f, a * a * 0.55f);
                }
            t.SetPixels(px);
            t.Apply();
            // 1 유닛 너비, 가운데 기준
            return Sprite.Create(t, new Rect(0, 0, size, h), new Vector2(0.5f, 0.5f), size);
        }

        /// <summary>위 → 아래로 어두워지는 띠 (무대 아래쪽을 판과 자연스럽게 잇기)</summary>
        public static Sprite VerticalFade(Color bottom, float startFromTop)
        {
            const int h = 64;
            var t = new Texture2D(1, h, TextureFormat.RGBA32, false) { wrapMode = TextureWrapMode.Clamp };
            var px = new Color[h];
            for (int y = 0; y < h; y++)
            {
                float fromTop = 1f - (y + 0.5f) / h;
                float a = Mathf.Clamp01((fromTop - startFromTop) / (1f - startFromTop));
                px[y] = new Color(bottom.r, bottom.g, bottom.b, bottom.a * a);
            }
            t.SetPixels(px);
            t.Apply();
            return Sprite.Create(t, new Rect(0, 0, 1, h), new Vector2(0.5f, 0.5f), h);
        }

        // ---------- UI 만들기 ----------
        public static RectTransform Rect(string name, Transform parent, Vector2 anchorMin, Vector2 anchorMax)
        {
            var go = new GameObject(name, typeof(RectTransform));
            var rt = (RectTransform)go.transform;
            rt.SetParent(parent, false);
            rt.anchorMin = anchorMin;
            rt.anchorMax = anchorMax;
            rt.offsetMin = Vector2.zero;
            rt.offsetMax = Vector2.zero;
            return rt;
        }

        public static Image Image(string name, Transform parent, Vector2 aMin, Vector2 aMax, Sprite sprite, Color color, bool sliced = false)
        {
            var rt = Rect(name, parent, aMin, aMax);
            var img = rt.gameObject.AddComponent<Image>();
            img.sprite = sprite;
            img.color = color;
            img.raycastTarget = false;
            if (sliced) img.type = UnityEngine.UI.Image.Type.Sliced;
            return img;
        }

        public static Text Label(string name, Transform parent, Vector2 aMin, Vector2 aMax, string text, int size,
            Color color, TextAnchor align = TextAnchor.MiddleCenter, Font font = null, bool outline = false)
        {
            var rt = Rect(name, parent, aMin, aMax);
            var t = rt.gameObject.AddComponent<Text>();
            t.font = font != null ? font : BodyFont;
            t.text = text;
            t.fontSize = size;
            t.color = color;
            t.alignment = align;
            t.raycastTarget = false;
            t.horizontalOverflow = HorizontalWrapMode.Overflow;
            t.verticalOverflow = VerticalWrapMode.Overflow;
            t.supportRichText = true;
            if (outline)
            {
                var o = rt.gameObject.AddComponent<Outline>();
                o.effectColor = new Color(0.05f, 0.04f, 0.12f, 0.9f);
                o.effectDistance = new Vector2(3, -3);
            }
            return t;
        }

        /// <summary>그림 버튼. 정사각형을 유지 (세로 높이에 맞춰 너비를 정함)</summary>
        public static Button SquareButton(string name, Transform parent, float centerX, float yMin, float yMax, Sprite sprite)
        {
            var rt = Rect(name, parent, new Vector2(centerX, yMin), new Vector2(centerX, yMax));
            var fit = rt.gameObject.AddComponent<AspectRatioFitter>();
            fit.aspectMode = AspectRatioFitter.AspectMode.HeightControlsWidth;
            fit.aspectRatio = 1f;
            var img = rt.gameObject.AddComponent<Image>();
            img.sprite = sprite;
            img.preserveAspect = true;
            var b = rt.gameObject.AddComponent<Button>();
            b.transition = Selectable.Transition.None;
            rt.gameObject.AddComponent<PressBounce>();
            return b;
        }

        /// <summary>둥근 글자 버튼</summary>
        public static Button TextButton(string name, Transform parent, Vector2 aMin, Vector2 aMax, string label, int size, out Text text)
        {
            var img = Image(name, parent, aMin, aMax, RoundPanel, Color.white, true);
            img.raycastTarget = true;
            var b = img.gameObject.AddComponent<Button>();
            b.transition = Selectable.Transition.ColorTint;
            var cb = b.colors;
            cb.disabledColor = new Color(0.55f, 0.55f, 0.6f, 0.7f);
            b.colors = cb;
            img.gameObject.AddComponent<PressBounce>();
            text = Label("Text", img.transform, Vector2.zero, Vector2.one, label, size, Ink, TextAnchor.MiddleCenter, BodyBold);
            return b;
        }

        public static void EnsureEventSystem()
        {
            if (Object.FindAnyObjectByType<EventSystem>() != null) return;
            var go = new GameObject("EventSystem", typeof(EventSystem));
            // 새 입력 시스템(Input System 패키지)을 쓰는 프로젝트면 그쪽 모듈, 아니면 기본 모듈
            var newInput = System.Type.GetType("UnityEngine.InputSystem.UI.InputSystemUIInputModule, Unity.InputSystem");
            if (newInput != null) go.AddComponent(newInput);
            else go.AddComponent<StandaloneInputModule>();
        }
    }

}
