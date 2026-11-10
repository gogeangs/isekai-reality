# 이미지 폴더

목업에서 만든 그림을 이 이름으로 넣으면 화면에 바로 나타납니다.
파일이 없으면 화면은 아이콘으로 대신 보여 줍니다.

| 파일 이름 | 내용 |
| --- | --- |
| hero_male.png | 기본 각성자(남) 전신 그림, 배경 없음 |
| hero_female.png | 기본 각성자(여) 전신 그림, 배경 없음 |
| bulssi.png | 정령 동료 불씨(기본 표정), 배경 없음 |
| bg_dusk.png | 메인 화면 배경(현대 도시 + 이세계 겹침, 노을) |

## 몬스터 (넣어 둠)

잿빛 모습 `monster_<id>.png`, 정화된 모습 `monster_<id>_purified.png`. 512×512, 투명 배경.
ChatGPT로 만든 그림을 반으로 잘라 정사각형으로 맞췄습니다.

| id | 잿빛 → 정화 |
| --- | --- |
| ashSlime | 잿빛 슬라임 → 이슬 슬라임 |
| labyrinthBat | 미궁 박쥐 → 별빛 박쥐 |
| roughWaterSpirit | 거칠어진 물방울 정령 → 맑은 물방울 정령 |
| shadowButterfly | 그림자 나비 → 노을 나비 |
| lostStoneSpirit | 길 잃은 돌정령 → 길 찾은 돌정령 |
| labyrinthWarden | 미궁 문지기 → 미궁 수호자 (보스) |

## UI 그림 (2026년 11월 9일)

ChatGPT로 만든 묶음 그림을 잘라 넣었습니다. 목록과 프롬프트는 '목업 재현용 에셋 목록과 프롬프트' 문서에 있습니다.

| 묶음 | 파일 |
| --- | --- |
| 테두리·버튼 | ui_panel(가운데를 비워 9조각으로 늘림), ui_panel_wide, ui_button_gold, ui_button_dark, ui_divider_left/right, ui_level_plaque, ui_ribbon, ui_bubble |
| 아이콘 | icon_vitality, agility, wisdom, spirit, quest, steps, moon, key, key_empty, crystal, exp, levelup, medal, study, check, sun |
| 하단 메뉴 | nav_status, nav_map, nav_records, nav_codex, nav_settings |
| 지도 | map_gate, lake, monster, player, unknown (map_inn·map_store는 상태창의 여관·잡화상 입구) |
| 던전 | floor_1~3, floor_boss, banner_clear, badge_gate, bg_gate, bg_battle, bg_victory |
| 레벨업 | banner_levelup |
| 배경 | bg_header, bg_status_male, bg_status_female, splash |
| 각성자 | hero_attack/victory_male·female, portrait_male·female, hero_chibi_male |
| 효과 | fx_slash, fx_hit, fx_purify |

## 지친 각성자·정령 표정 (2026년 11월 10일)

| 파일 | 쓰는 곳 |
| --- | --- |
| hero_status_tired_male/female | HP 0일 때 상태창 각성자 (원래 그림과 발 위치를 맞춤) |
| hero_tired_male/female | HP 0일 때 던전 입구·필드 전투 화면의 꼬마 각성자 |
| spirit_<fire·water·plant>_worried | HP가 낮거나 쓰러졌을 때, 전투에서 졌을 때 |
| spirit_<…>_cheer | 레벨업, 정화 성공, 일일 퀘스트 모두 완료 |
| spirit_<…>_sleepy | 여관에서 쉬는 중 |
| icon_streak | 여관 '연속 휴식' |
| icon_expedition | 지도 몬스터 창의 '원정 보내기' |
| icon_bag | 가방 버튼(상태창·던전 입구·잡화상)과 가방 창 |
