using System.Collections;
using System.Globalization;
using UnityEngine;

namespace Arca.Battle
{
    /// <summary>
    /// 전투 화면 전체 진행: 카메라 · 무대 배치 · 틱 진행 · 연출 · 버튼 처리.
    /// 장면에 이 컴포넌트가 없으면 Play 할 때 저절로 만들어진다 (AutoStart).
    /// </summary>
    public class BattleDirector : MonoBehaviour
    {
        public BattleConfig config;
        public StageLayout layout;

        public enum Phase { Intro, Fight, Victory, Defeat }

        public const float StageH = 10f;
        public float StageW { get; private set; } = 7.7f;
        public float Speed { get; private set; } = 1f;
        public Phase CurrentPhase { get; private set; }
        public bool Transitioning { get; private set; }
        public BattleRules Rules { get; private set; }
        public BattleHud Hud { get; private set; }
        public Camera Cam { get; private set; }

        public Actor hero, monster, pet, spirit;
        public Actor[] allies = new Actor[0];

        Transform stage;
        SpriteRenderer bg, fade, guardShield;
        FxPlayer fx;
        Sprite heroIdle, heroVictory, heroTired;
        Sprite[] heroAttack;
        readonly Vector3 camBase = new Vector3(0f, 0f, -10f);
        float shakeTime, shakeDuration, shakeAmount;
        bool lastLayoutSway;
        int buildId;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        static void AutoStart()
        {
            if (FindAnyObjectByType<BattleDirector>() == null)
                new GameObject("ArcaBattle").AddComponent<BattleDirector>();
        }

        void Awake()
        {
            if (config == null) config = Resources.Load<BattleConfig>("ArcaBattleConfig");
            if (config == null) config = ScriptableObject.CreateInstance<BattleConfig>();
            config.FillDefaultsIfEmpty();
            if (layout == null) layout = Resources.Load<StageLayout>("ArcaStageLayout");
            if (layout == null) layout = ScriptableObject.CreateInstance<StageLayout>();

            Application.targetFrameRate = 60;
            Time.timeScale = 1f;
            Session.InitFrom(config, layout);
            lastLayoutSway = layout.swayEnabled;
            UiKit.EnsureEventSystem();
            SetupCamera();
        }

        void Start() { Build(); }

        void SetupCamera()
        {
            Cam = Camera.main;
            if (Cam == null)
            {
                var go = new GameObject("Main Camera") { tag = "MainCamera" };
                Cam = go.AddComponent<Camera>();
            }
            Cam.orthographic = true;
            Cam.orthographicSize = StageH * 0.5f;
            Cam.transform.position = camBase;
            Cam.transform.rotation = Quaternion.identity;
            Cam.clearFlags = CameraClearFlags.SolidColor;
            Cam.backgroundColor = UiKit.Night;
            Cam.nearClipPlane = 0.1f;
            Cam.farClipPlane = 100f;
        }

        // ================= 만들기 · 다시 하기 =================

        void Build()
        {
            buildId++;
            Speed = Mathf.Max(1f, Speed);
            Rules = new BattleRules(config, Session.party, System.Environment.TickCount);
            CurrentPhase = Phase.Intro;
            Transitioning = false;

            stage = new GameObject("Stage").transform;
            var fxGo = new GameObject("Fx");
            fxGo.transform.SetParent(stage, false);
            fx = fxGo.AddComponent<FxPlayer>();

            bg = NewRenderer("Background", -100, ArtLibrary.Single("Bg/" + Session.background));
            fade = NewRenderer("BottomFade", -90, UiKit.VerticalFade(new Color(0.043f, 0.051f, 0.149f, 0.67f), 0.45f));

            // 동료 (뒷줄 · 계단): 0 = 맨 뒤(위), 1 = 그 앞
            allies = new Actor[Rules.allies.Count];
            for (int i = 0; i < allies.Length; i++)
            {
                var st = Rules.allies[i];
                var a = Actor.Create("Ally_" + st.def.id, stage, i == 0 ? 10 : 12, layout, 0.42f);
                a.frames = ArtLibrary.Sheet("Ally/ally_" + st.def.id + "_attack", 6, ArtSpec.AllyFoot / ArtSpec.AllyCanvas);
                a.SetIdle(a.frames != null ? a.frames[0] : null);
                allies[i] = a;
            }

            monster = Actor.Create("Monster", stage, 14, layout, 0.68f);
            monster.canSway = false;
            SetMonsterSprite();

            hero = Actor.Create("Hero", stage, 16, layout, 0.42f);
            LoadHeroSprites();

            pet = Actor.Create("Pet", stage, 18, layout, 0.55f);
            pet.canSway = false;
            pet.SetIdle(ArtLibrary.Single("Pet/pet_" + Session.petId + "_battle", ArtSpec.PetFoot / ArtSpec.PetCanvas));

            spirit = Actor.Create("Spirit", stage, 19, layout, 0.38f);
            spirit.canSway = false;
            spirit.SetIdle(ArtLibrary.Single("Pet/spirit_" + Session.spiritId + "_battle", ArtSpec.SpiritFoot / ArtSpec.PetCanvas));

            guardShield = NewRenderer("GuardShield", 24, ArtLibrary.Single("Fx/fx_guard"));
            guardShield.enabled = false;

            UpdateLayout();
            Hud = BattleHud.Create(this);
            StartCoroutine(Run(buildId));
        }

