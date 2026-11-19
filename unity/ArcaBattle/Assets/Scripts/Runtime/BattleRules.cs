using System.Collections.Generic;
using UnityEngine;

namespace Arca.Battle
{
    public enum GuardOutcome { None, Blocked, Broken }

    public struct HitResult
    {
        public bool valid;
        public int damage;
        public bool crit;
        public bool strike;
        public bool killed;
    }

    public struct CounterResult
    {
        public bool valid;
        /// <summary>-1 = 주인공, 0 이상 = 동료 번호</summary>
        public int target;
        public int damage;
        public bool heavy;
        public GuardOutcome guard;
        public bool targetDown;
    }

    public class Fighter
    {
        public string name;
        public int maxHp;
        public int hp;
        public int attack;
        public bool Alive => hp > 0;
        public float Ratio => maxHp <= 0 ? 0f : Mathf.Clamp01(hp / (float)maxHp);
        public void Hurt(int d) { hp = Mathf.Max(0, hp - Mathf.Max(0, d)); }
    }

    public class AllyState : Fighter
    {
        public AllyDef def;
        public int cooldown;
        public bool SkillReady => Alive && cooldown <= 0;
    }

    public class MonsterState : Fighter
    {
        public MonsterDef def;
        public int counters;
        /// <summary>다음 반격이 강한 공격인지 (방어 태세가 깨짐)</summary>
        public bool NextIsHeavy => def.heavyEvery > 0 && (counters + 1) % def.heavyEvery == 0;
    }

    /// <summary>
    /// 전투 규칙 (화면과 떨어진 순수 계산).
    /// 1틱: 주인공이 먼저 공격 → 몬스터가 남아 있으면 반격. 동료는 자동 공격, 스킬은 버튼.
    /// </summary>
    public class BattleRules
    {
        public const int PetGaugeMax = 100;
        /// <summary>몬스터가 주인공 대신 동료를 노릴 확률</summary>
        public const float AllyTargetChance = 0.25f;

        public readonly BattleConfig cfg;
        readonly System.Random rng;

        public readonly Fighter hero;
        public readonly List<AllyState> allies = new List<AllyState>();
        public MonsterState monster;
        public int monsterIndex;

        public int strikeCooldown, guardCooldown;
        public bool strikeArmed, guardArmed;
        public int petGauge;
        public int tick;

        public int MonsterCount => cfg.monsters.Count;
        public bool AllMonstersDown => monsterIndex >= cfg.monsters.Count - 1 && (monster == null || !monster.Alive);
        public bool PetReady => petGauge >= PetGaugeMax;

        public BattleRules(BattleConfig cfg, string[] party, int seed)
        {
            this.cfg = cfg;
            rng = new System.Random(seed);
            hero = new Fighter { name = cfg.heroName, maxHp = cfg.heroMaxHp, hp = cfg.heroMaxHp, attack = cfg.heroAttack };
            foreach (var id in party)
            {
                var def = cfg.FindAlly(id);
                if (def == null) continue;
                allies.Add(new AllyState { def = def, name = def.displayName, maxHp = def.maxHp, hp = def.maxHp, attack = def.attack });
                if (allies.Count == 2) break;
            }
            monsterIndex = 0;
            SpawnMonster();
        }

        void SpawnMonster()
        {
            var d = cfg.monsters[monsterIndex];
            monster = new MonsterState { def = d, name = d.displayName, maxHp = d.maxHp, hp = d.maxHp, attack = d.attack };
        }

        /// <summary>다음 몬스터로. 더 없으면 false (= 승리)</summary>
        public bool AdvanceMonster()
        {
            if (monsterIndex + 1 >= cfg.monsters.Count) return false;
            monsterIndex++;
            SpawnMonster();
            return true;
        }

        int Roll(int atk, float mult, bool canCrit, out bool crit)
        {
            float jitter = 1f + (float)(rng.NextDouble() * 2.0 - 1.0) * cfg.damageJitter;
            crit = canCrit && rng.NextDouble() < cfg.critChance;
            float d = atk * mult * jitter;
            if (crit) d *= cfg.critMultiplier;
            return Mathf.Max(1, Mathf.RoundToInt(d));
        }

