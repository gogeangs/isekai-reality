using System.Collections.Generic;
using UnityEngine;

namespace Arca.Battle
{
    /// <summary>
    /// 그림 불러오기 · 칸 나누기.
    /// Sprite Editor 에서 손으로 칸을 나누는 대신, 코드가 같은 일을 한다:
    /// 6칸 그림을 같은 너비로 자르고, Pivot(기준점)을 각 그림의 발 바닥에 둔다.
    /// 그래서 칸이 바뀌어도 발이 흔들리지 않고, 그림을 새로 바꿔 넣어도 다시 손댈 필요가 없다.
    ///
    /// 모든 그림은 「칸 높이 = 1 유닛」으로 만든다. 화면 크기는 transform 의 scale 로 정한다.
    /// (서기 768×1024 와 공격 640×800 이 같은 칸 높이가 되어, 공격할 때 키가 줄지 않는다)
    /// </summary>
    public static class ArtLibrary
    {
        static readonly Dictionary<string, Texture2D> textures = new Dictionary<string, Texture2D>();
        static readonly Dictionary<string, Sprite> singles = new Dictionary<string, Sprite>();
        static readonly Dictionary<string, Sprite[]> sheets = new Dictionary<string, Sprite[]>();

        public static Texture2D Tex(string path)
        {
            if (textures.TryGetValue(path, out var t) && t != null) return t;
            t = Resources.Load<Texture2D>("Art/" + path);
            if (t == null) Debug.LogWarning("[Arca] 그림을 찾지 못함: Resources/Art/" + path);
            else
            {
                t.wrapMode = TextureWrapMode.Clamp;
                textures[path] = t;
            }
            return t;
        }

        /// <summary>한 장 그림. footFromTop: 발 바닥 위치 (위에서부터, 원래 그림 높이 대비 0~1). 음수면 가운데 기준.</summary>
        public static Sprite Single(string path, float footFromTop = -1f)
        {
            string key = path + "|" + footFromTop.ToString("0.0000");
            if (singles.TryGetValue(key, out var s) && s != null) return s;
            var t = Tex(path);
            if (t == null) return null;
            var pivot = footFromTop < 0 ? new Vector2(0.5f, 0.5f) : new Vector2(0.5f, 1f - footFromTop);
            s = Sprite.Create(t, new Rect(0, 0, t.width, t.height), pivot, t.height, 0, SpriteMeshType.FullRect);
            s.name = path;
            singles[key] = s;
            return s;
        }

        /// <summary>가로로 늘어선 여러 칸 그림을 같은 너비로 자른다.</summary>
        public static Sprite[] Sheet(string path, int frames, float footFromTop)
        {
            string key = path + "|" + frames + "|" + footFromTop.ToString("0.0000");
            if (sheets.TryGetValue(key, out var arr) && arr != null) return arr;
            var t = Tex(path);
            if (t == null) return null;
            arr = new Sprite[frames];
            // 그림이 줄어서 들어왔어도(최대 크기 설정) 비율로 자르면 맞는다
            float fw = t.width / (float)frames;
            for (int i = 0; i < frames; i++)
            {
                var rect = new Rect(Mathf.Round(i * fw), 0, Mathf.Round(fw), t.height);
                arr[i] = Sprite.Create(t, rect, new Vector2(0.5f, 1f - footFromTop), t.height, 0, SpriteMeshType.FullRect);
                arr[i].name = path + "_" + (i + 1);
            }
            sheets[key] = arr;
            return arr;
        }

        /// <summary>UI 에 쓸 가운데 기준 그림</summary>
        public static Sprite Ui(string path) => Single(path, -1f);

        public static void ClearCache()
        {
            singles.Clear();
            sheets.Clear();
            textures.Clear();
        }
    }
}
