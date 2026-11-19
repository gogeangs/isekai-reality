using UnityEngine;
using UnityEngine.UI;

namespace Arca.Battle
{
    public enum PopupKind { Normal, Crit, Hurt, Warn, Info, Skill }

    /// <summary>
    /// 아래 40% 금테 남색 판 (HP 막대 · 전투 기록 · 동료 칸 · 버튼) + 무대 위에 뜨는 글자들.
    /// 전부 코드로 만든다 (장면 파일에 미리 놓을 것이 없음).
    /// </summary>
    public class BattleHud : MonoBehaviour
    {
        BattleDirector dir;
        BattleRules R => dir.Rules;

        Canvas canvas;
        RectTransform root, stageUi, panelArea, panelInner, popupLayer;

        // HP
        Text heroName, heroHpText, monName, monHpText;
        Bar heroBar, monBar;
        // 기록
        Text log1, log2;
        string lastLog = "", prevLog = "";
        // 동료 칸
        AllySlot[] slots = new AllySlot[0];
        // 버튼
        ActionButton strike, guard, petBtn;
        Button speedBtn;
        Text speedText;
        // 무대 위
        RectTransform bubble;
        Text bubbleText;
        Text swayText;
        GameObject result;

        class Bar
        {
            public RectTransform fill, trail;
            public float target = 1f, shown = 1f, trailShown = 1f;
            public void Set(float v) { target = Mathf.Clamp01(v); }
            public void Tick(float dt)
            {
                shown = Mathf.MoveTowards(shown, target, dt * 2.5f);
                trailShown = trailShown > shown ? Mathf.MoveTowards(trailShown, shown, dt * 0.7f) : shown;
                fill.anchorMax = new Vector2(shown, 1f);
                trail.anchorMax = new Vector2(trailShown, 1f);
            }
        }

        class ActionButton
        {
            public Button button;
            public Image icon, cover, ring;
            public Text label, count;
        }

        class AllySlot
        {
            public Image face;
            public Text name, hpText;
            public Bar bar;
            public ActionButton skill;
            public CanvasGroup group;
        }

        // ================= 만들기 =================

        public static BattleHud Create(BattleDirector d)
        {
            var go = new GameObject("BattleHud", typeof(RectTransform));
            var hud = go.AddComponent<BattleHud>();
            hud.dir = d;
            hud.Build();
            return hud;
        }

        void Build()
        {
            canvas = gameObject.AddComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 10;
            var scaler = gameObject.AddComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1170f, 2532f);
            scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.MatchWidthOrHeight;
            scaler.matchWidthOrHeight = 0f; // 너비 기준 (세로 휴대폰)
            scaler.referencePixelsPerUnit = 100f;
            gameObject.AddComponent<GraphicRaycaster>();
            root = (RectTransform)transform;

            float f = dir.layout.stageScreenFraction;
            stageUi = UiKit.Rect("StageUi", root, new Vector2(0f, 1f - f), Vector2.one);
            panelArea = UiKit.Rect("PanelArea", root, Vector2.zero, new Vector2(1f, 1f - f));
            popupLayer = UiKit.Rect("Popups", root, Vector2.zero, Vector2.one);

            BuildPanel();
            BuildStageUi();
            Refresh();
        }