        void LoadHeroSprites()
        {
            heroIdle = ArtLibrary.Single(Session.HeroIdlePath, ArtSpec.HeroFoot / ArtSpec.HeroCanvas);
            heroVictory = ArtLibrary.Single(Session.HeroVictoryPath, ArtSpec.HeroFoot / ArtSpec.HeroCanvas);
            heroTired = ArtLibrary.Single(Session.HeroTiredPath, ArtSpec.HeroFoot / ArtSpec.HeroCanvas);
            heroAttack = ArtLibrary.Sheet(Session.HeroAttackPath, 6, ArtSpec.HeroAttackFoot / ArtSpec.HeroAttackCanvas);
            hero.frames = heroAttack;
            hero.SetIdle(heroIdle);
        }

        void SetMonsterSprite()
        {
            var def = Rules.monster.def;
            var path = "Monster/" + def.sprite;
            var tex = ArtLibrary.Tex(path);
            float foot = tex != null ? def.footY / tex.height : 0.95f;
            monster.SetIdle(ArtLibrary.Single(path, foot));
            monster.alpha = 1f;
        }

        SpriteRenderer NewRenderer(string name, int order, Sprite sprite)
        {
            var go = new GameObject(name);
            go.transform.SetParent(stage, false);
            var sr = go.AddComponent<SpriteRenderer>();
            sr.sharedMaterial = Actor.SharedMaterial;
            sr.sortingOrder = order;
            sr.sprite = sprite;
            return sr;
        }

        public void Restart()
        {
            StopAllCoroutines();
            HitStop.Request(0f);
            Time.timeScale = 1f;
            if (stage != null) Destroy(stage.gameObject);
            if (Hud != null) Destroy(Hud.gameObject);
            Cam.transform.position = camBase;
            Build();
        }

        // ================= 배치 (매 프레임) =================

        Vector2 P(float xFrac, float footFrac) => new Vector2(xFrac * StageW, -StageH * 0.5f + footFrac * StageH);

        void UpdateLayout()
        {
            float f = Mathf.Clamp(layout.stageScreenFraction, 0.2f, 1f);
            Cam.rect = new Rect(0f, 1f - f, 1f, f);
            Cam.orthographicSize = StageH * 0.5f;
            float aspect = Screen.width / Mathf.Max(1f, Screen.height * f);
            StageW = StageH * aspect;

            if (bg != null && bg.sprite != null)
            {
                float w = bg.sprite.rect.width / bg.sprite.rect.height; // 스프라이트는 높이 1 유닛
                float scale = Mathf.Max(StageH, StageW / w) * 1.04f;      // 꽉 채워 자르기 (+흔들림 여유)
                bg.transform.localScale = new Vector3(scale, scale, 1f);
            }
            if (fade != null && fade.sprite != null)
            {
                float sw = fade.sprite.rect.width / fade.sprite.rect.height;
                fade.transform.localScale = new Vector3(StageW * 1.1f / sw, StageH * 1.02f, 1f);
            }

            hero.basePos = P(layout.heroX, layout.heroFootY);
            hero.height = layout.heroHeight * StageH;

            for (int i = 0; i < allies.Length; i++)
            {
                var pos = i == 0 ? layout.allyBack : layout.allyFront;
                if (allies.Length == 1) pos = layout.allyFront;
                allies[i].basePos = P(pos.x, pos.y);
                allies[i].height = layout.allyHeight * StageH;
            }

            bool boss = Rules.monster != null && Rules.monster.def.grade == MonsterGrade.Boss;
            monster.basePos = P(layout.monsterX, layout.monsterFootY);
            monster.height = (boss ? layout.monsterHeightBoss : layout.monsterHeightNormal) * StageH;

            pet.basePos = P(layout.heroX + layout.petOffsetX, layout.petFootY);
            pet.height = layout.petHeight * StageH;

            spirit.basePos = P(layout.spiritX, layout.spiritFootY);
            spirit.height = layout.spiritHeight * StageH;
        }

