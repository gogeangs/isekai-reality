using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

namespace Arca.Battle
{
    /// <summary>
    /// ⑦ 「모습 바꾸기」: 주인공 성별 · 직업, 동료 둘, 배경, 펫을 고르고 다시 시작.
    /// (시험용 화면이라 꾸밈은 단순하게)
    /// </summary>
    public class HeroSelectPanel : MonoBehaviour
    {
        BattleDirector dir;
        Image preview;
        readonly List<System.Action> refreshers = new List<System.Action>();

        // 고르는 중인 값 (「이대로 시작」 을 눌러야 적용)
        HeroGender gender;
        HeroJob job;
        readonly List<string> party = new List<string>();
        string background, petId;

        static readonly string[] Backgrounds = { "bg_field_forest", "bg_field_village", "bg_field_city", "bg_field_mountain", "bg_field_sea", "bg_field_water", "bg_battle" };
        static readonly string[] BackgroundNames = { "숲", "마을", "도시", "산", "바다", "물가", "던전" };
        static readonly string[] Pets = { "owl", "golem", "homunculus", "mimic", "toad" };
        static readonly string[] PetNames = { "부엉이", "골렘", "호문쿨루스", "미믹", "두꺼비" };

        public static void Open(BattleDirector d, RectTransform canvasRoot)
        {
            var existing = canvasRoot.GetComponentInChildren<HeroSelectPanel>();
            if (existing != null) return;
            var rt = UiKit.Rect("HeroSelect", canvasRoot, Vector2.zero, Vector2.one);
            var p = rt.gameObject.AddComponent<HeroSelectPanel>();
            p.dir = d;
            p.Build(rt);
        }

        void Build(RectTransform rt)
        {
            gender = Session.gender;
            job = Session.job;
            party.AddRange(Session.party);
            background = Session.background;
            petId = Session.petId;

            var dim = UiKit.Image("Dim", rt, Vector2.zero, Vector2.one, UiKit.White, new Color(0.03f, 0.03f, 0.08f, 0.82f));
            dim.raycastTarget = true;
            var card = UiKit.Image("Card", rt, new Vector2(0.04f, 0.05f), new Vector2(0.96f, 0.95f), UiKit.RoundPanel, Color.white, true).rectTransform;

            UiKit.Label("Title", card, new Vector2(0f, 0.93f), new Vector2(1f, 0.985f), "모습 바꾸기", 56, UiKit.Gold, TextAnchor.MiddleCenter, UiKit.TitleFont);

            // 미리보기
            var pvBox = UiKit.Rect("PreviewBox", card, new Vector2(0.30f, 0.74f), new Vector2(0.70f, 0.925f));
            preview = UiKit.Image("Preview", pvBox, Vector2.zero, Vector2.one, null, Color.white);
            preview.preserveAspect = true;

            float y = 0.725f;
            y = Row(card, y, "성별", new[] { "남", "여" }, i => gender = i == 0 ? HeroGender.Male : HeroGender.Female,
                i => (i == 0) == (gender == HeroGender.Male), 2);
            var jobs = (HeroJob[])System.Enum.GetValues(typeof(HeroJob));
            var jobNames = new string[jobs.Length];
            for (int i = 0; i < jobs.Length; i++) jobNames[i] = Session.JobName(jobs[i]);
            y = Row(card, y, "직업", jobNames, i => job = jobs[i], i => job == jobs[i], 4);

            var allies = dir.config.allies;
            var allyNames = new string[allies.Count];
            for (int i = 0; i < allies.Count; i++) allyNames[i] = allies[i].displayName;
            y = Row(card, y, "동료 (둘)", allyNames, i => ToggleAlly(allies[i].id), i => party.Contains(allies[i].id), 4);
            y = Row(card, y, "배경", BackgroundNames, i => background = Backgrounds[i], i => background == Backgrounds[i], 4);
            y = Row(card, y, "펫", PetNames, i => petId = Pets[i], i => petId == Pets[i], 5);

            var cancel = UiKit.TextButton("Cancel", card, new Vector2(0.06f, 0.025f), new Vector2(0.38f, 0.085f), "닫기", 40, out _);
            cancel.onClick.AddListener(() => Destroy(gameObject));
            var ok = UiKit.TextButton("Ok", card, new Vector2(0.42f, 0.025f), new Vector2(0.94f, 0.085f), "이대로 시작", 44, out var okText);
            okText.color = UiKit.Gold;
            ok.onClick.AddListener(Apply);

            RefreshAll();
        }

        void ToggleAlly(string id)
        {
            if (party.Contains(id)) { if (party.Count > 1) party.Remove(id); return; }
            party.Add(id);
            while (party.Count > 2) party.RemoveAt(0); // 가장 먼저 고른 동료가 빠짐
        }

        float Row(RectTransform card, float yTop, string title, string[] options, System.Action<int> pick, System.Func<int, bool> isOn, int perLine)
        {
            const float lineH = 0.040f, gap = 0.006f;
            int lines = Mathf.CeilToInt(options.Length / (float)perLine);
            UiKit.Label("RowTitle", card, new Vector2(0.05f, yTop - 0.034f), new Vector2(0.95f, yTop), title, 32, UiKit.Gold, TextAnchor.MiddleLeft, UiKit.TitleFont);
            float y = yTop - 0.038f;
            for (int i = 0; i < options.Length; i++)
            {
                int line = i / perLine, col = i % perLine;
                float w = 0.9f / perLine;
                float x0 = 0.05f + col * w;
                float y1 = y - line * (lineH + gap);
                var b = UiKit.TextButton("Opt" + i, card, new Vector2(x0 + 0.006f, y1 - lineH), new Vector2(x0 + w - 0.006f, y1), options[i], 30, out var t);
                var img = b.GetComponent<Image>();
                int idx = i;
                b.onClick.AddListener(() => { pick(idx); RefreshAll(); });
                refreshers.Add(() =>
                {
                    bool on = isOn(idx);
                    img.color = on ? UiKit.Gold : new Color(0.75f, 0.75f, 0.85f, 0.75f);
                    t.color = on ? UiKit.Night : UiKit.Ink;
                });
            }
            return y - lines * (lineH + gap) - 0.008f;
        }

        void RefreshAll()
        {
            foreach (var r in refreshers) r();
            var keepG = Session.gender; var keepJ = Session.job;
            Session.gender = gender; Session.job = job;
            preview.sprite = ArtLibrary.Ui(Session.HeroIdlePath);
            Session.gender = keepG; Session.job = keepJ;
        }

        void Apply()
        {
            Session.gender = gender;
            Session.job = job;
            if (party.Count == 1) party.Add(party[0] == "lian" ? "barkan" : "lian");
            Session.party = party.ToArray();
            Session.background = background;
            Session.petId = petId;
            Destroy(gameObject);
            dir.ApplySelectionAndRestart();
        }
    }
}
