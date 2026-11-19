using UnityEngine;
using UnityEngine.UI;

namespace Arca.Battle
{
    /// <summary>위로 떠오르며 사라지는 피해 숫자. 치명타는 크게 튀어나왔다 줄어든다.</summary>
    public class FloatingText : MonoBehaviour
    {
        BattleHud hud;
        Vector3 world;
        bool crit;
        float t;
        const float Life = 0.95f;
        RectTransform rt;
        Text text;
        Outline outline;
        Color baseColor;

        public void Init(BattleHud h, Vector3 w, bool isCrit)
        {
            hud = h; world = w; crit = isCrit;
            rt = (RectTransform)transform;
            text = GetComponent<Text>();
            outline = GetComponent<Outline>();
            baseColor = text.color;
            Place();
        }

        void Place()
        {
            float k = Mathf.Clamp01(t / Life);
            float rise = (1f - (1f - k) * (1f - k)) * 150f;
            rt.anchoredPosition = hud.WorldToCanvas(world) + new Vector2(0f, rise);
            float scale = crit ? Mathf.Lerp(1.7f, 1.12f, Mathf.Clamp01(t / 0.16f)) : Mathf.Lerp(1.25f, 1f, Mathf.Clamp01(t / 0.1f));
            rt.localScale = Vector3.one * scale;
            float a = k < 0.55f ? 1f : 1f - (k - 0.55f) / 0.45f;
            var c = baseColor; c.a = a; text.color = c;
            if (outline != null) { var oc = outline.effectColor; oc.a = 0.9f * a; outline.effectColor = oc; }
        }

        void Update()
        {
            t += Time.deltaTime;
            if (t >= Life || hud == null) { Destroy(gameObject); return; }
            Place();
        }
    }
}