        public Vector3 BubbleWorldPos =>
            new Vector3(spirit.basePos.x + layout.bubbleOffset.x * StageW,
                        spirit.basePos.y + spirit.height * 0.5f + layout.bubbleOffset.y * StageH, 0f);

        Vector3 GuardPos => new Vector3(hero.basePos.x + hero.offset.x + hero.height * 0.30f, hero.basePos.y + hero.height * 0.42f, 0f);

        void LateUpdate()
        {
            if (stage == null) return;
            if (layout.swayEnabled != lastLayoutSway) { lastLayoutSway = layout.swayEnabled; Session.sway = layout.swayEnabled; }
            UpdateLayout();

            // 정령은 둥실둥실
            spirit.offset = new Vector2(0f, Mathf.Sin(Time.time * 2.1f) * spirit.height * 0.04f + spirit.height * 0.05f);

            // 방어 태세 방패
            bool guard = Rules.guardArmed && CurrentPhase == Phase.Fight;
            guardShield.enabled = guard;
            if (guard)
            {
                float s = hero.height * 0.5f * (1f + Mathf.Sin(Time.time * 6f) * 0.03f);
                guardShield.transform.localPosition = GuardPos;
                guardShield.transform.localScale = new Vector3(s, s, 1f);
                guardShield.color = new Color(1f, 1f, 1f, 0.82f + Mathf.Sin(Time.time * 6f) * 0.12f);
            }

            // 카메라 흔들림
            Vector3 shake = Vector3.zero;
            if (shakeTime < shakeDuration)
            {
                shakeTime += Time.deltaTime;
                float k = 1f - shakeTime / shakeDuration;
                shake = new Vector3(Mathf.Sin(shakeTime * 90f), Mathf.Cos(shakeTime * 70f) * 0.5f, 0f) * shakeAmount * k;
            }
            Cam.transform.position = camBase + shake;
        }

        public void CameraShake(float amount, float duration)
        {
            shakeAmount = amount;
            shakeDuration = duration;
            shakeTime = 0f;
        }

        // ================= 전투 진행 =================

        IEnumerator Wait(float seconds)
        {
            float t = 0f;
            while (t < seconds) { t += Time.deltaTime; yield return null; }
        }

        IEnumerator Run(int id)
        {
            // 몬스터 등장
            monster.offset = new Vector2(StageW * 0.6f, 0f);
            Hud.Log(Josa(Rules.monster.name, "이", "가") + " 나타났다!");
            yield return monster.MoveOffset(Vector2.zero, 0.5f);
            yield return Wait(0.2f);
            CurrentPhase = Phase.Fight;
            Hud.Refresh();

            while (CurrentPhase == Phase.Fight && id == buildId)
            {
                float tickStart = Time.time;
                while (Transitioning) yield return null;
                if (CurrentPhase != Phase.Fight) break;

                // 동료 자동 공격 (주인공과 함께, 조금씩 늦게)
                for (int i = 0; i < allies.Length; i++)
                    if (!allies[i].busy) StartCoroutine(AllyAttack(i, false, (0.10f + 0.12f * i) / Speed));

                // 주인공이 먼저 공격
                yield return hero.PlayAttack(layout.attackFrameSeconds, Speed, layout.hitFrame, HeroHit, layout.attackStep * StageW);
                if (CurrentPhase != Phase.Fight) break;
                yield return Wait(0.06f / Speed);
                while (Transitioning) yield return null;
                if (CurrentPhase != Phase.Fight) break;

                // 몬스터가 남아 있으면 반격
                if (Rules.monster.Alive) yield return Counter();
                if (!Rules.hero.Alive) { yield return Defeat(); break; }

                Rules.EndTick();
                Hud.Refresh();
                float tick = config.tickSeconds / Speed;
                while (Time.time - tickStart < tick) yield return null;
            }
        }