        void BuildPanel()
        {
            var back = UiKit.Image("Back", panelArea, Vector2.zero, Vector2.one, UiKit.White, UiKit.Night);
            back.raycastTarget = true; // 판 뒤로 눌림이 새지 않게
            var inner = UiKit.Image("Panel", panelArea, Vector2.zero, Vector2.one, UiKit.RoundPanel, Color.white, true);
            panelInner = inner.rectTransform;
            panelInner.offsetMin = new Vector2(18f, 18f);
            panelInner.offsetMax = new Vector2(-18f, -14f);
            var p = panelInner;

            // --- HP 막대 ---
            var hb = UiKit.Rect("HeroHp", p, new Vector2(0.04f, 0.80f), new Vector2(0.48f, 0.955f));
            heroName = UiKit.Label("Name", hb, new Vector2(0f, 0.52f), new Vector2(1f, 1f), R.hero.name, 40, UiKit.Gold, TextAnchor.MiddleLeft, UiKit.TitleFont);
            heroBar = MakeBar(hb, new Vector2(0f, 0f), new Vector2(1f, 0.46f), UiKit.HeroHp, out heroHpText, 30);

            var mb = UiKit.Rect("MonsterHp", p, new Vector2(0.52f, 0.80f), new Vector2(0.96f, 0.955f));
            monName = UiKit.Label("Name", mb, new Vector2(0f, 0.52f), new Vector2(1f, 1f), "", 40, UiKit.Ink, TextAnchor.MiddleRight, UiKit.TitleFont);
            monBar = MakeBar(mb, new Vector2(0f, 0f), new Vector2(1f, 0.46f), UiKit.MonsterHp, out monHpText, 30);

            // --- 전투 기록 2줄 ---
            var lb = UiKit.Image("Log", p, new Vector2(0.04f, 0.655f), new Vector2(0.96f, 0.78f), UiKit.RoundBar, new Color(0f, 0f, 0f, 0.28f), true);
            log1 = UiKit.Label("Old", lb.transform, new Vector2(0.03f, 0.5f), new Vector2(0.97f, 0.98f), "", 30, UiKit.TextMuted, TextAnchor.MiddleLeft);
            log2 = UiKit.Label("New", lb.transform, new Vector2(0.03f, 0.02f), new Vector2(0.97f, 0.5f), "", 32, UiKit.Ink, TextAnchor.MiddleLeft);

            // --- 동료 칸 2개 ---
            slots = new AllySlot[R.allies.Count];
            for (int i = 0; i < slots.Length; i++)
            {
                float x0 = i == 0 ? 0.03f : 0.51f;
                slots[i] = MakeAllySlot(p, i, new Vector2(x0, 0.37f), new Vector2(x0 + 0.46f, 0.635f));
            }

            // --- 아래 버튼 줄 ---
            strike = MakeActionButton(p, "강타", "Ui/btn_strike", 0.13f, dir.OnStrike);
            guard = MakeActionButton(p, "방어 태세", "Ui/btn_guard", 0.36f, dir.OnGuard);
            petBtn = MakeActionButton(p, dir.config.petName, "Ui/btn_pet", 0.59f, dir.OnPet);

            speedBtn = UiKit.TextButton("Speed", p, new Vector2(0.75f, 0.14f), new Vector2(0.96f, 0.29f), "1배", 44, out speedText);
            speedBtn.onClick.AddListener(dir.ToggleSpeed);
            UiKit.Label("SpeedLabel", p, new Vector2(0.75f, 0.03f), new Vector2(0.96f, 0.12f), "속도", 28, UiKit.TextMuted);
        }

        Bar MakeBar(Transform parent, Vector2 aMin, Vector2 aMax, Color color, out Text text, int fontSize)
        {
            var back = UiKit.Image("Bar", parent, aMin, aMax, UiKit.RoundBar, UiKit.BarBack, true);
            var area = UiKit.Rect("Area", back.transform, Vector2.zero, Vector2.one);
            area.offsetMin = new Vector2(4f, 4f);
            area.offsetMax = new Vector2(-4f, -4f);
            var trail = UiKit.Image("Trail", area, Vector2.zero, Vector2.one, UiKit.RoundBar, new Color(1f, 0.93f, 0.75f, 0.85f), true);
            var fill = UiKit.Image("Fill", area, Vector2.zero, Vector2.one, UiKit.RoundBar, color, true);
            text = UiKit.Label("Num", back.transform, Vector2.zero, Vector2.one, "", fontSize, UiKit.Ink, TextAnchor.MiddleCenter, UiKit.BodyBold, true);
            return new Bar { fill = fill.rectTransform, trail = trail.rectTransform };
        }

