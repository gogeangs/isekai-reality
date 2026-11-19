using UnityEngine;
using UnityEngine.EventSystems;

namespace Arca.Battle
{
    /// <summary>누르면 살짝 줄었다가 돌아오는 버튼 느낌</summary>
    public class PressBounce : MonoBehaviour, IPointerDownHandler, IPointerUpHandler, IPointerExitHandler
    {
        float target = 1f, current = 1f;
        public void OnPointerDown(PointerEventData e) { target = 0.9f; }
        public void OnPointerUp(PointerEventData e) { target = 1f; }
        public void OnPointerExit(PointerEventData e) { target = 1f; }
        void Update()
        {
            current = Mathf.Lerp(current, target, 1f - Mathf.Exp(-25f * Time.unscaledDeltaTime));
            transform.localScale = new Vector3(current, current, 1f);
        }
    }
}