        void HeroHit()
        {
            var r = Rules.HeroAttack();
            if (!r.valid) return;
            string mon = Rules.monster.name;
            if (r.strike) Hud.Log($"강타! {mon}에게 <color=#FFD24A>{N(r.damage)}</color>");
            else if (r.crit) Hud.Log($"치명타! {mon}에게 <color=#FFD24A>{N(r.damage)}</color>");
            else Hud.Log($"{Rules.hero.name}의 공격 → {mon} {N(r.damage)}");
            ShowMonsterHit(r, ElementKind.None, r.strike, true);
        }

        void ShowMonsterHit(HitResult r, ElementKind element, bool big, bool hitStop)
        {
            float mh = monster.height;
            var hitPos = monster.Center + new Vector3(-mh * 0.12f, Random.Range(-0.08f, 0.12f) * mh, 0f);
            float fxSize = mh * (big ? 0.72f : 0.5f) * (element == ElementKind.None ? 1f : 1.15f);
            fx.Pop(ArtLibrary.Single(ArtSpec.ElementFx(element)), hitPos, fxSize, 0.3f, 0.5f, 1.15f, Random.Range(-25f, 25f));
            if (big) fx.Pop(ArtLibrary.Single("Fx/fx_slash"), hitPos, mh * 0.75f, 0.28f, 0.8f, 1.2f, Random.Range(-15f, 15f), 31);

            bool strong = big || r.crit;
            monster.Flash(new Color(1f, 1f, 1f, 0.85f), layout.flashSeconds);
            StartCoroutine(monster.Shake(layout.monsterShake * (strong ? 1.6f : 1f), layout.monsterShakeSeconds));
            if (hitStop) HitStop.Request(layout.hitStopSeconds * (strong ? 1.6f : 1f));
            if (strong) CameraShake(0.09f, 0.22f);

            Hud.Popup(monster.Head(0.72f), N(r.damage), r.crit || big ? PopupKind.Crit : PopupKind.Normal);
            Hud.Refresh();
            if (r.killed) StartCoroutine(MonsterDown());
        }

        IEnumerator Counter()
        {
            float sp = Speed;
            bool heavy = Rules.monster.NextIsHeavy;
            if (heavy)
            {
                Hud.Popup(monster.Head(1.0f), "강한 공격!", PopupKind.Warn);
                monster.Flash(new Color(1f, 0.2f, 0.15f, 0.55f), 0.35f / sp);
                yield return Wait(0.3f / sp);
            }
            float dur = layout.counterSeconds / sp;
            yield return monster.MoveOffset(new Vector2(-layout.counterLunge * StageW, 0f), dur * 0.45f, false);
            var c = Rules.MonsterCounter();
            if (c.valid) ShowCounter(c);
            yield return monster.MoveOffset(Vector2.zero, dur * 0.55f, true);
        }

        void ShowCounter(CounterResult c)
        {
            Actor target = c.target < 0 ? hero : allies[c.target];
            string tName = c.target < 0 ? Rules.hero.name : Rules.allies[c.target].name;
            string mon = Rules.monster.name;

            if (c.target < 0 && c.guard != GuardOutcome.None)
            {
                var gp = GuardPos;
                if (c.guard == GuardOutcome.Blocked)
                {
                    fx.Pop(ArtLibrary.Single("Fx/fx_guardHit"), gp, hero.height * 0.56f, 0.45f, 0.9f, 1.15f, 0f, 26);
                    Hud.Popup(gp + Vector3.up * hero.height * 0.3f, "막음!", PopupKind.Info);
                    Hud.Log($"방어 태세로 {mon}의 반격을 막았다!");
                    HitStop.Request(layout.hitStopSeconds);
                    StartCoroutine(hero.Shake(0.05f, 0.15f));
                }
                else
                {
                    fx.Pop(ArtLibrary.Single("Fx/fx_guardBreak"), gp, hero.height * 0.62f, 0.5f, 0.9f, 1.25f, 0f, 26);
                    Hud.Popup(gp + Vector3.up * hero.height * 0.3f, "방어가 깨졌다!", PopupKind.Warn);
                    CameraShake(0.12f, 0.25f);
                }
            }

            if (c.damage > 0)
            {
                target.Flash(new Color(1f, 0.22f, 0.22f, 0.65f), layout.flashSeconds * 1.4f);
                StartCoroutine(HurtTilt(target));
                fx.Pop(ArtLibrary.Single("Fx/fx_hit"), target.Center + new Vector3(target.height * 0.1f, 0f, 0f),
                    target.height * 0.32f, 0.25f, 0.5f, 1f, Random.Range(-30f, 30f), 30, new Color(1f, 0.65f, 0.6f));
                Hud.Popup(target.Head(0.7f), "-" + N(c.damage), PopupKind.Hurt);
                if (c.guard == GuardOutcome.None)
                    Hud.Log(c.heavy ? $"{mon}의 강한 공격! {tName} -{N(c.damage)}" : $"{mon}의 반격 → {tName} -{N(c.damage)}");
                else
                    Hud.Log($"방어가 깨졌다! {tName} -{N(c.damage)}");
            }

            if (c.target >= 0 && c.targetDown)
            {
                var a = allies[c.target];
                a.breathing = false;
                StartCoroutine(a.Fade(0.35f, 0.4f));
                Hud.Log($"{Josa(tName, "이", "가")} 쓰러졌다…");
            }
            Hud.Refresh();
        }