        ActionButton MakeActionButton(Transform parent, string label, string icon, float cx, UnityEngine.Events.UnityAction onClick)
        {
            var ab = new ActionButton();
            var box = UiKit.Rect(label + "Box", parent, new Vector2(cx - 0.11f, 0.12f), new Vector2(cx + 0.11f, 0.345f));
            // 정사각형 버튼을 칸 안에 맞춰 넣기 (빛 고리를 먼저 그려 버튼 뒤에 깔리게)
            var btnRt = SquareWithRing(box, label, out ab.ring);
            ab.icon = btnRt.gameObject.AddComponent<Image>();
            ab.icon.sprite = ArtLibrary.Ui(icon);
            ab.icon.preserveAspect = true;
            ab.cover = UiKit.Image("Cover", btnRt, new Vector2(0.04f, 0.04f), new Vector2(0.96f, 0.96f), UiKit.Circle, new Color(0.03f, 0.03f, 0.1f, 0.62f));
            ab.cover.type = Image.Type.Filled;
            ab.cover.fillMethod = Image.FillMethod.Radial360;
            ab.cover.fillOrigin = (int)Image.Origin360.Top;
            ab.cover.fillClockwise = false;
            ab.cover.fillAmount = 0f;
            ab.count = UiKit.Label("Count", btnRt, Vector2.zero, Vector2.one, "", 56, UiKit.Ink, TextAnchor.MiddleCenter, UiKit.BodyBold, true);
            ab.button = btnRt.gameObject.AddComponent<Button>();
            ab.button.transition = Selectable.Transition.None;
            ab.button.targetGraphic = ab.icon;
            ab.button.onClick.AddListener(onClick);
            btnRt.gameObject.AddComponent<PressBounce>();
            ab.label = UiKit.Label("Label", parent, new Vector2(cx - 0.12f, 0.03f), new Vector2(cx + 0.12f, 0.12f), label, 30, UiKit.Ink);
            return ab;
        }

        AllySlot MakeAllySlot(Transform parent, int i, Vector2 aMin, Vector2 aMax)
        {
            var st = R.allies[i];
            var s = new AllySlot();
            var bg = UiKit.Image("Ally" + i, parent, aMin, aMax, UiKit.RoundBar, new Color(0f, 0f, 0f, 0.25f), true);
            s.group = bg.gameObject.AddComponent<CanvasGroup>();
            var box = bg.rectTransform;

            // 얼굴 (동그랗게 자름)
            var faceBox = UiKit.Rect("FaceBox", box, new Vector2(0.02f, 0.08f), new Vector2(0.30f, 0.92f));
            var ring = UiKit.Image("FaceRing", faceBox, Vector2.zero, Vector2.one, UiKit.Circle, UiKit.Gold);
            var rf = ring.gameObject.AddComponent<AspectRatioFitter>();
            rf.aspectMode = AspectRatioFitter.AspectMode.FitInParent;
            rf.aspectRatio = 1f;
            var mask = UiKit.Image("Mask", ring.transform, new Vector2(0.05f, 0.05f), new Vector2(0.95f, 0.95f), UiKit.Circle, Color.white);
            mask.gameObject.AddComponent<Mask>().showMaskGraphic = false;
            s.face = UiKit.Image("Face", mask.transform, Vector2.zero, Vector2.one, ArtLibrary.Ui("Face/face_" + st.def.id), Color.white);

            s.name = UiKit.Label("Name", box, new Vector2(0.33f, 0.55f), new Vector2(0.72f, 0.92f), st.name, 34, UiKit.Ink, TextAnchor.MiddleLeft, UiKit.TitleFont);
            s.bar = MakeBar(box, new Vector2(0.33f, 0.14f), new Vector2(0.72f, 0.48f), UiKit.AllyHp, out s.hpText, 24);

            // 스킬 버튼
            var skBox = UiKit.Rect("SkillBox", box, new Vector2(0.74f, 0.06f), new Vector2(0.99f, 0.94f));
            var ab = new ActionButton();
            var btnRt = SquareWithRing(skBox, "Skill", out ab.ring);
            ab.icon = btnRt.gameObject.AddComponent<Image>();
            ab.icon.sprite = ArtLibrary.Ui("Ui/btn_skill_empty");
            ab.icon.preserveAspect = true;
            ab.label = UiKit.Label("SkillName", btnRt, new Vector2(0.08f, 0.1f), new Vector2(0.92f, 0.9f), WrapSkill(st.def.skillName), 22, UiKit.Ink, TextAnchor.MiddleCenter, UiKit.BodyBold, true);
            ab.cover = UiKit.Image("Cover", btnRt, new Vector2(0.04f, 0.04f), new Vector2(0.96f, 0.96f), UiKit.Circle, new Color(0.03f, 0.03f, 0.1f, 0.66f));
            ab.cover.type = Image.Type.Filled;
            ab.cover.fillMethod = Image.FillMethod.Radial360;
            ab.cover.fillOrigin = (int)Image.Origin360.Top;
            ab.cover.fillClockwise = false;
            ab.count = UiKit.Label("Count", btnRt, Vector2.zero, Vector2.one, "", 44, UiKit.Ink, TextAnchor.MiddleCenter, UiKit.BodyBold, true);
            ab.button = btnRt.gameObject.AddComponent<Button>();
            ab.button.transition = Selectable.Transition.None;
            ab.button.targetGraphic = ab.icon;
            int idx = i;
            ab.button.onClick.AddListener(() => dir.OnAllySkill(idx));
            btnRt.gameObject.AddComponent<PressBounce>();
            s.skill = ab;
            return s;
        }

