using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
#if ARCA_URP
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
#endif

namespace Arca.Battle.EditorTools
{
    /// <summary>
    /// 프로젝트를 처음 열면 스스로 하는 일 (한 번 해 두면 다음부터는 건너뜀):
    /// 1) URP 2D 렌더러 만들고 켜기  2) 세로 화면 · 2D 모드
    /// 3) 전투 장면(Assets/Scenes/ArcaBattle.unity) 만들고 열기, Play 를 누르면 항상 이 장면에서 시작
    /// 메뉴 Arca ▸ 처음 설정 다시 하기 로 다시 돌릴 수 있다.
    /// </summary>
    [InitializeOnLoad]
    public static class ArcaProjectSetup
    {
        public const string ScenePath = "Assets/Scenes/ArcaBattle.unity";
        const string SettingsDir = "Assets/Settings";

        static ArcaProjectSetup()
        {
            EditorApplication.delayCall += Run;
        }

        [MenuItem("Arca/처음 설정 다시 하기")]
        static void RunFromMenu() => Run();

        [MenuItem("Arca/전투 장면 열기")]
        static void OpenBattleScene()
        {
            if (File.Exists(ScenePath) && EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())
                EditorSceneManager.OpenScene(ScenePath);
        }

        static void Run()
        {
            if (EditorApplication.isPlayingOrWillChangePlaymode) return;
            if (EditorApplication.isCompiling || EditorApplication.isUpdating)
            {
                EditorApplication.delayCall += Run;
                return;
            }

            if (PlayerSettings.defaultInterfaceOrientation != UIOrientation.Portrait)
                PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
            if (PlayerSettings.productName != "ArcaBattle") PlayerSettings.productName = "ArcaBattle";
            if (EditorSettings.defaultBehaviorMode != EditorBehaviorMode.Mode2D)
                EditorSettings.defaultBehaviorMode = EditorBehaviorMode.Mode2D;

            EnsureUrp2D();
            EnsureScene();
        }

        static void EnsureUrp2D()
        {
#if ARCA_URP
            if (GraphicsSettings.defaultRenderPipeline is UniversalRenderPipelineAsset) return;
            if (!AssetDatabase.IsValidFolder(SettingsDir)) AssetDatabase.CreateFolder("Assets", "Settings");

            var urp = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(SettingsDir + "/ArcaURP.asset");
            if (urp == null)
            {
                var data = ScriptableObject.CreateInstance<Renderer2DData>();
                AssetDatabase.CreateAsset(data, SettingsDir + "/ArcaURP_2DRenderer.asset");
                urp = UniversalRenderPipelineAsset.Create(data);
                AssetDatabase.CreateAsset(urp, SettingsDir + "/ArcaURP.asset");
                AssetDatabase.SaveAssets();
            }

            GraphicsSettings.defaultRenderPipeline = urp;
            int current = QualitySettings.GetQualityLevel();
            for (int i = 0; i < QualitySettings.names.Length; i++)
            {
                QualitySettings.SetQualityLevel(i, false);
                QualitySettings.renderPipeline = urp;
            }
            QualitySettings.SetQualityLevel(current, false);
            AssetDatabase.SaveAssets();
            Debug.Log("[Arca] URP 2D 렌더러를 만들고 켰습니다 (Assets/Settings/ArcaURP.asset)");
#else
            Debug.LogWarning("[Arca] URP 패키지를 찾지 못해 기본 렌더러로 그립니다. Package Manager 에서 Universal RP 를 확인해 주세요.");
#endif
        }

        static void EnsureScene()
        {
            if (!File.Exists(ScenePath))
            {
                var active = SceneManager.GetActiveScene();
                // 사용자가 손대던 장면이 있으면 덮어쓰지 않음
                if (active.isDirty && !string.IsNullOrEmpty(active.path)) return;

                var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
                var camGo = new GameObject("Main Camera") { tag = "MainCamera" };
                var cam = camGo.AddComponent<Camera>();
                cam.orthographic = true;
                cam.orthographicSize = 5f;
                cam.clearFlags = CameraClearFlags.SolidColor;
                cam.backgroundColor = new Color(0.078f, 0.075f, 0.169f);
                camGo.transform.position = new Vector3(0f, 0f, -10f);

                var go = new GameObject("ArcaBattle");
                var d = go.AddComponent<BattleDirector>();
                d.config = AssetDatabase.LoadAssetAtPath<BattleConfig>("Assets/Resources/ArcaBattleConfig.asset");
                d.layout = AssetDatabase.LoadAssetAtPath<StageLayout>("Assets/Resources/ArcaStageLayout.asset");

                if (!AssetDatabase.IsValidFolder("Assets/Scenes")) AssetDatabase.CreateFolder("Assets", "Scenes");
                EditorSceneManager.SaveScene(scene, ScenePath);
                Debug.Log("[Arca] 전투 장면을 만들었습니다: " + ScenePath);
            }

            if (!EditorBuildSettings.scenes.Any(s => s.path == ScenePath))
            {
                var list = EditorBuildSettings.scenes.ToList();
                list.Insert(0, new EditorBuildSettingsScene(ScenePath, true));
                EditorBuildSettings.scenes = list.ToArray();
            }

            // Play 를 누르면 지금 열린 장면과 상관없이 전투 장면에서 시작
            EditorSceneManager.playModeStartScene = AssetDatabase.LoadAssetAtPath<SceneAsset>(ScenePath);

            var now = SceneManager.GetActiveScene();
            if (string.IsNullOrEmpty(now.path) && !now.isDirty)
                EditorSceneManager.OpenScene(ScenePath);
        }
    }
}
