using System;
using System.Collections.Generic;
using UnityEngine;

namespace Arca.Battle
{
    /// <summary>속성 (효과 그림 fx_hit_&lt;속성&gt; 을 고르는 데 씀)</summary>
    public enum ElementKind { None, Fire, Water, Wind, Earth, Light, Dark, Ice, Thunder, Poison, Metal }

    public enum HeroGender { Male, Female }

    /// <summary>주인공 직업. None = 맨손(기본 주인공 그림)</summary>
    public enum HeroJob { None, Warrior, Archer, Mage, Priest, Rogue, Knight }

    public enum MonsterGrade { Normal, Boss }

    [Serializable]
    public class AllyDef
    {
        public string id = "lian";
        public string displayName = "리안";
        public int maxHp = 1200;
        public int attack = 90;
        public string skillName = "혼자가 아닌 검";
        public float skillMultiplier = 2.6f;
        public int skillCooldownTicks = 6;
        public ElementKind element = ElementKind.None;
    }

    [Serializable]
    public class MonsterDef
    {
        public string id = "slime";
        public string displayName = "슬라임";
        [Tooltip("Resources/Art/Monster/ 안의 그림 이름")]
        public string sprite = "monster_slime";
        public int maxHp = 700;
        public int attack = 60;
        public MonsterGrade grade = MonsterGrade.Normal;
        [Tooltip("몇 번째 반격마다 강한 공격을 하는지 (0 = 안 함). 방어 태세로 막지 못하고 깨진다")]
        public int heavyEvery = 0;
        public float heavyMultiplier = 1.8f;
        [Tooltip("그림의 발 바닥 위치 (위에서부터 px, 그림 높이 기준)")]
        public float footY = 487f;
    }

    /// <summary>
    /// 전투 수치. Assets/Resources/ArcaBattleConfig.asset 을 에디터에서 고치면 된다.
    /// (재생 중에 고친 값은 다음 「다시 하기」 때 적용)
    /// </summary>
    [CreateAssetMenu(menuName = "Arca/Battle Config", fileName = "ArcaBattleConfig")]
    public class BattleConfig : ScriptableObject
    {
        [Header("틱 (1틱 = 주인공 공격 → 몬스터 반격)")]
        public float tickSeconds = 1f;

        [Header("주인공")]
        public string heroName = "각성자";
        public int heroMaxHp = 2400;
        public int heroAttack = 200;
        [Range(0f, 1f)] public float critChance = 0.15f;
        public float critMultiplier = 1.6f;
        [Tooltip("피해 흔들림 ±비율 (0.1 = ±10%)")]
        [Range(0f, 0.5f)] public float damageJitter = 0.10f;

        [Header("강타: 다음 공격이 크게")]
        public float strikeMultiplier = 2.2f;
        public int strikeCooldownTicks = 5;

        [Header("방어 태세: 다음 반격 막기")]
        public int guardCooldownTicks = 4;
        [Tooltip("강한 공격에 깨졌을 때 받는 피해 비율")]
        public float guardBreakDamageRate = 0.6f;

        [Header("펫")]
        public string petId = "owl";
        public string petName = "부엉이";
        public int petGaugePerTick = 20;
        public int petGaugePerHurt = 8;
        public int petSkillPower = 380;
        public ElementKind petElement = ElementKind.Wind;

        [Header("정령")]
        public string spiritId = "plant";
        public string cheerText = "할 수 있어!";

        [Header("모습 (재생 중 ⚙ 버튼으로도 바꿀 수 있음)")]
        public HeroGender heroGender = HeroGender.Male;
        public HeroJob heroJob = HeroJob.None;
        [Tooltip("Resources/Art/Bg/ 안의 그림 이름")]
        public string background = "bg_field_forest";

        [Header("동료 (이야기 동료 7명 중 둘을 데려감)")]
        public string[] party = { "lian", "barkan" };
        public List<AllyDef> allies = new List<AllyDef>();

        [Header("몬스터 (순서대로 나옴)")]
        public List<MonsterDef> monsters = new List<MonsterDef>();

        public AllyDef FindAlly(string id)
        {
            foreach (var a in allies)
                if (a != null && a.id == id) return a;
            return null;
        }

        /// <summary>에셋이 없거나 비었을 때 쓰는 기본 시험 수치</summary>
        public void FillDefaultsIfEmpty()
        {
            if (allies == null) allies = new List<AllyDef>();
            if (allies.Count == 0)
            {
                allies.Add(new AllyDef { id = "lian", displayName = "리안", maxHp = 1200, attack = 90, skillName = "혼자가 아닌 검", skillMultiplier = 2.6f, skillCooldownTicks = 6 });
                allies.Add(new AllyDef { id = "garen", displayName = "가렌", maxHp = 1500, attack = 80, skillName = "지팡이 후려치기", skillMultiplier = 2.4f, skillCooldownTicks = 6, element = ElementKind.Metal });
                allies.Add(new AllyDef { id = "nia", displayName = "니아", maxHp = 1000, attack = 95, skillName = "그림자 급소", skillMultiplier = 3.2f, skillCooldownTicks = 7, element = ElementKind.Dark });
                allies.Add(new AllyDef { id = "barkan", displayName = "바르칸", maxHp = 1600, attack = 85, skillName = "불 숨결", skillMultiplier = 2.4f, skillCooldownTicks = 6, element = ElementKind.Fire });
                allies.Add(new AllyDef { id = "popo", displayName = "포포", maxHp = 900, attack = 70, skillName = "덩굴 묶기", skillMultiplier = 2.0f, skillCooldownTicks = 5, element = ElementKind.Earth });
                allies.Add(new AllyDef { id = "sera", displayName = "세라", maxHp = 1700, attack = 75, skillName = "방패 밀치기", skillMultiplier = 1.8f, skillCooldownTicks = 5, element = ElementKind.Metal });
                allies.Add(new AllyDef { id = "teo", displayName = "테오", maxHp = 1400, attack = 90, skillName = "빛의 창", skillMultiplier = 2.8f, skillCooldownTicks = 6, element = ElementKind.Light });
            }
            if (monsters == null) monsters = new List<MonsterDef>();
            if (monsters.Count == 0)
            {
                monsters.Add(new MonsterDef { id = "slime", displayName = "슬라임", sprite = "monster_slime", maxHp = 700, attack = 60, grade = MonsterGrade.Normal, heavyEvery = 0, footY = 472f });
                monsters.Add(new MonsterDef { id = "goblinRaider", displayName = "고블린 약탈자", sprite = "monster_goblinRaider", maxHp = 2192, attack = 120, grade = MonsterGrade.Boss, heavyEvery = 3, heavyMultiplier = 1.8f, footY = 487f });
            }
            if (party == null || party.Length < 2) party = new[] { "lian", "barkan" };
        }
    }
}
