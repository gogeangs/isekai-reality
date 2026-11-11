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
| spirit_<…>_cheer | 레벨업, 사냥 성공, 일일 퀘스트 모두 완료 |
| spirit_<…>_sleepy | 여관에서 쉬는 중 |
| icon_streak | 여관 '연속 휴식' |
| icon_expedition | 지도 몬스터 창의 '원정 보내기' |
| icon_bag | 가방 버튼(상태창·던전 입구·잡화상)과 가방 창 |

## 마을·장비·화폐 (2026년 11월 10일)

| 파일 | 쓰는 곳 |
| --- | --- |
| village.jpg | 마을 탭 그림 (건물 자리는 village_screen.dart 의 areas) |
| icon_smithy, icon_board | 마을 시설 아이콘 (대장간, 의뢰 게시판) |
| nav_village, nav_bag | 하단 메뉴 '마을', '가방' |
| item_incense | 성장의 향 |
| monster_giantRat | 큰쥐 (길 잃은 돌정령 대신) |
| icon_mana_stone, icon_gold | 마석·금화 (화폐 바꾸는 묶음에서 씀) |
| equip_dagger, equip_staff, equip_cap, equip_armor, equip_gloves, equip_boots, equip_fang_necklace, equip_stone_charm | 장비 (대장간 묶음에서 씀) |
| mat_<재료 이름> (13종) | 재료: 가방, 대장간, 사냥 결과, 잡화상 (철 조각·나뭇가지) |

## 새 몬스터·속성 슬라임·원정 리본 (2026년 11월 11일)

'아르카 그림 프롬프트 3'으로 만든 그림입니다.

| 파일 | 쓰는 곳 |
| --- | --- |
| monster_hornRabbit, monster_babyBoar | 필드 몬스터 혼래빗·아기 와일드 보어 (512×512) |
| monster_<fire·water·wind·earth·light·dark>Slime | 속성 슬라임 6종 (512×512, 이제 색 입힌 재 슬라임 대신 이 그림이 나옴) |
| ribbon_success, ribbon_fail, ribbon_missed | 원정 결과 카드 리본 (1024×341, 글자는 앱이 얹음) |
| mat_rabbitMeat, mat_smallHorn, mat_goldenRabbitFur, mat_boarMeat, mat_toughHide, mat_smallTusk, mat_herb | 새 재료 아이콘 (256×256) |
| mat_<fire·water·wind·mud·light·dark>Jelly | 속성 젤리 6종 (256×256) |
| mat_<fire·water·wind·earth·light·shadow>Core | 속성 코어 6종 (256×256, 금빛 반짝임) |

## 펫·알·장면 (2026년 11월 11일, 그림 프롬프트 4)