        IEnumerator HurtTilt(Actor a)
        {
            float t = 0f, dur = 0.28f;
            while (t < dur)
            {
                t += Time.deltaTime;
                a.tilt = Mathf.Sin(Mathf.Clamp01(t / dur) * Mathf.PI) * 5f;
                yield return null;
            }
            a.tilt = 0f;
        }

        IEnumerator AllyAttack(int i, bool skill, float delay)
        {
            var a = allies[i];
            var st = Rules.allies[i];
            if (delay > 0f) yield return Wait(delay);
            while (a.busy)
            {
                if (!skill) yield break;
                yield return null;
            }
            if (!st.Alive || CurrentPhase != Phase.Fight || Transitioning) yield break;
            if (skill)
            {
                Hud.Log($"{st.name}의 「{st.def.skillName}」!");
                Hud.Popup(a.Head(1.02f), st.def.skillName, PopupKind.Skill);
                a.Flash(new Color(1f, 0.9f, 0.55f, 0.45f), 0.3f);
            }
            yield return a.PlayAttack(layout.attackFrameSeconds, Speed, layout.hitFrame, () =>
            {
                var r = Rules.AllyAttack(i, skill);
                if (!r.valid) return;
                ShowMonsterHit(r, skill ? st.def.element : ElementKind.None, skill, skill);
            }, layout.attackStep * StageW * 0.6f);
        }

        IEnumerator PetSkill()
        {
            pet.busy = true;
            float sp = Speed;
            Hud.Log($"{config.petName}의 펫 스킬!");
            Hud.Refresh();
            var to = new Vector2(monster.basePos.x - monster.height * 0.32f - pet.basePos.x, monster.height * 0.12f);
            yield return Hop(pet, to, 0.28f / sp, pet.height * 0.7f);
            var r = Rules.PetHit();
            if (r.valid) ShowMonsterHit(r, config.petElement, true, true);
            yield return Hop(pet, Vector2.zero, 0.3f / sp, pet.height * 0.45f);
            pet.busy = false;
        }

        IEnumerator Hop(Actor a, Vector2 to, float duration, float arc)
        {
            Vector2 from = a.offset;
            float t = 0f;
            while (t < duration)
            {
                t += Time.deltaTime;
                float k = Mathf.Clamp01(t / duration);
                a.offset = Vector2.Lerp(from, to, k) + Vector2.up * Mathf.Sin(k * Mathf.PI) * arc;
                yield return null;
            }
            a.offset = to;
        }