        static RectTransform SquareWithRing(Transform box, string name, out Image ring)
        {
            var holder = UiKit.Rect(name + "Square", box, Vector2.zero, Vector2.one);
            var fit = holder.gameObject.AddComponent<AspectRatioFitter>();
            fit.aspectMode = AspectRatioFitter.AspectMode.FitInParent;
            fit.aspectRatio = 1f;
            ring = UiKit.Image("Ring", holder, new Vector2(-0.08f, -0.08f), new Vector2(1.08f, 1.08f), UiKit.Circle, new Color(1f, 0.85f, 0.4f, 0f));
            return UiKit.Rect(name, holder, Vector2.zero, Vector2.one);
        }

        static string WrapSkill(string s)
        {
            if (string.IsNullOrEmpty(s) || s.Length <= 4) return s;
            int sp = s.IndexOf(' ');
            if (sp > 0) return s.Substring(0, sp) + "\n" + s.Substring(sp + 1);
            int half = (s.Length + 1) / 2;
            return s.Substring(0, half) + "\n" + s.Substring(half);
        }

        void BuildStageUi()
        {
            // 위쪽 작은 버튼: 살랑임 켜고 끄기 · 모습 바꾸기
            var sway = UiKit.TextButton("Sway", stageUi, new Vector2(0.03f, 0.905f), new Vector2(0.36f, 0.965f), "", 30, out swayText);
            sway.onClick.AddListener(() => { dir.ToggleSway(); Refresh(); });

            // 정령 응원 말풍선
            var b = UiKit.Image("Bubble", popupLayer, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), UiKit.Bubble, Color.white, true);
            bubble = b.rectTransform;
            bubble.sizeDelta = new Vector2(250f, 78f);
            bubbleText = UiKit.Label("Text", bubble, Vector2.zero, Vector2.one, dir.config.cheerText, 32, UiKit.Hex("#3A2F55"), TextAnchor.MiddleCenter, UiKit.BodyBold);
            bubble.SetAsFirstSibling();
        }

        // ================= 갱신 =================

        public void OnMonsterChanged()
        {
            monBar.shown = monBar.trailShown = 1f;
            Refresh();
        }

        public void Refresh()
        {
            if (R == null) return;
            heroBar.Set(R.hero.Ratio);
            heroHpText.text = BattleDirector.N(R.hero.hp) + " / " + BattleDirector.N(R.hero.maxHp);

            var m = R.monster;
            bool boss = m.def.grade == MonsterGrade.Boss;
            monName.text = (boss ? "<color=#E8655A><size=30>보스</size></color> " : "") + m.name +
                           $" <color=#EFE9DC9E><size=28>{R.monsterIndex + 1}/{R.MonsterCount}</size></color>";
            monBar.Set(m.Ratio);
            monHpText.text = BattleDirector.N(m.hp) + " / " + BattleDirector.N(m.maxHp);

            bool fight = dir.CurrentPhase == BattleDirector.Phase.Fight;

            // 강타
            SetCooldown(strike, R.strikeCooldown, dir.config.strikeCooldownTicks, R.strikeArmed, fight);
            strike.label.text = R.strikeArmed ? "<color=#FFD24A>강타 준비!</color>" : "강타";
            // 방어 태세
            SetCooldown(guard, R.guardCooldown, dir.config.guardCooldownTicks, R.guardArmed, fight);
            guard.label.text = R.guardArmed ? "<color=#8FD3FF>방어 중</color>" : "방어 태세";
            // 펫 게이지
            petBtn.cover.fillMethod = Image.FillMethod.Vertical;
            petBtn.cover.fillOrigin = (int)Image.OriginVertical.Top;
            petBtn.cover.fillAmount = 1f - R.petGauge / (float)BattleRules.PetGaugeMax;
            petBtn.count.text = R.PetReady ? "" : "";
            petBtn.button.interactable = fight && R.PetReady;
            petBtn.label.text = R.PetReady ? $"<color=#FFD24A>{dir.config.petName} 준비!</color>" : $"{dir.config.petName} {R.petGauge}%";

            for (int i = 0; i < slots.Length; i++)
            {
                var st = R.allies[i];
                var s = slots[i];
                s.bar.Set(st.Ratio);
                s.hpText.text = BattleDirector.N(st.hp);
                s.group.alpha = st.Alive ? 1f : 0.45f;
                SetCooldown(s.skill, st.cooldown, st.def.skillCooldownTicks, false, fight && st.Alive);
            }

            speedText.text = dir.Speed > 1.5f ? "2배" : "1배";
            swayText.text = Session.sway ? "살랑임 켬" : "살랑임 끔";
        }

        static void SetCooldown(ActionButton b, int cd, int total, bool armed, bool enabled)
        {
            b.cover.fillAmount = cd > 0 ? Mathf.Clamp01(cd / (float)Mathf.Max(1, total)) : 0f;
            b.count.text = cd > 0 ? cd.ToString() : "";
            b.button.interactable = enabled && cd <= 0 && !armed;
            b.icon.color = enabled ? Color.white : new Color(0.7f, 0.7f, 0.75f, 1f);
            var rc = b.ring.color;
            rc.a = armed ? 0.75f : 0f;
            b.ring.color = rc;
        }

        public void Log(string line)
        {
            prevLog = lastLog;
            lastLog = line;
            if (log1 == null) return;
            log1.text = StripColor(prevLog);
            log2.text = lastLog;
        }

        static string StripColor(string s)
        {
            if (string.IsNullOrEmpty(s)) return s;
            return System.Text.RegularExpressions.Regex.Replace(s, "<.*?>", "");
        }

        void Update()
        {
            if (dir == null || R == null) return;
            float dt = Time.unscaledDeltaTime;
            heroBar.Tick(dt);
            monBar.Tick(dt);
            foreach (var s in slots) s.bar.Tick(dt);

            // 안전 영역 (노치 · 홈 막대) 피하기
            float unitsPerPx = root.rect.height / Mathf.Max(1f, Screen.height);
            var safe = Screen.safeArea;
            panelInner.offsetMin = new Vector2(18f, 18f + safe.yMin * unitsPerPx);
            stageUi.offsetMax = new Vector2(0f, -(Screen.height - safe.yMax) * unitsPerPx);
            float f = dir.layout.stageScreenFraction;
            stageUi.anchorMin = new Vector2(0f, 1f - f);
            panelArea.anchorMax = new Vector2(1f, 1f - f);

            // 준비된 버튼은 반짝반짝
            float pulse = 0.5f + 0.5f * Mathf.Sin(Time.unscaledTime * 6f);
            if (R.PetReady && dir.CurrentPhase == BattleDirector.Phase.Fight)
            {
                var c = petBtn.ring.color; c.a = 0.35f + 0.4f * pulse; petBtn.ring.color = c;
            }
            else { var c = petBtn.ring.color; c.a = 0f; petBtn.ring.color = c; }
            if (R.strikeArmed) { var c = strike.ring.color; c.a = 0.45f + 0.4f * pulse; strike.ring.color = c; }
            if (R.guardArmed) { var c = guard.ring.color; c.a = 0.45f + 0.4f * pulse; guard.ring.color = c; }

            // 말풍선은 정령을 따라다님
            bool showBubble = dir.CurrentPhase == BattleDirector.Phase.Fight || dir.CurrentPhase == BattleDirector.Phase.Intro;
            bubble.gameObject.SetActive(showBubble);
            if (showBubble)
            {
                bubble.anchoredPosition = WorldToCanvas(dir.BubbleWorldPos) + new Vector2(0f, Mathf.Sin(Time.time * 2.1f) * 4f);
                bubble.localScale = Vector3.one * (1f + Mathf.Sin(Time.time * 3f) * 0.02f);
            }
        }

        /// <summary>무대 위 위치 → 이 캔버스 위 위치 (가운데 기준)</summary>
        public Vector2 WorldToCanvas(Vector3 world)
        {
            var screen = dir.Cam.WorldToScreenPoint(world);
            RectTransformUtility.ScreenPointToLocalPointInRectangle(popupLayer, screen, null, out var local);
            return local;
        }

        // ================= 떠오르는 글자 =================

        public void Popup(Vector3 world, string text, PopupKind kind)
        {
            int size; Color color; Font font = UiKit.BodyBold;
            switch (kind)
            {
                case PopupKind.Crit: size = 96; color = UiKit.Crit; break;
                case PopupKind.Hurt: size = 60; color = UiKit.Hex("#FF7A6E"); break;
                case PopupKind.Warn: size = 46; color = UiKit.Hex("#FF9D5C"); font = UiKit.TitleFont; break;
                case PopupKind.Info: size = 50; color = UiKit.Hex("#8FD3FF"); font = UiKit.TitleFont; break;
                case PopupKind.Skill: size = 44; color = UiKit.Gold; font = UiKit.TitleFont; break;
                default: size = 66; color = Color.white; break;
            }
            var t = UiKit.Label("Popup", popupLayer, new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), text, size, color, TextAnchor.MiddleCenter, font, true);
            t.rectTransform.sizeDelta = new Vector2(600f, 140f);
            var o = t.GetComponent<Outline>();
            if (o != null) o.effectDistance = kind == PopupKind.Crit ? new Vector2(5, -5) : new Vector2(3, -3);
            var fl = t.gameObject.AddComponent<FloatingText>();
            fl.Init(this, world + new Vector3(Random.Range(-0.25f, 0.25f), 0f, 0f), kind == PopupKind.Crit);
        }

        // ================= 결과 =================

        public void ShowResult(bool win)
        {
            if (result != null) Destroy(result);
            Refresh();
            var dim = UiKit.Image("Result", stageUi, Vector2.zero, Vector2.one, UiKit.White, new Color(0.04f, 0.04f, 0.1f, win ? 0.25f : 0.45f));
            dim.raycastTarget = true;
            result = dim.gameObject;
            var title = UiKit.Label("Title", dim.transform, new Vector2(0f, 0.62f), new Vector2(1f, 0.86f), win ? "승리!" : "쓰러졌다…",
                win ? 150 : 110, win ? UiKit.Gold : UiKit.Ink, TextAnchor.MiddleCenter, UiKit.TitleFont, true);
            title.GetComponent<Outline>().effectDistance = new Vector2(6, -6);
            title.gameObject.AddComponent<PopIn>();
            var again = UiKit.TextButton("Again", dim.transform, new Vector2(0.3f, 0.47f), new Vector2(0.7f, 0.56f), "다시 하기", 44, out _);
            again.onClick.AddListener(dir.Restart);
            again.gameObject.AddComponent<PopIn>().delay = 0.25f;
        }
    }

}
