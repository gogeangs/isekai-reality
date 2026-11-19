using UnityEngine;

namespace Arca.Battle
{
    /// <summary>
    /// 아주 짧은 화면 멈춤(히트스톱). 때리는 순간 시간을 잠깐 0 으로 만들어 타격감을 준다.
    /// </summary>
    public class HitStop : MonoBehaviour
    {
        static HitStop instance;
        float until;

        public static void Request(float seconds)
        {
            if (seconds <= 0f) return;
            if (instance == null)
            {
                var go = new GameObject("HitStop");
                instance = go.AddComponent<HitStop>();
            }
            instance.until = Mathf.Max(instance.until, Time.realtimeSinceStartup + seconds);
            Time.timeScale = 0f;
        }

        void Update()
        {
            if (Time.timeScale == 0f && Time.realtimeSinceStartup >= until) Time.timeScale = 1f;
        }

        void OnDestroy()
        {
            Time.timeScale = 1f;
            if (instance == this) instance = null;
        }
    }
}