        HitResult HitMonster(int atk, float mult, bool canCrit, bool forceCrit = false)
        {
            var r = new HitResult();
            if (monster == null || !monster.Alive) return r;
            r.valid = true;
            r.damage = Roll(atk, mult, canCrit, out r.crit);
            if (forceCrit && !r.crit) { r.crit = true; r.damage = Mathf.RoundToInt(r.damage * cfg.critMultiplier); }
            monster.Hurt(r.damage);
            r.killed = !monster.Alive;
            return r;
        }

        // ---------- 주인공 ----------
        public HitResult HeroAttack()
        {
            if (!hero.Alive) return new HitResult();
            bool strike = strikeArmed && monster != null && monster.Alive;
            var r = HitMonster(hero.attack, strike ? cfg.strikeMultiplier : 1f, true);
            if (r.valid && strike)
            {
                strikeArmed = false;
                strikeCooldown = cfg.strikeCooldownTicks;
                r.strike = true;
            }
            return r;
        }

        public bool TryArmStrike()
        {
            if (strikeArmed || strikeCooldown > 0 || !hero.Alive) return false;
            strikeArmed = true;
            return true;
        }

        public bool TryArmGuard()
        {
            if (guardArmed || guardCooldown > 0 || !hero.Alive) return false;
            guardArmed = true;
            return true;
        }

        // ---------- 동료 ----------
        public bool TryStartAllySkill(int i)
        {
            if (i < 0 || i >= allies.Count || !allies[i].SkillReady) return false;
            allies[i].cooldown = allies[i].def.skillCooldownTicks;
            return true;
        }

        public HitResult AllyAttack(int i, bool skill)
        {
            if (i < 0 || i >= allies.Count || !allies[i].Alive) return new HitResult();
            var a = allies[i];
            return HitMonster(a.attack, skill ? a.def.skillMultiplier : 1f, true);
        }

        // ---------- 펫 ----------
        public bool TryUsePet()
        {
            if (!PetReady || monster == null || !monster.Alive) return false;
            petGauge = 0;
            return true;
        }

        public HitResult PetHit() => HitMonster(cfg.petSkillPower, 1f, false);

        // ---------- 몬스터 반격 ----------
        public CounterResult MonsterCounter()
        {
            var c = new CounterResult();
            if (monster == null || !monster.Alive || !hero.Alive) return c;
            c.valid = true;
            c.heavy = monster.NextIsHeavy;
            monster.counters++;

            // 방어 태세 중이면 반드시 주인공을 노린다
            c.target = -1;
            if (!guardArmed && rng.NextDouble() < AllyTargetChance)
            {
                var alive = new List<int>();
                for (int i = 0; i < allies.Count; i++) if (allies[i].Alive) alive.Add(i);
                if (alive.Count > 0) c.target = alive[rng.Next(alive.Count)];
            }

            int dmg = Roll(monster.attack, c.heavy ? monster.def.heavyMultiplier : 1f, false, out _);
            if (c.target < 0)
            {
                if (guardArmed)
                {
                    guardArmed = false;
                    guardCooldown = cfg.guardCooldownTicks;
                    if (c.heavy) { c.guard = GuardOutcome.Broken; dmg = Mathf.RoundToInt(dmg * cfg.guardBreakDamageRate); }
                    else { c.guard = GuardOutcome.Blocked; dmg = 0; }
                }
                hero.Hurt(dmg);
                if (dmg > 0) petGauge = Mathf.Min(PetGaugeMax, petGauge + cfg.petGaugePerHurt);
                c.targetDown = !hero.Alive;
            }
            else
            {
                allies[c.target].Hurt(dmg);
                c.targetDown = !allies[c.target].Alive;
            }
            c.damage = dmg;
            return c;
        }

        /// <summary>틱 끝: 쿨타임 줄이기, 펫 게이지 채우기</summary>
        public void EndTick()
        {
            tick++;
            if (!strikeArmed && strikeCooldown > 0) strikeCooldown--;
            if (!guardArmed && guardCooldown > 0) guardCooldown--;
            foreach (var a in allies) if (a.cooldown > 0) a.cooldown--;
            if (monster != null && monster.Alive) petGauge = Mathf.Min(PetGaugeMax, petGauge + cfg.petGaugePerTick);
        }
    }
}
