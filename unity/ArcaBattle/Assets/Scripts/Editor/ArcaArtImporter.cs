using UnityEditor;
using UnityEngine;

namespace Arca.Battle.EditorTools
{
    /// <summary>
    /// 그림 가져오기 설정을 자동으로 맞춘다 (Assets/Resources/Art 아래 그림만).
    /// - Sprite 로, 최대 크기 4096 (6칸 그림은 가로 3840 이라 기본값 2048 이면 흐려짐)
    /// - 밉맵 끔 (2D 에서는 필요 없음, 흐려짐 방지)
    /// - 고화질 압축, 투명 가장자리 번짐 방지
    /// </summary>
    public class ArcaArtImporter : AssetPostprocessor
    {
        void OnPreprocessTexture()
        {
            if (!assetPath.StartsWith("Assets/Resources/Art/")) return;
            var ti = (TextureImporter)assetImporter;
            ti.textureType = TextureImporterType.Sprite;
            if (ti.spriteImportMode == SpriteImportMode.None) ti.spriteImportMode = SpriteImportMode.Single;
            ti.mipmapEnabled = false;
            ti.alphaIsTransparency = true;
            ti.maxTextureSize = 4096;
            ti.textureCompression = TextureImporterCompression.CompressedHQ;
            ti.filterMode = FilterMode.Bilinear;
            ti.wrapMode = TextureWrapMode.Clamp;
            ti.npotScale = TextureImporterNPOTScale.None;
            ti.spritePixelsPerUnit = 100f;
        }
    }
}
