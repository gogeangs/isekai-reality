using System;
using System.Collections;
using UnityEngine;

namespace Arca.Battle
{
    /// <summary>
    /// 무대 위 캐릭터 한 명 (주인공 · 동료 · 몬스터 · 펫 · 정령).
    /// 발 바닥(basePos)에 서서 숨쉬고, 6칸 공격을 재생하고, 맞으면 번쩍이고 흔들린다.
    /// 위치 = basePos + offset, 크기 = height (그림 칸 높이, 유닛)
    /// </summary>
    public class Actor : MonoBehaviour
    {
        static Material sharedMaterial;
        static bool shaderOk;
        static readonly int FlashId = Shader.PropertyToID("_FlashColor");
        static readonly int SwayAmountId = Shader.PropertyToID("_SwayAmount");
        static readonly int SwaySpeedId = Shader.PropertyToID("_SwaySpeed");
        static readonly int SwayWavesId = Shader.PropertyToID("_SwayWaves");
        static readonly int SwayStartId = Shader.PropertyToID("_SwayStart");
        static readonly int SwayPhaseId = Shader.PropertyToID("_SwayPhase");
        static readonly int FrameRectId = Shader.PropertyToID("_FrameRect");

        public SpriteRenderer body;
        SpriteRenderer shadow;
        MaterialPropertyBlock mpb;

        [NonSerialized] public StageLayout layout;
        [NonSerialized] public Vector2 basePos;
        [NonSerialized] public float height = 1f;
        [NonSerialized] public Vector2 offset;
        [NonSerialized] public float tilt;
        [NonSerialized] public Vector2 squash = Vector2.one;
        [NonSerialized] public float alpha = 1f;
        [NonSerialized] public float shadowWidth = 0.45f;
        [NonSerialized] public bool breathing = true;
        [NonSerialized] public bool canSway = true;
        [NonSerialized] public bool busy;
        /// <summary>떨림 (offset 과 따로 더해서, 반격 돌진과 겹쳐도 서로 지우지 않게)</summary>
        [NonSerialized] public float shakeX;

        public Sprite idle;
        public Sprite[] frames;

        float breathPhase, breathRate;
        Color flashColor;
        float flashTime, flashDuration;
        float swayPhase;

        public static Material SharedMaterial
        {
            get
            {
                if (sharedMaterial != null) return sharedMaterial;
                var sh = Shader.Find("Arca/Sprite");
                shaderOk = sh != null && sh.isSupported;
                if (!shaderOk)
                {
                    Debug.LogWarning("[Arca] Arca/Sprite 셰이더를 못 찾아 기본 셰이더로 그림 (번쩍임 · 살랑임 없음)");
                    sh = Shader.Find("Sprites/Default");
                }
                sharedMaterial = new Material(sh) { name = "ArcaSprite (runtime)" };
                return sharedMaterial;
            }
        }

        public static Actor Create(string name, Transform parent, int order, StageLayout layout, float shadowWidth)
        {
            var go = new GameObject(name);
            go.transform.SetParent(parent, false);
            var a = go.AddComponent<Actor>();
            a.layout = layout;
            a.body = go.AddComponent<SpriteRenderer>();
            a.body.sharedMaterial = SharedMaterial;
            a.body.sortingOrder = order;
            a.mpb = new MaterialPropertyBlock();
            a.shadowWidth = shadowWidth;
            if (shadowWidth > 0f)
            {
                var sgo = new GameObject(name + "_Shadow");
                sgo.transform.SetParent(parent, false);
                a.shadow = sgo.AddComponent<SpriteRenderer>();
                a.shadow.sprite = UiKit.Shadow;
                a.shadow.sharedMaterial = SharedMaterial;
                a.shadow.sortingOrder = 5;
            }
            // 캐릭터마다 숨 박자를 조금씩 다르게
            a.breathPhase = UnityEngine.Random.value * Mathf.PI * 2f;
            a.breathRate = 1f + UnityEngine.Random.Range(-1f, 1f) * (layout != null ? layout.breathPeriodJitter : 0.15f);
            a.swayPhase = UnityEngine.Random.value * 10f;
            return a;
        }

        public void SetIdle(Sprite s, bool show = true)
        {
            idle = s;
            if (show && !busy) body.sprite = s;
        }

        public void Show(Sprite s) { if (s != null) body.sprite = s; }

        public void Flash(Color c, float duration)
        {
            flashColor = c;
            flashDuration = Mathf.Max(0.01f, duration);
            flashTime = 0f;
        }

        public Vector3 Center => new Vector3(basePos.x + offset.x, basePos.y + offset.y + height * 0.45f, 0f);
        public Vector3 Head(float k = 0.8f) => new Vector3(basePos.x + offset.x, basePos.y + offset.y + height * k, 0f);