        IEnumerator MonsterDown()
        {
            Transitioning = true;
            string name = Rules.monster.name;
            Hud.Log($"{Josa(name, "을", "를")} 쓰러뜨렸다!");
            yield return Wait(0.18f);
            monster.Flash(new Color(1f, 1f, 1f, 1f), 0.45f);
            StartCoroutine(monster.MoveOffset(new Vector2(monster.offset.x, -monster.height * 0.06f), 0.45f));
            yield return monster.Fade(0f, 0.45f);

            if (Rules.AdvanceMonster())
            {
                SetMonsterSprite();
                UpdateLayout();
                monster.offset = new Vector2(StageW * 0.6f, 0f);
                Hud.OnMonsterChanged();
                bool boss = Rules.monster.def.grade == MonsterGrade.Boss;
                Hud.Log((boss ? "<color=#E8655A>보스</color> " : "") + Josa(Rules.monster.name, "이", "가") + " 나타났다!");
                yield return monster.MoveOffset(Vector2.zero, 0.5f);
                if (boss) CameraShake(0.1f, 0.3f);
                Transitioning = false;
            }
            else
            {
                Transitioning = false;
                yield return Victory();
            }
        }

        IEnumerator Victory()
        {
            CurrentPhase = Phase.Victory;
            guardShield.enabled = false;
            Hud.Log("<color=#E6C379>승리!</color>");
            Hud.Refresh();
            while (hero.busy) yield return null;
            yield return Wait(0.2f);
            hero.SetIdle(heroVictory);
            hero.Show(heroVictory);
            Hud.ShowResult(true);
            float hop = layout.victoryHop * StageH;
            for (int k = 0; k < 2; k++)
            {
                yield return Hop(hero, Vector2.zero, 0.32f, hop);
                yield return Wait(0.06f);
            }
            // 이어서 가끔 한 번씩 뛰기
            while (CurrentPhase == Phase.Victory)
            {
                yield return Wait(1.8f);
                yield return Hop(hero, Vector2.zero, 0.3f, hop * 0.7f);
            }
        }

        IEnumerator Defeat()
        {
            CurrentPhase = Phase.Defeat;
            guardShield.enabled = false;
            while (hero.busy) yield return null;
            hero.SetIdle(heroTired);
            hero.Show(heroTired);
            Hud.Log($"{Josa(Rules.hero.name, "이", "가")} 쓰러졌다…");
            Hud.Refresh();
            yield return Wait(0.4f);
            Hud.ShowResult(false);
        }

        // ================= 버튼 =================

        public bool CanAct => CurrentPhase == Phase.Fight && !Transitioning;

        public void OnStrike()
        {
            if (CurrentPhase != Phase.Fight) return;
            if (!Rules.TryArmStrike()) return;
            Hud.Log("강타 준비! 다음 공격이 세진다");
            hero.Flash(new Color(1f, 0.85f, 0.4f, 0.5f), 0.35f);
            Hud.Refresh();
        }

        public void OnGuard()
        {
            if (CurrentPhase != Phase.Fight) return;
            if (!Rules.TryArmGuard()) return;
            Hud.Log("방어 태세! 다음 반격을 막는다");
            fx.Pop(ArtLibrary.Single("Fx/fx_guard"), GuardPos, hero.height * 0.5f, 0.25f, 0.6f, 1f, 0f, 25);
            Hud.Refresh();
        }

        public void OnPet()
        {
            if (!CanAct || pet.busy) return;
            if (!Rules.TryUsePet()) return;
            StartCoroutine(PetSkill());
        }

        public void OnAllySkill(int i)
        {
            if (!CanAct || i >= allies.Length) return;
            if (!Rules.TryStartAllySkill(i)) return;
            StartCoroutine(AllyAttack(i, true, 0f));
            Hud.Refresh();
        }

        public void ToggleSpeed()
        {
            Speed = Speed > 1.5f ? 1f : 2f;
            Hud.Refresh();
        }

        /// <summary>살랑임 켜고 끄기 (이번 재생 동안만. 기본값은 StageLayout 의 swayEnabled)</summary>
        public void ToggleSway() { Session.sway = !Session.sway; }

        /// <summary>⚙ 모습 바꾸기 패널에서 고른 뒤</summary>
        public void ApplySelectionAndRestart()
        {
            Restart();
        }

        // ================= 글자 도우미 =================

        public static string N(int v) => v.ToString("N0", CultureInfo.InvariantCulture);

        /// <summary>받침에 따라 조사 고르기: Josa("슬라임", "이", "가") → "슬라임이"</summary>
        public static string Josa(string word, string withFinal, string withoutFinal)
        {
            if (string.IsNullOrEmpty(word)) return word;
            char c = word[word.Length - 1];
            bool final = c >= 0xAC00 && c <= 0xD7A3 && (c - 0xAC00) % 28 != 0;
            return word + (final ? withFinal : withoutFinal);
        }
    }
}