| 파일 | 쓰는 곳 |
| --- | --- |
| pet_<crow·blackCat·toad·owl·lizard·homunculus>_<baby·adult> | 펫 6종 아기·성체 (512×512) |
| pet_egg, item_pet_snack | 펫 알, 펫 간식 (256×256) |
| letter_spirit | 정령의 편지 (512×512) |
| scene_hatch | 부화 때 펫 뒤의 빛 (1024×1024) |
| scene_farewell | 정령의 작별 장면 (1600×900) |
| icon_alchemy | 마을 연금술 공방 배지 (512×512) |
| cauldron | 연금술 가마솥 (512×512) |
| item_recipe_book, item_recipe_note, potion_suspicious | 레시피 책·쪽지, 수상한 물약 (256×256) |
| potion_<healBig·antidote·burnSalve·clearEye·strength·agility·intellect·vitality·luck> | 연금술 새 물약 9종 (256×256) |
| potion_resist<Fire·Water·Wind·Earth·Light·Dark>, potion_callMonsters, potion_callModified, potion_plenty | 저항 물약 6종, 부르는 물약 2종, 풍요의 물약 (256×256) |
| icon_post | 마을 우체국 배지 (512×512) |
| icon_mail | 화면 위 우편 아이콘 (256×256) |
| monster_<ice·thunder·metal·poison>Slime | 새 속성 슬라임 4종 (512×512) |
| potion_resist<Ice·Thunder·Metal·Poison> | 새 저항 물약 4종 (256×256) |
| mat_dewHerb, mat_manaOre, mat_sturdyKnot, mat_riverPearl | 채집 귀한 재료 4종 (256×256, 진주는 붉은 테두리를 지워서 넣음) |
| filter_elf, filter_dwarf | 마법 돋보기 엘프·드워프 장식 (1024×1024, 엘프는 둘레 얼룩을 지워서 넣음) |
| filter_fairy, filter_dragonkin | 마법 돋보기 요정·용인 장식 (1024×1024, 둘레 얼룩을 지워서 넣음) |
| lens_frame | 마법 돋보기 감정 사진 틀 (1080×1440, 둘레 얼룩을 지워서 넣음) |
| filter_catfolk | 마법 돋보기 고양이 수인 장식 (1024×1024, 뿌연 배경을 지워서 넣음) |
| filter_foxfolk | 마법 돋보기 여우 수인 장식 (1024×1024) |
| filter_mermaid, filter_starChild | 마법 돋보기 인어·별의 아이 장식 (1024×1024, 둘레 얼룩을 지워서 넣음) |
| item_pouch | 걸음 주머니 (256×256) |
| mat_labyrinthStone, mat_runeStone, mat_ironIngot, mat_hardWood, mat_tannedLeather, mat_herbExtract | 재료 수집·가공 재료 6종 (256×256) |
| mat_essence, mat_glow<Fire·Water·Wind·Earth·Light>Core | 정제 에센스, 빛나는 속성 코어 5종 (256×256) |
| merchant | 떠돌이 상인 (512×512) |
| mat_glowShadowCore | 빛나는 그림자 코어 (256×256) |
| mat_<ice·thunder·metal>Jelly, mat_<ice·thunder·metal>Core | 얼음·번개·금속 젤리와 코어 (256×256) |
| mat_poisonJelly, mat_poisonCore, mat_glowIceCore, mat_glowThunderCore | 독 젤리·코어, 빛나는 얼음·번개 코어 (256×256) |
| mat_glowMetalCore, mat_glowPoisonCore | 빛나는 금속·독 코어 (256×256) |
| icon_el_<fire·water·ice·wind·thunder> | 속성 아이콘 (256×256, 번개는 원 크기를 다른 아이콘에 맞춤) |
| icon_el_<earth·metal·poison·light·dark·none> | 속성 아이콘 나머지 6종 (256×256, 원 크기를 불 아이콘에 맞춤) |
| equip_horn_dagger, equip_boar_armor, equip_rabbit_boots, equip_tusk_necklace | 새 장비 4종 (256×256, 단검은 둘레 얼룩을 지워서 넣음) |
| monster_<fireSlimeKing·frostWolfKing·ancientTreant·shadowBatQueen·thunderGriffin> | 요일 보스 5종 (512×512, 둘레 얼룩을 지워서 넣음) |
| potion_heal_3, potion_heal_4, potion_heal_5 | 치유·생명·여명의 물약 (256×256) |
| potion_mana_3 | 맑은 마나 물약 (256×256) |
| potion_mana_4, potion_mana_5 | 깊은 마나·여명의 마나 물약 (256×256, 4등급은 뿌연 얼룩을 지워서 넣음) |
| mat_bossWardenHeart, mat_bossKingOrb | 보스 재료: 문지기의 심장, 왕의 구슬 (256×256) |
| mat_bossFrostFang | 보스 재료: 서리 송곳니 (256×256, 뿌연 배경과 바람 줄무늬를 지워서 넣음) |
| mat_bossTreantHeart | 보스 재료: 고목의 심재 (256×256) |
| mat_bossQueenWing, mat_bossThunderFeather, mat_bossShard | 보스 재료: 여왕의 밤날개, 천둥 깃털, 보스 장비 조각 (256×256) |
| mat_stoneWater, mat_stoneFire | 물의 마석, 불꽃의 마석 (256×256) |
| mat_stoneWind | 바람의 마석 (256×256) |
| icon_convert_table | 공방 변환대 (256×256) |
| mat_stoneLight, mat_stoneEarth | 빛의 마석, 대지의 마석 (256×256) |
| mat_stoneDark | 어둠의 마석 (256×256) |
| mat_stoneIce | 얼음의 마석 (256×256) |
| mat_stoneThunder | 번개의 마석 (256×256) |
| mat_stoneMetal | 금속의 마석 (256×256) |
| mat_stonePoison | 독의 마석 (256×256) |
| potion_weaponFire | 불꽃 공격 물약 (256×256) |
| potion_weaponWater | 물 공격 물약 (256×256) |
| potion_weaponLight, potion_weaponEarth, potion_weaponWind | 빛·대지·바람 공격 물약 (256×256) |
| potion_weaponDark | 어둠 공격 물약 (256×256) |
| potion_weaponIce | 얼음 공격 물약 (256×256) |
| potion_weaponThunder | 번개 공격 물약 (256×256) |
| potion_thaw, potion_steps, potion_weaponPoison, potion_weaponMetal | 녹이는 물약, 걸음 물약, 독·금속 공격 물약 (256×256) |
| weapon_staff, weapon_axe, weapon_sword | 전투 장면 무기: 지팡이·도끼·검 (512×1024, 손잡이가 아래) |
| weapon_spear | 전투 장면 무기: 창 (512×1024) |
| weapon_dagger | 전투 장면 무기: 단검 (512×1024) |