        /// <summary>
        /// 공격 6칸: 2 → 6칸을 차례로 보이고 1칸으로 돌아온다.
        /// hitFrame(1~6) 칸이 보이는 순간 onHit 을 부른다. speed 2 면 칸 시간이 절반.
        /// </summary>
        public IEnumerator PlayAttack(float[] seconds, float speed, int hitFrame, Action onHit, float stepForward)
        {
            if (frames == null || frames.Length < 6) { onHit?.Invoke(); yield break; }
            busy = true;
            bool hitDone = false;
            float baseX = offset.x;
            int count = Mathf.Min(5, seconds.Length);
            for (int k = 0; k < count; k++)
            {
                int frameIndex = k + 1; // 0-based → 2~6칸
                body.sprite = frames[frameIndex];
                if (!hitDone && frameIndex + 1 >= hitFrame)
                {
                    hitDone = true;
                    onHit?.Invoke();
                }
                float dur = seconds[k] / Mathf.Max(0.01f, speed);
                // 앞으로 내딛기: 4칸까지 나가고 5 · 6칸에서 돌아옴
                float from = offset.x - baseX;
                float to = frameIndex <= 3 ? stepForward * (frameIndex / 3f) : stepForward * (1f - (frameIndex - 3) / 2f);
                float t = 0f;
                while (t < dur)
                {
                    t += Time.deltaTime;
                    offset.x = baseX + Mathf.Lerp(from, to, Mathf.SmoothStep(0f, 1f, t / dur));
                    yield return null;
                }
            }
            offset.x = baseX;
            if (!hitDone) onHit?.Invoke();
            body.sprite = frames[0];
            // 1칸에서 아주 잠깐 멈췄다가 대기 그림으로 (동료는 1칸이 곧 대기 그림)
            if (idle != null && idle != frames[0])
            {
                float t = 0f, settle = 0.08f / Mathf.Max(0.01f, speed);
                while (t < settle) { t += Time.deltaTime; yield return null; }
            }
            if (idle != null) body.sprite = idle;
            busy = false;
        }

        /// <summary>줄어드는 좌우 떨림</summary>
        public IEnumerator Shake(float amount, float duration)
        {
            float t = 0f;
            while (t < duration)
            {
                t += Time.deltaTime;
                float k = 1f - Mathf.Clamp01(t / duration);
                shakeX = Mathf.Sin(t / duration * Mathf.PI * 7f) * amount * k;
                yield return null;
            }
            shakeX = 0f;
        }

        public IEnumerator MoveOffset(Vector2 to, float duration, bool easeOut = true)
        {
            Vector2 from = offset;
            float t = 0f;
            while (t < duration)
            {
                t += Time.deltaTime;
                float k = Mathf.Clamp01(t / duration);
                k = easeOut ? 1f - (1f - k) * (1f - k) : k * k;
                offset = Vector2.LerpUnclamped(from, to, k);
                yield return null;
            }
            offset = to;
        }

        public IEnumerator Fade(float to, float duration)
        {
            float from = alpha, t = 0f;
            while (t < duration)
            {
                t += Time.deltaTime;
                alpha = Mathf.Lerp(from, to, t / duration);
                yield return null;
            }
            alpha = to;
        }

        void LateUpdate()
        {
            if (body == null) return;
            float breathY = 1f;
            if (breathing && !busy && layout != null && layout.breathPeriod > 0.01f)
                breathY = 1f + Mathf.Sin(Time.time * Mathf.PI * 2f / (layout.breathPeriod * breathRate) + breathPhase) * layout.breathAmount;

            var p = basePos + offset + new Vector2(shakeX, 0f);
            transform.localPosition = new Vector3(p.x, p.y, 0f);
            transform.localRotation = Quaternion.Euler(0f, 0f, tilt);
            transform.localScale = new Vector3(height * squash.x, height * squash.y * breathY, 1f);

            float flashA = 0f;
            if (flashTime < flashDuration)
            {
                flashTime += Time.deltaTime;
                flashA = flashColor.a * (1f - Mathf.Clamp01(flashTime / flashDuration));
            }

            var c = body.color;
            c.a = alpha;
            body.color = c;

            if (shaderOk)
            {
                body.GetPropertyBlock(mpb);
                mpb.SetColor(FlashId, new Color(flashColor.r, flashColor.g, flashColor.b, flashA));
                bool sway = canSway && Session.sway && layout != null && body.sprite != null;
                float amount = 0f;
                if (sway)
                {
                    var tex = body.sprite.texture;
                    var r = body.sprite.textureRect;
                    // 그림 px 를 원래 칸 크기 기준으로 → uv
                    amount = layout.swayPixels / Mathf.Max(1f, r.width) * (r.width / tex.width);
                    mpb.SetVector(FrameRectId, new Vector4(r.xMin / tex.width, r.yMin / tex.height, r.xMax / tex.width, r.yMax / tex.height));
                    mpb.SetFloat(SwaySpeedId, layout.swaySpeed);
                    mpb.SetFloat(SwayWavesId, layout.swayWaves);
                    mpb.SetFloat(SwayStartId, layout.swayStart);
                    mpb.SetFloat(SwayPhaseId, swayPhase);
                }
                mpb.SetFloat(SwayAmountId, amount);
                body.SetPropertyBlock(mpb);
            }
            else if (flashA > 0f)
            {
                body.color = Color.Lerp(new Color(1, 1, 1, alpha), new Color(flashColor.r, flashColor.g, flashColor.b, alpha), flashA);
            }

            if (shadow != null)
            {
                float lift = Mathf.Max(0f, offset.y);
                float w = height * shadowWidth * Mathf.Clamp(1f - lift * 0.25f, 0.5f, 1f);
                shadow.transform.localPosition = new Vector3(p.x, basePos.y + Mathf.Min(0f, offset.y) - height * 0.01f, 0f);
                shadow.transform.localScale = new Vector3(w, w * 0.5f, 1f);
                shadow.enabled = body.enabled && alpha > 0.05f;
                var sc = shadow.color;
                sc.a = alpha;
                shadow.color = sc;
            }
        }

        void OnDestroy()
        {
            if (shadow != null) Destroy(shadow.gameObject);
        }
    }
}
