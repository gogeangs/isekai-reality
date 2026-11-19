using UnityEngine;

namespace Arca.Battle
{
    /// <summary>작게 시작해 통 튀어나오며 나타나기</summary>
    public class PopIn : MonoBehaviour
    {
        public float delay;
        float t;
        void OnEnable() { t = 0f; transform.localScale = Vector3.zero; }
        void Update()
        {
            t += Time.unscaledDeltaTime;
            float k = Mathf.Clamp01((t - delay) / 0.35f);
            // 살짝 넘쳤다가 돌아오는 곡선
            float s = k <= 0f ? 0f : 1f + 2.2f * Mathf.Pow(k - 1f, 3f) + 1.2f * Mathf.Pow(k - 1f, 2f);
            transform.localScale = Vector3.one * s;
            if (k >= 1f) { transform.localScale = Vector3.one; enabled = false; }
        }
    }
}
