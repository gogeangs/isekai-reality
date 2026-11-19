#if ARCA_SPRITE_EDITOR
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.U2D.Sprites;
using UnityEngine;

namespace Arca.Battle.EditorTools
{
    /// <summary>
    /// (선택) 6칸 그림을 Sprite Editor 에서도 칸으로 보이게 나누기.
    /// 게임은 코드(ArtLibrary)가 직접 칸을 나누므로 이 메뉴를 안 눌러도 똑같이 돌아간다.
    /// Sprite Editor 로 칸 · Pivot(발 바닥)을 눈으로 확인하고 싶을 때 쓴다.
    /// </summary>
    public static class ArcaSheetSlicer
    {
        [MenuItem("Arca/6칸 그림을 Sprite Editor 칸으로 나누기 (선택)")]
        static void SliceAll()
        {
            var factory = new SpriteDataProviderFactories();
            factory.Init();
            int done = 0;
            foreach (var guid in AssetDatabase.FindAssets("t:Texture2D", new[] { "Assets/Resources/Art/Hero", "Assets/Resources/Art/Ally" }))
            {
                var path = AssetDatabase.GUIDToAssetPath(guid);
                var file = Path.GetFileNameWithoutExtension(path);
                if (!file.Contains("_attack")) continue;
                var ti = AssetImporter.GetAtPath(path) as TextureImporter;
                if (ti == null) continue;

                ti.GetSourceTextureWidthAndHeight(out int w, out int h);
                bool ally = path.Contains("/Ally/");
                float foot = ally ? ArtSpec.AllyFoot / ArtSpec.AllyCanvas : ArtSpec.HeroAttackFoot / ArtSpec.HeroAttackCanvas;

                ti.spriteImportMode = SpriteImportMode.Multiple;
                var dp = factory.GetSpriteEditorDataProviderFromObject(ti);
                dp.InitSpriteEditorDataProvider();
                var rects = new List<SpriteRect>();
                float fw = w / 6f;
                for (int i = 0; i < 6; i++)
                {
                    rects.Add(new SpriteRect
                    {
                        name = file + "_" + (i + 1),
                        rect = new Rect(Mathf.Round(i * fw), 0, Mathf.Round(fw), h),
                        alignment = SpriteAlignment.Custom,
                        pivot = new Vector2(0.5f, 1f - foot),
                        spriteID = GUID.Generate()
                    });
                }
                dp.SetSpriteRects(rects.ToArray());
                dp.Apply();
                ti.SaveAndReimport();
                done++;
            }
            Debug.Log($"[Arca] 6칸 그림 {done}장을 칸으로 나눴습니다 (칸 너비 = 그림 너비 ÷ 6, Pivot = 발 바닥)");
        }
    }
}
#endif
