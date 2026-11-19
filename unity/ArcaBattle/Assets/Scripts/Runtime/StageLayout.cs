using UnityEngine;

namespace Arca.Battle
{
    /// <summary>
    /// 무대 배치 · 움직임 수치. Assets/Resources/ArcaStageLayout.asset 을 고치면 된다.
    /// 재생 중에 고쳐도 바로 화면에 반영된다 (배치 · 숨쉬기 · 살랑임).
    ///
    /// 자리 값 읽는 법: x 는 무대 너비 비율 (가운데 0, 왼쪽 끝 -0.5, 오른쪽 끝 +0.5),
    /// y(발 바닥) 는 무대 높이 비율 (아래 끝 0, 위 끝 1), 키는 무대 높이 비율.
    /// 그림의 「키」는 그림 칸 전체 높이 (캐릭터 몸은 그보다 조금 작다).
    /// </summary>
    [CreateAssetMenu(menuName = "Arca/Stage Layout", fileName = "ArcaStageLayout")]
    public class StageLayout : ScriptableObject
    {
        [Header("화면 나누기")]
        [Range(0.4f, 0.8f)] public float stageScreenFraction = 0.6f;

        [Header("주인공 (앞, 몬스터 쪽)")]
        public float heroX = 0.05f;
        public float heroFootY = 0.075f;
        [Tooltip("서기 그림(768×1024) 칸 높이. 공격 6칸 그림도 같은 칸 높이로 맞춘다")]
        public float heroHeight = 0.5f;

        [Header("동료 둘 (뒷줄, 계단처럼)")]
        public Vector2 allyBack = new Vector2(-0.375f, 0.225f);
        public Vector2 allyFront = new Vector2(-0.20f, 0.15f);
        [Tooltip("동료 그림(640×640 한 칸) 칸 높이")]
        public float allyHeight = 0.36f;

        [Header("몬스터 (오른쪽)")]
        public float monsterX = 0.335f;
        public float monsterFootY = 0.10f;
        public float monsterHeightNormal = 0.34f;
        public float monsterHeightBoss = 0.42f;

        [Header("펫 (주인공 발 앞쪽 아래)")]
        public float petOffsetX = 0.24f;
        public float petFootY = 0.015f;
        public float petHeight = 0.13f;

        [Header("정령 (왼쪽 아래 구석)")]
        public float spiritX = -0.42f;
        public float spiritFootY = 0.01f;
        public float spiritHeight = 0.12f;
        [Tooltip("응원 말풍선 가운데 (정령 가운데 기준, 무대 너비 · 높이 비율)")]
        public Vector2 bubbleOffset = new Vector2(0.19f, 0.04f);

        [Header("숨쉬기 (발 바닥 기준 세로로 오르내림)")]
        public float breathAmount = 0.015f;
        public float breathPeriod = 2.6f;
        [Tooltip("캐릭터마다 박자를 조금씩 다르게 (±비율)")]
        public float breathPeriodJitter = 0.18f;

        [Header("공격 6칸 (2→6칸 재생 후 1칸으로). 2배 속도면 절반")]
        public float[] attackFrameSeconds = { 0.10f, 0.08f, 0.16f, 0.10f, 0.12f };
        [Tooltip("피해가 들어가는 칸 (1~6)")]
        public int hitFrame = 4;
        public float hitStopSeconds = 0.05f;
        [Tooltip("공격할 때 앞으로 내딛는 거리 (무대 너비 비율)")]
        public float attackStep = 0.03f;

        [Header("맞을 때")]
        public float monsterShake = 0.12f;
        public float monsterShakeSeconds = 0.28f;
        public float flashSeconds = 0.22f;

        [Header("몬스터 반격")]
        public float counterLunge = 0.07f;
        public float counterSeconds = 0.32f;

        [Header("승리")]
        public float victoryHop = 0.04f;

        [Header("머리카락 · 망토 살랑임 (셰이더 시험)")]
        public bool swayEnabled = false;
        [Tooltip("흔들리는 폭 (그림 px)")]
        public float swayPixels = 3f;
        public float swaySpeed = 3.2f;
        public float swayWaves = 9f;
        [Tooltip("몸의 이 높이(0 발 ~ 1 머리 위)부터 위쪽만 흔들림")]
        [Range(0f, 1f)] public float swayStart = 0.45f;
    }
}
