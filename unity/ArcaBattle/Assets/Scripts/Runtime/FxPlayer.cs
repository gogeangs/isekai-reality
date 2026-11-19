using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Arca.Battle
{
    /// <summary>효과 그림 (맞은 효과 · 베기 · 방어) 을 잠깐 띄웠다 사라지게</summary>
    public class FxPlayer : MonoBehaviour
    {
        readonly List<SpriteRenderer> pool = new List<SpriteRenderer>();

        SpriteRenderer Get()
        {
            foreach (var s in pool)
                if (!s.gameObject.activeSelf) { s.gameObject.SetActive(true); return s; }
            var go = new GameObject("Fx");
            go.transform.SetParent(transform, false);
            var sr = go.AddComponent<SpriteRenderer>();
            sr.sharedMaterial = Actor.SharedMaterial;
            pool.Add(sr);
            return sr;
        }

        /// <param name="size">효과 그림의 높이 (유닛)</param>
        public void Pop(Sprite sprite, Vector3 pos, float size, float duration, float scaleFrom = 0.6f, float scaleTo = 1.1f,
            float rotation = 0f, int order = 30, Color? tint = null)
        {
            if (sprite == null) return;
            var sr = Get();
            sr.sprite = sprite;
            sr.sortingOrder = order;
            sr.color = tint ?? Color.white;
            sr.transform.localPosition = pos;
            sr.transform.localRotation = Quaternion.Euler(0, 0, rotation);
            StartCoroutine(Animate(sr, size, duration, scaleFrom, scaleTo, tint ?? Color.white));
        }

        IEnumerator Animate(SpriteRenderer sr, float size, float duration, float s0, float s1, Color tint)
        {
            // 효과 그림은 가운데 기준, 높이 1 유닛 스프라이트 → size 로 키움
            float t = 0f;
            while (t < duration)
            {
                t += Time.deltaTime;
                float k = Mathf.Clamp01(t / duration);
                float e = 1f - (1f - k) * (1f - k) * (1f - k);
                float sc = size * Mathf.Lerp(s0, s1, e);
                sr.transform.localScale = new Vector3(sc, sc, 1f);
                var c = tint;
                c.a = tint.a * (k < 0.45f ? 1f : 1f - (k - 0.45f) / 0.55f);
                sr.color = c;
                yield return null;
            }
            sr.gameObject.SetActive(false);
        }

        void OnDisable()
        {
            foreach (var s in pool) if (s != null) s.gameObject.SetActive(false);
        }
    }
}
