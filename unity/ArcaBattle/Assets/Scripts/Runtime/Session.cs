using UnityEngine;

namespace Arca.Battle
{
    /// <summary>
    /// 이번 재생 동안 고른 것 (주인공 성별 · 직업, 동료 둘, 배경, 펫, 살랑임).
    /// 처음에는 BattleConfig / StageLayout 값으로 시작하고, ⚙ 「모습 바꾸기」 로 바꾼다.
    /// </summary>
    public static class Session
    {
        public static bool initialized;
        public static HeroGender gender;
        public static HeroJob job;
        public static string[] party = { "lian", "barkan" };
        public static string background = "bg_field_forest";
        public static string petId = "owl";
        public static string spiritId = "plant";
        public static bool sway;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
        static void ResetStatics() { initialized = false; }

        public static void InitFrom(BattleConfig c, StageLayout l)
        {
            if (initialized) return;
            initialized = true;
            gender = c.heroGender;
            job = c.heroJob;
            party = new[] { c.party[0], c.party[1] };
            background = c.background;
            petId = c.petId;
            spiritId = c.spiritId;
            sway = l.swayEnabled;
        }

        static string G => gender == HeroGender.Male ? "male" : "female";
        static string J => job.ToString().ToLowerInvariant();

        public static string HeroIdlePath => job == HeroJob.None ? $"Hero/hero_idle_{G}" : $"Hero/hero_{J}_{G}";
        public static string HeroAttackPath => job == HeroJob.None ? $"Hero/hero_attack_{G}" : $"Hero/hero_{J}_attack_{G}";
        // 승리 · 쓰러짐은 직업별 그림이 아직 없어 기본 주인공 그림을 씀
        public static string HeroVictoryPath => $"Hero/hero_victory_{G}";
        public static string HeroTiredPath => $"Hero/hero_tired_{G}";

        public static string JobName(HeroJob j)
        {
            switch (j)
            {
                case HeroJob.Warrior: return "전사";
                case HeroJob.Archer: return "궁수";
                case HeroJob.Mage: return "마법사";
                case HeroJob.Priest: return "사제";
                case HeroJob.Rogue: return "도적";
                case HeroJob.Knight: return "기사";
                default: return "맨손";
            }
        }
    }

    /// <summary>그림 크기 · 발 바닥 위치 (원래 그림 px 기준)</summary>
    public static class ArtSpec
    {
        public const float HeroCanvas = 1024f, HeroFoot = 1004f;           // 서기 · 승리 · 쓰러짐 768×1024
        public const float HeroAttackCanvas = 800f, HeroAttackFoot = 780f; // 공격 640×800 × 6칸
        public const float AllyCanvas = 640f, AllyFoot = 620f;             // 동료 640×640 × 6칸
        public const float PetCanvas = 512f, PetFoot = 496f;               // 펫 512
        public const float SpiritFoot = 491f;                              // 정령 512

        public static string ElementFx(ElementKind e)
        {
            if (e == ElementKind.None) return "Fx/fx_hit";
            return "Fx/fx_hit_" + e.ToString().ToLowerInvariant();
        }

        public static Color ElementColor(ElementKind e)
        {
            switch (e)
            {
                case ElementKind.Fire: return UiKit.Hex("#FF8A4C");
                case ElementKind.Water: return UiKit.Hex("#5FB8FF");
                case ElementKind.Wind: return UiKit.Hex("#8FE3B0");
                case ElementKind.Earth: return UiKit.Hex("#C9A46A");
                case ElementKind.Light: return UiKit.Hex("#FFE58A");
                case ElementKind.Dark: return UiKit.Hex("#B48CFF");
                case ElementKind.Ice: return UiKit.Hex("#B8ECFF");
                case ElementKind.Thunder: return UiKit.Hex("#FFE14D");
                case ElementKind.Poison: return UiKit.Hex("#A6E05A");
                case ElementKind.Metal: return UiKit.Hex("#D8DDE6");
                default: return Color.white;
            }
        }
    }
}
