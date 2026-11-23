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
| hero_parts_male | 각성자(남) 부위 시트 (2048×2048, 개발이 잘라서 씀) |
| hero_parts_female | 각성자(여) 부위 시트 (2048×2048, 개발이 잘라서 씀) |
| status_<poison·burn·frozen·dazzle·bound·stance> | 전투 상태 이상 아이콘 6종 (256×256, 원 크기를 맞춤) |
| bg_field_village, bg_field_mountain | 필드 전투 배경: 마을(기본)·산 (1024×1024 jpg) |
| bg_dungeon_1~3, bg_boss_<warden·flame·frost·grove·night·storm> | 던전·보스 전투 배경 9장 (1024×1024 jpg) |
| mat_shadeMushroom, mat_poisonMushroom, mat_moonMushroom, mat_springPetal, mat_summerPetal | 채집 재료: 버섯 3종, 벚꽃잎, 해바라기 꽃잎 (256×256) |
| mat_<autumn·winter>Petal, mat_sunPollen, mat_breezeBloom, mat_roughGem, mat_gem<Fire·Water·Wind·Earth·Light·Dark·Ice·Thunder·Metal·Poison>, mat_ancientShard, mat_relicSeal | 채집 재료 17종 (256×256) |
| fx_hit_<fire·water·wind·earth·light·dark·ice·thunder·metal·poison> | 속성 타격 효과 10종 (512×512, 붉은·자홍 테두리를 지워서 넣음) |
| monster_parts_slime | 슬라임 공용 부위 시트 (2048×2048, 개발이 잘라서 씀) |
| stat_<strength·agility·intellect·vitality·luck> | 스탯 메달 5종 (512×512, 크기를 맞춤) |
| pet_map_<crow·blackCat·toad·owl·lizard·homunculus> | 원정 지도용 펫 메달 6종 (256×256) |
| slot_<weapon·hands·accessory·head·body·feet> | 장비 빈 칸 아이콘 6종 (256×256, 흰색 한 가지, 뿌연 둘레를 지움) |
| monster_parts_<giantRat·hornRabbit·babyBoar·labyrinthBat> | 몬스터 부위 시트 4종 (2048×2048, 개발이 잘라서 씀) |
| monster_parts_<shadowButterfly·labyrinthWarden·fireSlimeKing> | 몬스터 부위 시트 3종 (2048×2048, 개발이 잘라서 씀) |
| monster_parts_<frostWolfKing·ancientTreant·shadowBatQueen·thunderGriffin> | 보스 부위 시트 4종 (2048×2048, 개발이 잘라서 씀) |
| tool_sickle_<stone·iron·silver·mithril> | 약초 낫 4등급 (256×256) |
| tool_pickaxe_<stone·iron·silver·mithril> | 곡괭이 4등급 (256×256) |
| tool_axe_<stone·iron·silver·mithril> | 도끼 4등급 (256×256) |
| tool_rod_<stone·iron·silver·mithril>, tool_brush_<stone·iron·silver·mithril> | 낚싯대·붓 4등급 (256×256) |
| bg_field_sea | 필드 전투 배경: 바다 (1024×1024 jpg) |
| title_boss<Warden·FireKing·FrostWolf·Treant·BatQueen·Griffin>, title_relicHunter | 보스·유물 칭호 배지 7종 (256×256, 시트 한 장에서 잘라 냄) |
| title_el<Fire·Water·Wind·Earth·Light·Dark·Ice·Thunder·Metal·Poison> | 속성 칭호 배지 10종 (256×256, 시트 한 장에서 잘라 냄) |
| map_harvest_<mushroom·flower·gem·relic> | 채집 지도 아이콘 4종 (256×256, 임시 그림을 교체, 시트에서 잘라 냄) |
| equip_warden<Weapon·Head·Body·Hands·Feet·Acc> | 보스 장비 문지기 세트 6종 (512×512, 시트에서 잘라 냄, 뿌연 빛무리 지움) |
| 2026-11-13 | equip_flame{Weapon,Head,Body,Hands,Feet,Acc} | 보스 장비 불꽃 왕 세트 (시트에서 잘라 냄, 512) |
| 2026-11-13 | equip_frost{Weapon,Head,Body,Hands,Feet,Acc} | 보스 장비 서리 늑대 세트 (시트에서 잘라 냄, 512) |
| 2026-11-13 | equip_grove{Weapon,Head,Body,Hands,Feet,Acc} | 보스 장비 고목 세트 (시트에서 잘라 냄, 512) |
| 2026-11-13 | equip_night{Weapon,Head,Body,Hands,Feet,Acc} | 보스 장비 밤날개 세트 (시트에서 잘라 냄, 512) |
| 2026-11-13 | equip_storm{Weapon,Head,Body,Hands,Feet,Acc} | 보스 장비 천둥 세트 (시트에서 잘라 냄, 512) |
| 2026-11-13 | rig/hero_male_{arm_front_raised,arm_back_upper,hand_grip} | 주인공 남자 전투 부위 3 (시트에서 잘라 냄, 기존 부위와 같은 비율로 줄임; arm_back_upper 는 교체) |
| 2026-11-13 | rig/hero_female_{arm_front_raised,arm_back_upper,hand_grip} | 주인공 여자 전투 부위 3 (시트에서 잘라 냄, 기존 부위와 같은 비율; 손 아래 구멍 투명하게; arm_back_upper 는 교체) |
| 2026-11-13 | monster_slime | 하늘 슬라임 (임시 그림 교체, 512) |
| 2026-11-13 | equip_{sword,axe,spear} | 첫 무기 아이콘 3 (시트에서 잘라 냄, 임시 그림 교체, 512) |
| 2026-11-15 | board_{bg,note,pin,seal,done} | 의뢰 게시판 5장 (#180, 바탕 1024×2048·쪽지 800×400·핀 160·도장 256·인장 512×256, 개별 그림 사용) |
| 2026-11-15 | farewell_01_gate | 이별 컷신 장면 1 문 앞 (#182, 852×1846) |
| 2026-11-15 | farewell_02_lookup·03_smile_{fire,water,leaf}·04_light·05_eyes | 이별 컷신 나머지 6장 (#182, 852×1846) |
| 2026-11-15 | farewell_01_gate_female·02_lookup_female·05_eyes_female | 이별 컷신 여자 각성자 판 3장 (#182, 852×1846, 코드에서 성별에 따라 골라 써야 함) |
| 2026-11-15 | card_open_{ore,wood} | 「새로 열렸어요」 카드 Lv.8·Lv.9 금테 메달 (#181, 256, WebP로 합침) |
| 2026-11-15 | card_open_{ore,wood} | 「새로 열렸어요」 카드 Lv.8·Lv.9 (#181, 시트에서 잘라 냄, 256) |
| 2026-11-15 | card_open_{ore,wood} | 금테 메달로 다시 만든 판으로 교체 (#181, 256) |
| 2026-11-15 | monster_ashKing·monster_ashKing_face·bg_boss_gate | 잿빛 군주 안개 판·얼굴 판(512, 원래 캔버스 그대로 줄임) + 본체 전투 배경(1024). 얼굴 판은 자세가 달라 다시 뽑을 예정 |
| 2026-11-15 | ending_01_face | 결말 장면 1 왕의 얼굴 (852×1846) |
| 2026-11-15 | monster_ashKing_face | 얼굴 판 다시 (안개 판과 같은 자세·자리, 겹침 96%) |
| 2026-11-15 | ending_02_face_to_face(_female) | 결말 장면 2 마주 선 둘 남자·여자 (852×1846) |
| 2026-11-15 | ending_03_promise | 결말 장면 3 약속 (852×1846) |
| 2026-11-15 | ending_04_bridge | 결말 장면 4 문이 다리로 (852×1846) |
| 2026-11-15 | ending_05_dawn | 결말 장면 5 다리 너머 여명 (852×1846) |
| 2026-11-15 | potion_jobmana_{1,2} | 마나 물약 2종 (#183, 기력 물약 그림을 보라색으로 바꿔 만든 임시 그림, 160) |
| 2026-11-15 | icon_guild | 길드 아이콘 금테 메달 (임시 그림 교체, 512) |
| 2026-11-15 | potion_jobmana_{1,2} | 직업 마나 물약 보라 2병 (시트에서 잘라 냄, 임시 그림 교체, 512) |
| 2026-11-15 | pet_griffin_{baby,adult}·pet_map_griffin | 희귀 펫 아기 그리핀 (#185, 시트에서 잘라 냄, 512) |
| 2026-11-15 | pet_direwolf_{baby,adult}·pet_map_direwolf | 희귀 펫 다이어울프 (#185, 시트에서 잘라 냄, 512) |
| 2026-11-15 | pet_drake_{baby,adult}·pet_map_drake | 희귀 펫 드레이크 (#185, 시트에서 잘라 냄, 512) |
| 2026-11-15 | pet_kelpie_{baby,adult}·pet_map_kelpie | 희귀 펫 켈피 (#185, 시트에서 그림 덩어리별로 잘라 냄, 512) |
| 2026-11-15 | pet_mimic_{baby,adult}·pet_map_mimic | 희귀 펫 미믹 (#185, 시트에서 그림 덩어리별로 잘라 냄, 512) |
| 2026-11-15 | pet_golem_{baby,adult}·pet_map_golem | 희귀 펫 골렘 (#185, 시트에서 그림 덩어리별로 잘라 냄, 512) |
| 2026-11-15 | map_rift | 지도 잿빛 틈 금테 메달 (2막, 512 → 개발이 160) |
| 2026-11-15 | equip_ash{Weapon,Crown,Body,Hands,Feet,Acc} | 잿빛 왕의 유품 6 (2막, 시트에서 잘라 냄, 512 → 개발이 256) |
| 2026-11-15 | monster_ash{Rage,Sorrow,Greed} | 2막 분신 보스 분노·슬픔·탐욕 (시트에서 그림 덩어리별로 잘라 냄, 512) |
| 2026-11-15 | monster_ash{Fear,Lonely} | 2막 분신 보스 두려움·외로움 (시트에서 잘라 냄, 뿌연 빛무리 제거, 512) |
| 2026-11-15 | bg_victory | 던전 결과 축하 배경, 인물 없는 판으로 교체 (#204, 1536×1024) |
| 2026-11-15 | map_treasure | 길 찾기 보물 상자 지도 표시 (512 → 개발이 160) |
| 2026-11-15 | title_ash{Rage,Sorrow,Greed} | 2막 칭호 분노·슬픔·탐욕 (시트에서 잘라 냄, 512 → 개발이 160) |
| 2026-11-15 | title_ash{Fear,Lonely} | 2막 칭호 두려움·외로움 (시트에서 잘라 냄, 512 → 개발이 160) |
| 2026-11-15 | title_bridgeMaker | 2막 칭호 「다리를 놓은 자」 (512 → 개발이 160) |
| 2026-11-15 | title_{smith,harvest,alchemy,combat}Adept | 숙련도 칭호 견습 4 (#176, 시트에서 잘라 냄, 512 → 개발이 160) |
| 2026-11-15 | title_{walk,appraise,spirit,trade}Adept | 숙련도 칭호 견습 4 (#176, 시트에서 잘라 냄, 512 → 개발이 160) |
| 2026-11-15 | title_{smith,harvest,alchemy,combat}Master | 숙련도 칭호 장인 4 (#176, 시트에서 잘라 냄, 512 → 개발이 160) |
| 2026-11-15 | npc_{marta,toby,bron,ella} | 마을 사람 얼굴 4 (마을 개편, 시트에서 잘라 냄, 512 아래 맞춤) |
| 2026-11-15 | title_{walk,appraise,spirit,trade}Master | 숙련도 칭호 장인 4 (#176, 시트에서 잘라 냄, 512 → 개발이 160) |
| 2026-11-15 | npc_{hart,sera,lumi} | 마을 사람 얼굴 3 (마을 개편, 시트에서 잘라 냄, 512 아래 맞춤) |
| 2026-11-15 | btn_{strike,guard,potion,pet} | 전투 버튼 4 (시트에서 잘라 냄, 512) |
| 2026-11-15 | village_bg | 새 마을 바탕 (건물 없음, 빈 터 12곳, 1536×1024) |
| 2026-11-15 | btn_skill_empty | 전투 빈 스킬 칸 버튼 (512) |
| 2026-11-15 | village_bg_end | 결말 뒤 마을 바탕 (village_bg 편집, 탑 불 켜짐·빛의 다리, 1536×1024) |
| 2026-11-15 | village_fog | 2막 마을 잿빛 안개 겹침 (투명, 1536×1024) |
| 2026-11-15 | village_{inn,shop,board,smithy} | 새 마을 건물 4 (시트에서 잘라 냄, 같은 비율·아래 맞춤, 512) |
| 2026-11-15 | village_{alchemy,guild,shelter,market_build} | 새 마을 건물 4 (첫 시트와 거의 같은 비율, 아래 맞춤, 512) |
| 2026-11-15 | bg_job_awaken | 직업 각성 배경 (1024×1536, 그대로) |
| 2026-11-15 | skill_frame_{attack,life,passive,active} | 스킬 테두리 4 (시트에서 잘라 냄, 번진 빛 노이즈 제거, 가운데 맞춤, 512) |
| 2026-11-15 | fx_job_awaken | 직업 각성 빛 효과 (울퉁불퉁한 배경 경계를 둥글게 서서히 사라지게 다시 만듦, 1024) |
| 2026-11-15 | mastery_{smith,harvest,alchemy,combat} | 숙련도 문장 4 (시트에서 잘라 냄, 가운데 맞춤, 512) |
| 2026-11-15 | guild_hall | 길드 홀 배경 (1536×768로 줄임) |
| 2026-11-15 | mastery_{walk,appraise,spirit,trade} | 숙련도 문장 4 (기획대로 틀 없이, 게임에서 스킬 테두리를 두름, 512) |
| 2026-11-15 | skill_{hotHammer,thornVine,potionThrow,rush} | 전투 스킬 아이콘 4 (시트에서 잘라 냄, 번진 빛 제거, 512) |
| 2026-11-15 | job_{blacksmith,herbalist,alchemist,warrior} | 직업 문장 4 (기본 직업, 시트에서 잘라 냄, 512) |
| 2026-11-15 | skill_{galeSlash,weakStab,chargeOrder,coinToss} | 전투 스킬 아이콘 4 (뒤에 깔린 어두운 판을 걷어 냄, 단검 손잡이·소매는 손으로 살림, 512) |
| 2026-11-15 | job_{explorer,appraiser,tamer,merchant} | 직업 문장 4 (기본 직업, 시트에서 잘라 냄, 512) |
| 2026-11-15 | mastery_{smith,harvest,alchemy,combat} | 숙련도 문장 4 다시 (기획대로 틀 없이, 금테 원판 판을 바꿈, 512) |
| 2026-11-15 | village_inn_{2,3} | 여관 ★2·★3 (★1과 같은 틀: 512, 높이 480, 아래 맞춤) |
| 2026-11-15 | job_{weaponsmith,runesmith,jeweler,healer} | 직업 문장 4 (복합 직업 청록+은 고리, 시트에서 잘라 냄, 512) |
| 2026-11-15 | skill_{masterSlash,runeBurst,gemShard,healingLight} | 전투 스킬 아이콘 4 (시트에서 잘라 냄, 번진 빛 제거, 512) |
| 2026-11-15 | job_{hunter,archaeologist,pilgrim,peddler} | 직업 문장 4 (복합 직업, 시트에서 잘라 냄, 512) |
| 2026-11-15 | skill_{vitalStrike,relicLight,blessedStrike,bundleSwing} | 전투 스킬 아이콘 4 (시트에서 잘라 냄, 번진 빛 제거, 512) |
| 2026-11-16 | job_{adventurer,beastKnight,pathfinder,potionMerchant} | 직업 문장 4 (복합 직업, 시트에서 잘라 냄, 512) |
| 2026-11-16 | job_{nightWalker,gateHeir,ashHunter,allCrafter} | 직업 문장 4 (숨은 직업, 번진 노랑·보라 빛 제거, 512) |
| 2026-11-16 | skill_{counterSlash,jointAttack,windBlade,poisonFlask} | 전투 스킬 아이콘 4 (뒤에 깔린 판을 걷어 냄, 단검 손잡이·날은 손으로 살림, 512) |
| 2026-11-16 | skill_{shadowSlash,gatekeeperLight,ashPurge,artisanCombo} | 전투 스킬 아이콘 4 (숨은 직업, 번진 빛 제거, 512) |
| 2026-11-16 | skill_m_{smith,harvest,alchemy,combat} | 숙련 액티브 스킬 아이콘 4 (시트에서 잘라 냄, 번진 빛 제거, 512) |
| 2026-11-16 | skill_m_{walk,appraise,spirit,trade} | 숙련 액티브 스킬 아이콘 4 (시트에서 잘라 냄, 번진 빛 제거, 512) |
| 2026-11-16 | village_shop_{2,3} | 잡화상 ★2·★3 (512, 긴 쪽 480, 아래 맞춤) |
| 2026-11-16 | village_board_{2,3} | 의뢰 게시판 ★2·★3 (★3은 검은 배경을 걷어 냄, 512, 아래 맞춤) |
| 2026-11-16 | village_smithy_{2,3} | 대장간 ★2·★3 (512, 긴 쪽 480, 아래 맞춤) |
| 2026-11-16 | village_alchemy_{2,3} | 연금술 공방 ★2·★3 (512, 긴 쪽 480, 아래 맞춤) |
| 2026-11-16 | village_guild_{2,3} | 길드 ★2·★3 (512, 긴 쪽 480, 아래 맞춤) |
| 2026-11-16 | village_shelter_{2,3} | 보금자리 ★2·★3 (512, 긴 쪽 480, 아래 맞춤) |
| 2026-11-16 | npc_mina | 잡화상 미나 얼굴 (npc_toby 대신, 512, 아래 맞춤) |
| 2026-11-16 | village_bg, village_bg_end | 마을 바탕 다시 (탑 가운데 위, 빈 터 14곳) + 결말 뒤 바탕(새 바탕을 편집, 구도 같음), 1536×1024 |
| 2026-11-16 | equip_ashWeapon | 분노의 잿불검 다시 (지금 검을 고쳐 불을 세게, 512 → 빌드에서 webp 다시 만듦) |
| 2026-11-16 | mastery_{smith,harvest,alchemy,combat} | 숙련도 문장 4 다시 (직업 문장과 다른 상징: 집게·바구니·가마솥·검 둘, 512) |
| 2026-11-16 | board_note_small | 의뢰 게시판 2열용 세로 쪽지 (512×640, 가운데) |
| 2026-11-16 | village_bg, village_bg_end | 세로 화면용 마을 바탕 (가운데 3×3 빈 터 8 + 우물, 양옆 빈 터 각 3) + 결말 뒤 바탕(편집, 구도 같음) |
| 2026-11-16 | village_bg | 세로 화면용 마을 바탕 다시 (3×3을 가로 약 565~975 안에, 결말 뒤 바탕은 이 그림 편집으로 다음에) |
| 2026-11-16 | village_bg_end | 세로 화면용 결말 뒤 바탕 (새 village_bg 편집, 구도 같음) |
| 2026-11-16 | equip_martaScarf, equip_seraBadge, item_minaPouch, item_dorgunWhetstone, item_lumiNest, potion_dawnLight | 마을 사람 특별 보상 6종 (#226, 512) |
| 2026-11-16 | village_smithy_build{3,2,1} | 공사 중 대장간 3단계 (#225, 한 장 시트에서 잘라 village_smithy 받침에 맞춤, 512) |
| 2026-11-16 | village_board_build{3,2,1} | 공사 중 의뢰 게시판 3단계 (#225, 한 장 시트에서 잘라 village_board 받침에 맞춤, 512) |
| 2026-11-16 | village_alchemy_build{3,2,1} | 공사 중 연금술 공방 3단계 (#225, 한 장 시트에서 잘라 village_alchemy 받침에 맞춤, 512) |
| 2026-11-16 | village_shelter_build{3,2,1} | 공사 중 펫 쉼터 3단계 (#225, 한 장 시트에서 잘라 village_shelter 받침에 맞춤, 512) |
| 2026-11-16 | village_guild_build{3,2,1} | 공사 중 길드 3단계 (#225, 한 장 시트에서 잘라 village_guild 받침에 맞춤, 512) |
| 2026-11-16 | village_training | 훈련장 건물 (#228, 다른 건물과 같은 크기·바닥 위치, 512) |
| 2026-11-16 | village_training_build{3,2,1} | 공사 중 훈련장 3단계 (#228, 한 장 시트에서 잘라 village_training 받침에 맞춤, 흰 테두리 제거, 512) |
| 2026-11-16 | npc_garen | 훈련장 교관 가렌 얼굴 (#228, 512) |
| 2026-11-16 | monster_dummy | 훈련장 허수아비(보통) (#228, 512) |
| 2026-11-16 | equip_garenBand | 가렌의 훈련 완장 (#228 가렌 부탁 4번 보상, 512) |
| 2026-11-16 | title_trialEndurer | 칭호 「시련을 견딘 자」 (#228, 512) |
| 2026-11-16 | monster_dummyHard | 단단한 허수아비 (#228, monster_dummy와 받침 크기·자리 맞춤, 512) |
| 2026-11-16 | monster_dummyElement | 속성 허수아비 (#228, 가슴 수정 비움, monster_dummy와 받침 맞춤, 512) |
| 2026-11-16 | monster_trainingGolem | 훈련 골렘 (#228, 512) |
| 2026-11-16 | village_garden | 약초밭 건물 (#230, 다른 건물과 같은 크기·바닥 위치, 512) |
| 2026-11-16 | village_garden_build{3,2,1} | 공사 중 약초밭 3단계 (#230, 한 장 시트에서 잘라 village_garden 받침에 맞춤, 512) |
| 2026-11-16 | npc_popo | 약초밭 정원사 포포 얼굴 (#230, 512) |
| 2026-11-16 | village_market | 거래소 완공 (#229 3막, village_market_build와 받침 크기·자리 맞춤, 512) |
| 2026-11-16 | npc_barkan | 거래소 상인 바르칸 얼굴 (#229 3막, 512) |
| 2026-11-16 | garden_plot_{empty,sprout,grow,ready} | 약초밭 밭 칸 4단계 (#230, 한 장 시트에서 잘라 같은 틀 자리·크기로 맞춤, 512) |
| 2026-11-17 | seed_herb, seed_flower, seed_glow | 약초밭 씨앗 3종 (#230, 한 장 시트에서 잘라 같은 배율, 빛나는 씨앗 뿌연 테두리 제거, 512) |
| 2026-11-17 | item_martaFlask, item_minaAbacus, item_dorgunAnvil, item_elielFlask | 마을 사람 전용 아이템 4종 (#232, 한 장 시트에서 잘라 같은 배율, 512) |
| 2026-11-17 | item_hartMapcase, item_seraCrest, item_lumiWhistle, item_garenWeight | 마을 사람 전용 아이템 4종 (#232, 한 장 시트에서 잘라 같은 배율, 512) |
| 2026-11-17 | harvest_relic_dirt | 유물 발굴 흙 덮개 (#234, 1024) |
| 2026-11-17 | harvest_herb_plant, harvest_flower_stem | 채집 미니 게임 약초(뿌리까지)·줄기 꽃 (#234, 한 장에서 잘라 붉은 테두리 제거, 512×768) |
| 2026-11-17 | harvest_relic_dirt | 유물 발굴 흙 덮개 만화풍으로 교체 (#234, 1024) |
| 2026-11-17 | bg_harvest_herb | 채집 미니 게임 약초 덤불 배경 (#234, 1024×1536) |
| 2026-11-17 | harvest_mushroom_bed | 채집 미니 게임 버섯 밭 판 (#234, 1024, 빈 자리 3×3 중심 x 293·507·721 / y 356·527·700) |
| 2026-11-17 | harvest_herb_soil, harvest_wood_saw, harvest_water_bobber, harvest_water_fish | 채집 미니 게임 작은 소품 4종 (#234, 한 장에서 잘라 회색 안개 제거, 흙·톱·물고기 512×256, 찌 256×256) |
| 2026-11-17 | bg_harvest_flower | 채집 미니 게임 꽃밭 배경 (#234, 1024×1536) |
| 2026-11-17 | harvest_ore_rock | 채집 미니 게임 큰 바위 (#234, 1024) |
| 2026-11-17 | harvest_ore_rock_broken | 채집 미니 게임 쪼개진 바위 (#234, harvest_ore_rock과 같은 칸·자리, 1024) |
| 2026-11-17 | bg_harvest_mushroom | 채집 미니 게임 버섯 군락 배경 (#234, 1024×1536) |
| 2026-11-17 | harvest_gem_wall | 채집 미니 게임 광맥 벽 (#234, 1024, 원석 홈 가운데 약 x508·y529, 금테 반지름 약 171) |
| 2026-11-17 | bg_harvest_ore | 채집 미니 게임 광석 바위 배경 (#234, 1024×1536) |
| 2026-11-17 | harvest_wood_log, harvest_wood_log_split | 채집 미니 게임 통나무·갈라진 통나무 (#234, 같은 배율·자리, 붉은 테두리 제거, 1024×512) |
| 2026-11-17 | harvest_relic_pot | 채집 미니 게임 묻힌 유물 토기 (#234, 1024) |
| 2026-11-17 | bg_harvest_gem | 채집 미니 게임 보석 광맥 배경 (#234, 1024×1536) |
| 2026-11-17 | pet_wolf_baby, pet_wolf_adult | 영웅 펫 은빛 늑대 아기·성체 (#235, 한 장에서 잘라 회색 안개 제거, 같은 배율, 512) |
| 2026-11-17 | bg_harvest_wood | 채집 미니 게임 쓰러진 나무(벌목 터) 배경 (#234, 1024×1536) |
| 2026-11-17 | bg_harvest_water | 채집 미니 게임 물가 배경 (#234, 1024×1536) |
| 2026-11-17 | bg_harvest_relic | 채집 미니 게임 고대 유물 배경 (#234, 1024×1536) |
| 2026-11-17 | pet_wolf_awake | 영웅 펫 은빛 늑대 각성 모습 (#235, pet_wolf_adult와 같은 크기·바닥 자리, 512) |
| 2026-11-17 | title_forestKeeper, item_popoDew | 포포 특별 보상 칭호·이슬병 (#230, 한 장에서 잘라 512) |
| 2026-11-17 | pet_turtle_baby, pet_turtle_adult | 영웅 펫 이끼 거북 아기·성체 (#235, 한 장에서 잘라 같은 배율, 512) |
| 2026-11-17 | pet_panther_baby, pet_panther_adult | 영웅 펫 달그림자 표범 아기·성체 (#235, 한 장에서 잘라 같은 배율, 512) |
| 2026-11-17 | pet_whale_baby, pet_whale_adult | 영웅 펫 안개 고래 아기·성체 (#235, 한 장에서 잘라 같은 배율, 512) |
| 2026-11-17 | pet_phoenix_baby, pet_phoenix_adult | 영웅 펫 잿불새 아기·성체 (#235, 한 장에서 잘라 붉은 번짐 정리, 같은 배율, 512) |
| 2026-11-17 | pet_stag_baby, pet_stag_adult | 영웅 펫 새벽 사슴 아기·성체 (#235, 한 장에서 잘라 뿌연 빛무리 제거, 같은 배율, 512) |
| 2026-11-17 | pet_phoenix_awake, pet_whale_awake, pet_panther_awake, pet_turtle_awake | 영웅 펫 각성 모습 4종 (#235, 뿌연 빛무리 제거, 512) |
| 2026-11-17 | pet_stag_awake | 영웅 펫 새벽 사슴 각성 모습 (#235, 뿌연 빛무리 제거·해돋이 원판 유지, 512) |
| 2026-11-17 | pet_map_{wolf,turtle,panther,whale,phoenix,stag} | 영웅 펫 지도 메달 6종 (#235, 한 장에서 잘라 같은 크기, 512 → 개발이 128로) |
| 2026-11-17 | map_highland | 하이랜드 지도 섬 표시 (#146, 512 → 개발이 160으로, 하늘색은 개발이 속성마다 바꿈) |
| 2026-11-17 | scene_highland_first | 하이랜드 첫 만남 장면 (#146, 852×1846) |
| 2026-11-17 | title_skyWalker, title_guardianTrust, title_kingdomWitness | 하이랜드 칭호 3종 (#146, 한 장에서 잘라 같은 테두리 크기, 512 → 개발이 160으로) |
| 2026-11-17 | bg_highland_wind | 하이랜드 바람 섬 구름 초원 배경 (#146, 1024) |
| 2026-11-17 | item_skyFeather, mat_skyStone, mat_cloudCrystal, mat_stormCore, mat_sunDew, mat_frostCrystal, mat_fallsPearl | 하이랜드 하늘 깃털·재료 6종 (#146, 한 장에서 잘라 뿌연 빛무리 제거, 같은 배율, 512) |
| 2026-11-17 | bg_highland_thunder | 하이랜드 번개 섬 폭풍 배경 (#146, 1024) |
| 2026-11-17 | monster_guard{Wind,Thunder,Light,Ice,Water}, monster_stoneSoldier | 하이랜드 수호자 석상 5종 + 석상 병사 (#146, 한 장에서 잘라 뿌연 빛무리 제거, 같은 배율·바닥 맞춤, 512) |
| 2026-11-17 | bg_highland_light | 하이랜드 빛 섬 햇살 정원 배경 (#146, 1024) |
| 2026-11-17 | equip_sky{Weapon,Head,Body,Hands,Feet,Acc} | 하이랜드 하늘 장비 6종 (#146, 한 장에서 잘라 같은 배율, 512 → 개발이 256으로) |
| 2026-11-17 | bg_highland_ice | 하이랜드 얼음 섬 서리 봉우리 배경 (#146, 1024) |
| 2026-11-17 | bg_highland_water | 하이랜드 물 섬 폭포 배경 (#146, 1024) |
| 2026-11-17 | village_tavern | 주점 건물 (#242, 다른 건물과 같은 크기·바닥 위치, 512) |
| 2026-11-17 | npc_lian | 각성자 리안 얼굴 (#242, 붉은 테두리 제거, 512) |
| 2026-11-17 | scene_meet_lights | 리안 만남 장면 1 낯선 불빛들 (#242, 852×1846) |
| 2026-11-17 | npc_lian | 리안 얼굴 다시 — 미나·가렌과 같은 귀여운 그림체로 교체 (#242, 512) |
| 2026-11-17 | item_barkanSeal, equip_lianKnot, food_stew, food_honeyBread, food_skewer | 주점 아이콘 5종(바르칸 인장·리안 매듭·고기 스튜·꿀빵·매운 꼬치), 시트 분할·붉은 테두리 정리, 512 |
| 2026-11-17 | scene_meet_lian | 리안 만남 장면 2 「리안이 다가옴」, 852×1846 |
| 2026-11-17 | title_merchantFriend, title_walkTogether | 칭호 「상단의 벗」·「함께 걷는 자」, 시트 분할 512 |
| 2026-11-17 | npc_nia, npc_teo | 3막 이야기 동료 얼굴(니아·테오), 시트 분할·창 끝 붉은 테두리 정리, 아래 맞춤 512 |
| 2026-11-17 | item_recruitTicket, item_martaLunch, icon_journeyEnergy | 3막 공통 아이콘(모집권·마르타의 도시락·여정 기력), 시트 분할·모집권 흰 번짐 정리, 512 |
| 2026-11-17 | ally_lian, ally_garen | 3막 동료 전투 전신(리안·가렌), 같은 배율·발끝 y=1012 맞춤, 768×1024 |
| 2026-11-17 | map_region_baldrin | 발드린 관문 지역 지도 1024×1536. 장소 대략 위치(x,y): 다리 끝 512,1180 · 야영지 470,880 · 잿빛 들판 150,720 · 성벽길 850,700 · 은빛 늑대 언덕 110,230 · 요새 입구 550,260 · 바람의 굴 920,240 |
| 2026-11-17 | equip_baldrin{Weapon,Head,Body,Hands,Feet,Acc} | 발드린 문지기 세트 6부위, 시트 분할 512 |
| 2026-11-17 | monster_goblinRaider, monster_skeletonGuard, monster_harpy, monster_ogre | 발드린 일반 몬스터 4종, 시트 분할 512 |
| 2026-11-17 | town_baldrin | 발드린 피난민 야영지 마을 그림, 1254→1024 |
| 2026-11-17 | monster_ashHounds, monster_ashArmor, monster_ashWolfAlpha | 발드린 보스 3종(사냥개 무리·빈 갑주·늑대 우두머리), 분홍·붉은 테두리 정리, 512 |
| 2026-11-17 | bg_baldrin_ashplain | 발드린 필드 배경 잿빛 들판, 1024 |
| 2026-11-17 | npc_volk, npc_hanna, npc_pipi, npc_orum | 발드린 주민 얼굴 4종, 시트 분할·아래 맞춤 512 |
| 2026-11-17 | bg_baldrin_wallroad | 발드린 필드 배경 무너진 성벽길, 1024 |
| 2026-11-17 | item_lianCompass, item_barkanPurse | 리안·바르칸 전용 아이템(나침반·동전 주머니), 시트 분할 512 |
| 2026-11-17 | bg_baldrin_wolfhill | 발드린 필드 배경 은빛 늑대의 언덕, 1024 |
| 2026-11-17 | title_baldrinLamp, title_windMemory | 발드린 칭호 2종(관문의 등불지기·바람을 기억하는 자), 시트 분할 512 |
| 2026-11-17 | bg_dungeon_baldrin | 발드린 던전 배경 문지기 지하 요새, 1024 |
| 2026-11-17 | equip_baldrinSpear, uniq_volkHelm, uniq_teoSpear, uniq_windPendant | 관문의 빛 창·발드린 이름 있는 장비 3, 넓은 빛 번짐·노랑/빨강 테두리 정리(물체 둘레 얇은 주황 빛만 남김), 512 |
| 2026-11-17 | bg_baldrin_windden | 발드린 숨은 장소 배경 바람의 굴, 1024 |
| 2026-11-17 | monster_harpy | 하피 다시(사람 얼굴+새 날개·발톱), 덮어쓰기 512 |
| 2026-11-17 | ally_job_warrior, ally_job_archer | 이름 없는 동료 전사·궁수 전신, 같은 배율·발끝 y=1012, 768×1024 |
| 2026-11-17 | scene_act3_fivelamps | 3막 끝 장면 다섯 등불이 이어짐, 852×1846 |
| 2026-11-17 | ally_job_mage, ally_job_priest | 이름 없는 동료 마법사·사제 전신, 같은 배율·발끝 y=1012, 768×1024 |
| 2026-11-17 | scene_teo_marta | 3막 끝 장면 테오와 마르타의 재회, 852×1846 |
| 2026-11-17 | ally_job_rogue, ally_job_knight | 이름 없는 동료 도적·기사 전신, 위쪽 흰 얼룩 제거, 같은 배율·발끝 y=1012, 768×1024 |
| 2026-11-17 | ally_nia, ally_barkan | 3막 동료 전투 전신(니아·바르칸), 같은 배율(니아가 더 작음)·발끝 y=1012, 768×1024 |
| 2026-11-17 | map_region_selenia | 셀레니아 지역 지도 1024×1536. 장소 대략 위치(x,y): 관문에서 오는 다리 512,1300 · 대장터(마을) 560,700 · 흑등 상회 거리 790,700 · 대상의 길 120,900 · 상회 지하 금고 540,330 · 버려진 광산 900,220 · 별가루 골짜기 150,330 · 별가루 광맥 230,160 |
| 2026-11-17 | ally_popo, ally_sera | 3막 동료 전투 전신(포포·세라), 같은 배율·발끝 y=1012, 768×1024 |
| 2026-11-17 | map_region_elowin | 엘로윈 지역 지도 1024×1536. 장소 대략 위치(x,y): 장터에서 오는 길 512,1380 · 잎사귀 마을(고목) 520,640 · 덩굴 숲길 150,1000 · 멈춘 샘물 연못 840,1060 · 버섯 안개 언덕 140,250 · 고목의 뿌리 미궁 560,210 · 모스의 연못 880,330 |
| 2026-11-17 | ally_teo | 3막 동료 전투 전신(테오), 다른 동료와 같은 틀·발끝 y=1012, 768×1024 |
| 2026-11-17 | map_region_morval | 모르발 지역 지도 1024×1536. 장소 대략 위치(x,y): 숲에서 오는 길 510,1420 · 성 아랫마을 470,760 · 성벽 밖 폐허 110,760 · 왕실 묘지 870,740 · 안개 호수 170,440 · 잿빛 왕좌의 탑 620,120 · 근위대 마구간 890,330 |
| 2026-11-17 | monster_orcMerc, monster_koboldMiner, monster_gargoyle, monster_livingArmor | 셀레니아 일반 몬스터 4종, 시트 분할 512 (발밑 흙 그림자 포함, 선이 거친 편) |
| 2026-11-17 | map_region_aurel | 아우렐 지역 지도 1024×1536. 장소 대략 위치(x,y): 왕도에서 오는 길 510,1430 · 순례자 천막촌 420,1030 · 재 내리는 순례길 130,700 · 용암 협곡 830,760 · 불꽃 제단 150,400 · 산꼭대기 성소(여명의 근원) 560,230 · 불새 둥지 920,230 |
| 2026-11-17 | equip_seleniaAxe, uniq_grumHammer, uniq_blackLantern, uniq_stardustBoots | 셀레니아 지역 무기·이름 있는 장비 3, 넓은 빛 번짐·노랑/빨강 테두리 정리, 512 |
| 2026-11-17 | village_garden_2 | 약초밭 ★2, ★1과 같은 땅 너비·아래(496) 맞춤 512 |
| 2026-11-17 | monster_orcMerc, monster_koboldMiner, monster_gargoyle, monster_livingArmor | 셀레니아 일반 몬스터 4종 다시(매끈한 선·발밑 흙 없음), 덮어쓰기 512 |
| 2026-11-17 | town_selenia | 셀레니아 마을 그림(불 꺼진 대장터 + 흑등 상회 거리), 1024 |
| 2026-11-17 | monster_orcCaptain, monster_ashCart, monster_metalColossus | 셀레니아 보스 3종(오크 용병 대장·잿빛 수레 괴물·고대 금속 거인), 시트 분할 512 |
| 2026-11-17 | bg_selenia_caravan | 셀레니아 필드 배경 대상의 길, 1024 |
| 2026-11-17 | npc_eni, npc_grum, npc_oscar, npc_mir, npc_kaspar | 셀레니아 주민 얼굴 5종, 시트 분할·아래 맞춤 512 |
| 2026-11-17 | bg_selenia_mine | 셀레니아 필드 배경 버려진 광산, 1024 |
| 2026-11-17 | village_garden_3 | 약초밭 ★3, ★1·★2와 같은 땅 너비·아래(496) 맞춤 512 |
| 2026-11-17 | bg_selenia_stardust | 셀레니아 필드 배경 별가루 골짜기, 1024 |
| 2026-11-17 | equip_selenia{Weapon,Head,Body,Hands,Feet,Acc} | 셀레니아 상단 세트 6부위, 시트 분할 512 |
| 2026-11-17 | bg_dungeon_selenia | 셀레니아 던전 배경 흑등 상회의 지하 금고, 1024 |
| 2026-11-17 | mat_stardust | 재료 별가루(병), 512 |
| 2026-11-17 | bg_selenia_vein | 셀레니아 숨은 장소 배경 별가루 광맥, 1024 |
| 2026-11-17 | village_training_2 | 훈련장 ★2, ★1과 같은 땅 너비·아래(496) 맞춤 512 |
| 2026-11-17 | town_elowin | 엘로윈 마을 그림(잎사귀 마을, 고목 위), 1024 |
| 2026-11-17 | title_seleniaLamp, title_stardustFinder, title_elowinLamp, title_mossFriend | 셀레니아·엘로윈 칭호 4종, 시트 분할 512 |
| 2026-11-17 | village_training_3 | 훈련장 ★3, ★1·★2와 같은 땅 너비·아래(496) 맞춤 512 |
| 2026-11-17 | monster_treant, monster_giantSpider, monster_dryad, monster_woodWolf | 엘로윈 일반 몬스터 4종, 시트 분할·붉은 테두리 정리 512 |
| 2026-11-17 | bg_elowin_vinepath | 엘로윈 필드 배경 잿빛 덩굴 숲길, 1024 |
| 2026-11-17 | monster_treant, monster_giantSpider, monster_dryad, monster_woodWolf | 엘로윈 일반 몬스터 4종 다시(굵은 선), 덮어쓰기 512 |
| 2026-11-17 | village_tavern_2 | 주점 ★2, ★1과 같은 땅 너비·아래(496) 맞춤 512 |
| 2026-11-17 | equip_elowin{Weapon,Head,Body,Hands,Feet,Acc} | 엘로윈 나무지기 세트 6부위, 반투명 얼룩 배경 제거·시트 분할 512 |
| 2026-11-17 | npc_arbel, npc_momo, npc_doto, npc_ellaDryad | 엘로윈 주민 얼굴 4종, 시트 분할·아래 맞춤 512 |
| 2026-11-17 | village_tavern_3 | 주점 ★3, ★2와 같은 땅 너비·아래(496) 맞춤 512 |
| 2026-11-17 | food_mushroomSoup | 주점 ★2 새 한 끼 버섯 수프, 512 |
| 2026-11-17 | equip_elowinStaff, uniq_momoWreath, uniq_arbelDagger, uniq_elderHeart | 엘로윈 지역 무기·이름 있는 장비 3, 넓은 빛 번짐·노랑/빨강 테두리 정리 512 |
| 2026-11-17 | bg_elowin_spring | 엘로윈 필드 배경 멈춘 샘물 연못, 1024 |
| 2026-11-17 | uniq_arbelDagger | 아르벨의 잎새 단검 다시(꽉 찬 잎 날·얇은 빛), 덮어쓰기 512 |
| 2026-11-17 | bg_elowin_mushroom | 엘로윈 필드 배경 버섯 안개 언덕, 1024 |
| 2026-11-17 | bg_dungeon_elowin | 엘로윈 던전 배경 고목의 뿌리 미궁, 1024 |
| 2026-11-17 | bg_elowin_mosspond | 엘로윈 숨은 장소 배경 모스의 연못, 1024 |
| 2026-11-17 | town_morval | 모르발 마을 그림(다시 일어서는 왕도 아랫마을), 1024 |
| 2026-11-17 | bg_morval_ruins | 모르발 필드 배경 무너진 성벽 밖 폐허, 1024 |
| 2026-11-17 | bg_morval_crypt | 모르발 필드 배경 왕실 지하 묘지, 1024 |
| 2026-11-17 | bg_morval_lake | 모르발 필드 배경 잿빛 안개 호수, 1024 |
| 2026-11-17 | bg_dungeon_morval | 모르발 던전 배경 잿빛 왕좌의 탑, 1024 |
| 2026-11-17 | bg_morval_stable | 모르발 숨은 장소 배경 근위대 마구간, 1024 |
| 2026-11-17 | town_aurel | 아우렐 마을 그림(순례자 천막촌), 1024 |
| 2026-11-17 | bg_aurel_pilgrim | 아우렐 필드 배경 재가 내리는 순례길, 1024 |
| 2026-11-17 | bg_aurel_lava | 아우렐 필드 배경 용암 협곡, 1024 |
| 2026-11-17 | bg_aurel_altar | 아우렐 필드 배경 꺼져 가는 불꽃 제단, 1024 |
| 2026-11-17 | bg_dungeon_aurel | 아우렐 던전 배경 여명의 근원, 1024 |
| 2026-11-17 | bg_aurel_phoenixnest | 아우렐 숨은 장소 배경 잿불새의 둥지, 1024 |
| 2026-11-17 | chest_party, chest_partyBronze, chest_partySilver, chest_partyGold | 파티 상자 4종, 같은 배율·바닥(491) 맞춤 512 |
| 2026-11-17 | mat_golemCore, mat_hydraScale, mat_wyvernClaw, mat_krakenPearl, item_footTicket, icon_cheer | 파티 보스 재료 4·발자국 표·응원 버튼, 색 테두리 정리·시트 분할 512 |
| 2026-11-18 | equip_aurel{Weapon,Head,Body,Hands,Feet,Acc} | 아우렐 순례 세트 6부위, 시트 분할 512 |
| 2026-11-18 | equip_morvalSword, uniq_lucyFlower, uniq_kingCloak, uniq_moonFang | 모르발 지역 무기·이름 있는 장비 3, 얇은 주황 테두리만, 붉은 얼룩 정리 512 |
| 2026-11-18 | monster_spiderQueen, monster_ashElder, monster_ashTortoise | 엘로윈 보스 3종(거미 여왕·잿빛 고목·잿빛 거북), 진한 붉은 테두리 정리·시트 분할 512 |
| 2026-11-18 | monster_vampireBat, monster_wraith, monster_ghoul, monster_cultZealot | 모르발 일반 몬스터 4종, 분홍·파랑 테두리 정리·시트 분할 512 |
| 2026-11-18 | monster_cultPriests, monster_ashCaptain, monster_ashBeasts | 모르발 보스 3종(사제 셋·잿빛 근위대장·근위대 짐승 무리), 붉은·분홍 테두리 정리 512 |
| 2026-11-18 | npc_ashKingRestored, npc_howden, npc_lucy, npc_marco, npc_orben | 모르발 주민·악역 얼굴 5종, 시트 분할·아래 맞춤 512 |
| 2026-11-18 | monster_vampireBat, monster_wraith, monster_ghoul, monster_cultZealot | 모르발 일반 몬스터 4종 다시(굵은 선), 덮어쓰기 512 |
| 2026-11-18 | equip_morval{Weapon,Head,Body,Hands,Feet,Acc} | 모르발 근위 세트 6부위, 시트 분할 512 |
| 2026-11-18 | monster_cultPriests, monster_ashCaptain, monster_ashBeasts | 모르발 보스 3종 다시(굵은 선·짐승 털 반 검정/반 잿빛), 덮어쓰기 512 |
| 2026-11-18 | monster_salamander, monster_ifrit, monster_koboldrake, monster_cultFlamePriest | 아우렐 일반 몬스터 4종, 시트 분할 512 |
| 2026-11-18 | monster_youngRedDragon, monster_orben, monster_orbenAsh, monster_phoenixMother | 아우렐 보스 4종(새끼 레드 드래곤·오르벤 1단계·마지막 단계·불사조 어미), 넓은 색 번짐 정리 512 |
| 2026-11-18 | npc_naomi, npc_tess, npc_cord, npc_pin | 아우렐 주민 얼굴 4종, 시트 분할·아래 맞춤 512 |
| 2026-11-18 | monster_orben | 오르벤 1단계 다시(꽉 찬 잿빛 연기 포함), 덮어쓰기 512 |
| 2026-11-18 | equip_aurelBow, uniq_teoCloak, uniq_naomiStaff, uniq_phoenixCharm | 아우렐 지역 무기(활)·이름 있는 장비 3, 얇은 주황 테두리만 512 |
| 2026-11-18 | title_morvalLamp, title_guardMemory, title_aurelLamp, title_fiveLamps, title_phoenixHonor | 모르발·아우렐·3막 끝 칭호 5종, 시트 분할 512 |
| 2026-11-18 | monster_partyGolem, monster_partyHydra, monster_partyWyvern, monster_partyKraken | 파티 보스 4종, 붉은 테두리 정리·시트 분할 512 |
| 2026-11-18 | flag_party, flag_emb_sword/paw/lantern/tower/leaf/star/moon/wing | 파티 깃발 바탕(흰 천·금 깃대)과 문양 8종(흰색+금 테두리, 색 입혀 쓰는 용도), 512 |
| 2026-11-18 | equip_partyWeapon/Head/Body/Hands/Feet/Acc | 파티 보스 세트 「동행」 6부위(청록 천·금 테두리·발자국 고리 문양), 512 |
| 2026-11-18 | pet_pegasus_baby, pet_pegasus_adult | 전설 펫 페가수스 「아스트라」 아기·성체 (한 장에서 잘라 같은 배율, 512) |
| 2026-11-18 | pet_behemoth_baby, pet_behemoth_adult | 전설 펫 베히모스 「고르」 아기·성체 (한 장에서 잘라 붉은 번짐 정리, 같은 배율, 512) |
| 2026-11-18 | pet_nightmare_baby, pet_nightmare_adult | 전설 펫 나이트메어 「셰이드」 아기·성체 (한 장에서 잘라 같은 배율, 떠다니는 보라 연기 포함, 512) |
| 2026-11-18 | pet_leviathan_baby, pet_leviathan_adult | 전설 펫 리바이어던 「마레」 아기·성체 (한 장에서 잘라 붉은 번짐 정리, 같은 배율, 물방울 포함, 512) |
| 2026-11-18 | pet_dragon_baby, pet_dragon_adult | 전설 펫 드래곤 「이그니스」 아기·성체 (한 장에서 잘라 같은 배율, 입김 불꽃 포함, 512) |
| 2026-11-18 | pet_unicorn_baby, pet_unicorn_adult | 전설 펫 유니콘 「루체」 아기·성체 (한 장에서 잘라 노랑·붉은 번짐 정리, 같은 배율, 512) |
| 2026-11-18 | pet_pegasus_awake | 전설 펫 페가수스 각성 모습 (성체 편집, 성체와 같은 자리·배율, 512) |
| 2026-11-18 | pet_behemoth_awake, pet_nightmare_awake, pet_leviathan_awake, pet_dragon_awake, pet_unicorn_awake | 전설 펫 각성 모습 5종 (성체 편집, 번짐·빛무리 정리, 발밑을 성체와 같은 바닥선 496에 맞춤, 512) |
| 2026-11-18 | pet_map_{pegasus,behemoth,nightmare,leviathan,dragon,unicorn} | 전설 펫 지도 메달 6종 (금테·날개·왕관, 한 장에서 잘라 같은 크기, 512 → 개발이 128로) |
| 2026-11-18 | job_warrior(다시), job_archer, job_mage, job_priest, job_rogue, job_knight | 직업 개편 전투 직업 문장 6 (빨강 바탕, #249, 한 장에서 잘라 지금 문장과 같은 크기, 512) |
| 2026-11-18 | job_explorer, job_pilgrim, job_archaeologist, job_adventurer (다시) | 직업 개편 히든 직업 문장 4 (보라 바탕, #249, 넓은 보라 빛무리 정리, 지금 문장과 같은 크기, 512) |
| 2026-11-18 | skill_cleave, skill_warCry, skill_ironWall, skill_lastStand, skill_rapidShot, skill_trapArrow, skill_windArrow, skill_starfallArrow, skill_elementBolt | 직업 개편 스킬 아이콘 9 (전사 4·궁수 4·마법사 1, #249, 붉은 얼룩 정리, 지금 스킬과 같은 크기, 512) |
| 2026-11-18 | skill_manaShield, skill_elementBurst, skill_grandMagic, skill_aegis, skill_purify, skill_holyLight, skill_miracle, skill_ambush, skill_steal | 직업 개편 스킬 아이콘 9 (마법사 3·사제 4·도적 2, #249, 노랑·분홍 번짐 정리, 지금 스킬과 같은 크기, 512) |
| 2026-11-18 | skill_poisonBlade, skill_smokeBomb, skill_shadowFlurry, skill_shieldBash, skill_guard, skill_taunt, skill_lanceCharge, skill_paladinOath, skill_anvilDrop | 직업 개편 스킬 아이콘 9 (도적 3·기사 5·대장장이 1, #249, 노랑·분홍 번짐 정리, 지금 스킬과 같은 크기, 512) |
| 2026-11-18 | skill_acidFlask, skill_pollenCloud, skill_dazzleLens, skill_scaleWeight, skill_whistleSignal | 직업 개편 생산 직업 스킬 아이콘 5 (#249, 노랑 번짐 정리, 지금 스킬과 같은 크기, 512) |
| 2026-11-18 | title_pair_{weaponsmith,runesmith,jeweler,potionMerchant,peddler,beastKnight} | 직업 개편 특별 짝 칭호 6 (금 고리 두 개 「짝」 표시, #249, 지금 칭호와 같은 크기, 512) |
| 2026-11-18 | title_pair_{pathfinder,paladin,nightThief,ranger} | 직업 개편 특별 짝 칭호 4 (#249, 지금 칭호와 같은 크기, 512) |
| 2026-11-18 | weapon_bow | 직업 개편 활 (내 무기·기본 활 겸용, #249, 지금 weapon_sword·weapon_staff와 같은 512×1024 칸·같은 높이로 세움) |
| 2026-11-18 | fx_arrow | 직업 개편 쏘는 화살 (전투 연출, 오른쪽을 향함, 꼬리 잔상 포함, #249, 256×64) |
| 2026-11-18 | item_jobToken | 직업 개편 전직의 증표 (두 갈래 길·별 문양 금패 + 붉은 끈, #249, 512) |
| 2026-11-18 | village_guildhall_1 | 4막 길드 회관 ★1 (등불 회관, 남색·금 깃발, 둘레 꾸미기 자리 4곳, #246, 다른 건물과 같은 크기·바닥 위치, 512) |
| 2026-11-18 | village_guildhall_2 | 4막 길드 회관 ★2 (★1 편집, 2층·발코니·창고, #246, ★1과 같은 바닥 너비·위치, 512) |
| 2026-11-18 | village_guildhall_3 | 4막 길드 회관 ★3 (★2 편집, 훈련소 마당·허수아비·무기 걸이, 검은 바탕 제거, #246, ★2와 같은 바닥 너비·위치, 512) |
| 2026-11-18 | village_guildhall_4 | 4막 길드 회관 ★4 (★3 편집, 큰 깃대·금 장식, 종탑 빛무리 정리, #246, ★3과 같은 바닥 너비·위치, 512) |
| 2026-11-18 | bg_guildhall | 4막 길드 회관 안 (길드 화면 바탕, 아래쪽 빈 바닥, #246, 1024) |
| 2026-11-18 | monster_raidGiant, monster_raidDragon, monster_raidLich, monster_raidTortoise | 4막 길드 레이드 보스 4 (#246, 한 장에서 잘라 칸을 꽉 채움, 512) |
| 2026-11-18 | mat_giantLight, mat_ancientScale, mat_lichRelic, mat_tortoiseShell, item_lanternSeal, item_guildCharter | 4막 레이드 재료 4 · 등불 인장 · 길드 창설 증서 (#246, 한 장에서 잘라 냄, 512) |
| 2026-11-18 | equip_lanternWeapon/Head/Body/Hands/Feet/Acc | 4막 길드 세트 「등불 수호단」 6부위 (남색·금·등불 문양, 빛 번짐 없음, #246, 512) |
| 2026-11-18 | deco_nameplate, deco_lanternString, deco_flowerbed, deco_fountain, deco_petStatue, deco_campfire | 4막 회관 꾸미기 6 (현판은 빈 판, 노랑 번짐 정리, 바닥을 아래(496)에 맞춤, #246, 512) |
| 2026-11-18 | title_raidGiant, title_raidDragon, title_raidLich, title_raidTortoise, title_lanternOath | 4막 레이드 칭호 4 · 「등불의 맹세」 (꼭대기 작은 등불 표시, #246, 지금 칭호와 같은 크기, 512 → 개발이 160으로) |
| 2026-11-18 | deco_springTree, deco_summerChime, deco_autumnLeaves, deco_winterSnowman | 4막 회관 꾸미기 계절 4 (번짐 정리, 바닥을 아래(496)에 맞춤, #246, 512) |
| 2026-11-18 | map_erbard | 5막 대륙 지도 「에르바르드」 (1024×1536, #247). 빈 터 대략 중심(x,y): 왕성 (515,690) · 솔레안 평원 (385,158)(528,205)(645,180)(625,240)(490,300) · 실바렌 숲 (287,319)(152,382)(323,406)(128,475)(250,480)(111,584) · 도르마크 산맥 (732,395)(936,440)(735,477)(885,540)(942,605) · 모르테인 늪 (285,828)(160,868)(358,952)(140,1000)(289,1068) · 이그나르 화산 (830,853)(700,878)(615,948)(820,978)(680,1038). 그려진 빈 터는 27곳이라 지방마다 1곳씩은 길가 등에 얹어야 함 |
| 2026-11-18 | icon_estate_{light,metal,earth,dark,fire,royal} | 5막 영지 아이콘 6 (깃대 비움, 한 장에서 같은 배율로 잘라 바닥(496) 맞춤 — 왕성이 가장 큼, #247, 512 → 개발이 48~64로) |
| 2026-11-18 | monster_wildGriffin, monster_wildTroll, monster_wildBoar, monster_wildLizardman, monster_wildLavaGolem | 5막 야생 수비대 바깥(보통) 5 (#247, 붉은 번짐 정리, 512) |
| 2026-11-18 | monster_wildKnightCaptain, monster_wildRuneGolem, monster_wildElfArcher, monster_wildBanshee, monster_wildDragonCaptain | 5막 야생 수비대 안쪽(강함) 5 (옛 왕국 왕관 문장 깃발, #247, 색 번짐 정리, 512) |
| 2026-11-18 | item_siegeTicket | 5막 공성권 (금 나팔 + 성탑 밀랍 인장 쪽지, #247, 512) |
| 2026-11-18 | title_erbardCrown, title_pioneer | 5막 칭호 「에르바르드의 왕관」·「에르바르드의 개척자」 (꼭대기 작은 성탑 표시, #247, 512 → 개발이 160으로) |
| 2026-11-18 | scene_erbard_arrive | 5막 1장 에르바르드 도착 컷신 (빛의 다리 끝에서 대륙을 내려다봄, 왕성 위 검은 등불 깃발, #247, 852×1846) |
| 2026-11-18 | chest_royal | 5막 왕성 특별 상자 (남색·금 + 왕관, 붉은 번짐 정리, #247, 512) |
| 2026-11-18 | flag_emb_blackLantern | 5막 흑등 연맹 깃발 문양 (흰 유리·금테 등불 + 초승달 그림자, 둘레 반짝이 제거, 게임이 검게 칠함, #247, 512) |
| 2026-11-18 | flag_mark_crown | 5막 왕성 길드 깃발 위 왕관 표시 (금 왕관·푸른 보석, #247, 256) |
| 2026-11-18 | bg_siege | 5막 공성전 전투 배경 (성문 앞 돌바닥, 성벽 깃발·사다리, 노을, 아래쪽 비어 있음, #247, 1024) |
| 2026-11-18 | flag_emb_blackLantern (다시) | 5막 흑등 연맹 깃발 문양 다시 — 용 발톱이 쥔 육각 등불·초승달 창, 흰 몸체+얇은 금 테두리 (파티 flag_emb_lantern과 다른 모양, #247, 512) |
| 2026-11-18 | map_erbard (다시) | 5막 대륙 지도 정사각 3072×3072 (원본 1254를 키움, #247). 빈 터 대략 중심(x,y): 왕성 앞 (1531,1568) · 솔레안 평원(위) (1024,314)(1499,294)(2043,331)(1225,527)(1813,527)(1529,730) · 실바렌 숲(왼쪽 위) (735,730)(343,931)(990,968)(343,1244)(862,1254) · 도르마크 산맥(오른쪽 위) (2313,747)(2731,936)(2134,973)(2739,1252)(2246,1271) · 모르테인 늪(왼쪽 아래) (328,1796)(872,1801)(1058,2050)(372,2080)(960,2313)(551,2374) · 이그나르 화산(오른쪽 아래) (2131,1818)(2719,1793)(2009,2041)(2670,2087)(2131,2303)(2548,2376). 그려진 빈 터 29곳 — 숲·산맥이 5곳씩이라 각 1곳은 길가 등에 얹어야 함 |
| 2026-11-18 | map_erbard (빈 터 추가) | 5막 대륙 지도 정사각 3072×3072, 빈 터 정확히 31곳 (앞 줄 좌표를 대신함, #247). 빈 터 대략 중심(x,y): 왕성 앞 (1538,1568) · 솔레안 평원(위) (992,314)(1507,299)(2063,331)(1254,527)(1818,527)(1534,730) · 실바렌 숲(왼쪽 위) (740,735)(360,936)(980,970)(870,1127)(343,1244)(857,1257) · 도르마크 산맥(오른쪽 위) (2298,747)(2474,857)(2727,936)(2134,973)(2234,1271)(2734,1252) · 모르테인 늪(왼쪽 아래) (326,1796)(872,1801)(1058,2050)(372,2080)(968,2313)(551,2374) · 이그나르 화산(오른쪽 아래) (2139,1823)(2727,1793)(1999,2058)(2680,2082)(2136,2313)(2538,2376) |
| 2026-11-18 | monster_blackGuard, monster_blackCaptain | 5막 흑등 연맹 수비대 용병·지휘관 (흑등 문양, 한 장에서 같은 배율로 잘라 발 맞춤 — 지휘관이 큼, #247, 512) |
| 2026-11-18 | item_keyShard, icon_footprint, icon_rallyFlag, icon_siegeRam, icon_wallRepair | 걸음 보상(열쇠 조각·발자국, #252)·공성전 아이콘 3(집결 깃발·공성 망치·성벽 보수, #251), 넓은 빛무리·붉은 번짐 정리, 512 |
| 2026-11-18 | title_vanguard | 공성전 칭호 「선봉장」 (붉은 메달·칼·작은 깃발, 꼭대기 성탑 표시, #251, 512 → 개발이 160으로) |
| 2026-11-18 | bg_siegeFinal | 공성전 배경 · 최후의 6시간 (bg_siege 편집 — 같은 구도에 붉은 노을·횃불·불티, #251, 1024) |
| 2026-11-18 | scene_siegeResult | 공성전 결과 장면 (새벽, 흑등 깃발이 찢겨 날아가고 빈 흰 새 깃발이 오름 — 게임이 길드 깃발 색·문양을 얹음, #251, 852×1846) |
| 2026-11-18 | fx_guard | 막기 방어막 (반투명 푸른 육각 방어막 + 금빛 룬 고리, 가운데 투명, #256, 768) |
| 2026-11-18 | fac_wall, fac_tower, fac_market, fac_light, fac_metal, fac_earth, fac_dark, fac_fire | 영지 시설 8 (공통 3 + 지방 특산 5, 한 장에서 같은 배율로 잘라 바닥(496) 맞춤, 붉은 번짐 정리, #255, 512) |
| 2026-11-18 | mat_lightRelic, mat_metalOre, mat_earthWood, mat_darkCrystal, mat_fireStone | 영지 특산물 5 (성스러운 백합·청동 광석·엘프 고목 가지·안개 결정·용암석, 노랑·붉은 번짐 정리, #255, 512) |
| 2026-11-18 | fx_guardHit | 막았을 때 번쩍임 (방어막 위 금빛 충격·푸른 파문, fx_guard와 같은 테두리·크기, #256, 768) |
| 2026-11-18 | policy_defense, policy_plenty, policy_trade | 영주의 정책 3 (같은 금테 메달, 색·상징만 다름, 같은 배율, #255, 512) |
| 2026-11-18 | fx_guardBreak | 막기 실패 · 방어막이 유리처럼 깨져 흩어짐 (금빛 룬 조각 포함, #256, 768) |
| 2026-11-19 | bg_hatchery | 알 부화장 판 바탕 (짚 바닥·나무 들보·가운데 등불·양옆 선반, 아래 가운데 둥지 자리 비움, #285, 1024×640) |
| 2026-11-19 | nest_back | 알 부화장 둥지 뒤쪽 (짚·잔가지 테 + 안쪽 깃털, 앞 테 없음, 원본 캔버스 그대로 줄여 nest_front와 겹치면 맞도록, #285, 256) |
| 2026-11-19 | nest_front | 알 부화장 둥지 앞쪽 테 (nest_back과 같은 256 캔버스·같은 자리 — 겹치면 둥지가 닫힘, 사이에 알을 끼움. 원본보다 위로 올리고 가로 6% 넓혀 맞춤, #285, 256) |
| 2026-11-19 | monster_sphinx, monster_doppelganger, monster_clockworkKnight, monster_arachne, monster_centaur, monster_owlbear, monster_kelpie, monster_naga, monster_roc | Lv.50 지도 몬스터 9 (한 장에서 잘라 냄, 색 번짐 정리, #281, 512) |
| 2026-11-19 | monster_sphinx … monster_roc (9장, 다시) | Lv.50 지도 몬스터 9 새 판으로 덮어씀 (외곽선 더 굵고 번짐 적음, #281, 512) |
| 2026-11-19 | spirit_plant_farewell | 풀 정령 이별 얼굴(눈물 미소), 512, 기본 그림과 같은 크기·위치 |
| 2026-11-19 | spirit_fire_farewell | 불 정령 이별 얼굴(눈물 미소), 512, 떠다니는 불꽃 조각·후광 제거 |
| 2026-11-19 | spirit_water_farewell | 물 정령 이별 얼굴(눈물 미소), 512, 떠다니는 거품·반짝이·후광 제거 |
| 2026-11-19 | monster_dullahan, monster_werewolf, monster_deathKnight, monster_basilisk | Lv.50 지도 몬스터 4종, 512 (2×2 한 장에서 잘라냄) |
| 2026-11-19 | mat_gortRoot, mat_silvaFern, mat_mireaGrass, mat_zephiraLeaf, mat_noctiGrass, mat_mandragora | 약초 재료 6종, 512 (3×2 한 장에서 잘라냄) |
| 2026-11-19 | village_market_2 | 거래소 ★2(옆 노점 추가), 512, 기본 거래소와 폭·바닥선 맞춤 |
| 2026-11-19 | bg_in_smithy | 대장간 안 배경(화덕·모루·무기 벽), 1024×1792 |
| 2026-11-19 | village_market_3 | 거래소 ★3(노점 세 칸·양쪽 깃발·큰 저울), 512, 기본 거래소와 폭·바닥선 맞춤 |
| 2026-11-19 | bg_in_inn | 여관 안 배경(벽난로·안락의자·객실 문·열쇠판), 1024×1792 |
| 2026-11-19 | bg_in_alchemy | 연금술 공방 안 배경(끓는 가마솥·물약 선반·증류기·말린 약초), 1024×1792 |
| 2026-11-19 | bg_in_shop | 상점 안 배경(계산대·저울·물약·가방·자루), 1024×1792 |
| 2026-11-19 | bg_in_tavern | 주점 안 배경(술통 바·잔 선반·게시판·탁자·류트), 1024×1792 |
| 2026-11-19 | bg_in_guild | 길드 안 배경(직업 문장 깃발·큰 문·작업대·훈련 인형), 1024×1792 |
| 2026-11-19 | icon_chat, icon_friends, icon_settings | 위쪽 버튼 아이콘 3종, 512 (그림에 딸려 온 남색 동그라미·금테는 떼어 냄 — 게임 버튼이 따로 그림) |
| 2026-11-19 | alchemy_cauldron | 연금술 큰 가마솥(빈 상태, 장작불 위), 768 |
| 2026-11-19 | alchemy_still, alchemy_altar | 연금술 증류기(가공) · 변환 제단(변환), 768, 같은 비율·바닥선 |
| 2026-11-19 | fx_splash | 재료가 빠질 때 튀는 물보라(흰·회색, 게임이 색을 입힘), 512, 뿌연 흰 번짐 제거 |
| 2026-11-19 | alchemy_brew | 가마솥 입구에 겹치는 끓는 물(흰·회색, 게임이 색을 입힘)+김, 768, alchemy_cauldron과 같은 캔버스·위치 |
| 2026-11-19 | pet_golem_battle, pet_mimic_battle, pet_owl_battle, pet_toad_battle | 펫 전투용(오른쪽을 봄) 4종, 512, 바닥선 496 |
| 2026-11-19 | pet_homunculus_battle, spirit_plant_battle, spirit_water_battle, spirit_fire_battle | 펫·정령 전투용(오른쪽을 봄) 4종, 512 (호문쿨루스 바닥선 496, 정령은 가운데 · 후광·떠다니는 조각 제거) |
| 2026-11-19 | ally_lian_attack | 리안 공격 6칸 판(준비→힘 모으기→휘두름→베기+금빛 궤적→마무리→준비), 3840×640, 칸 640·발 바닥선 620 |
| 2026-11-19 | ally_garen_attack | 가렌 공격 6칸 판(지팡이 짚고 외치며 내려베기+붉은 기운), 3840×640, 칸 640·발 바닥선 맞춤 |
| 2026-11-19 | ally_nia_attack | 니아 공격 6칸 판(몸 낮춤→튀어나가며 X자 단검 베기), 3840×640, 붉은 테두리 얼룩 제거 |
| 2026-11-19 | ally_barkan_attack | 바르칸 공격 6칸 판(도끼 들어 내려찍기+불티·돌 조각), 3840×640, 발 바닥선 맞춤 |
| 2026-11-19 | ally_popo_attack | 포포 공격 6칸 판(지팡이 돌려 잎·꽃잎 마법), 3840×640, 노란 후광 띠 제거 |
| 2026-11-19 | ally_sera_attack | 세라 공격 6칸 판(방패 돌진→푸른 파동→검 찌르기), 3840×640, 붉은·노란 테두리 얼룩 제거 |
| 2026-11-19 | ally_teo_attack | 테오 공격 6칸 판(창 당겼다 길게 찌르기+금빛 빛줄기), 3840×640, 붙어 있던 3·4칸 분리 |
| 2026-11-19 | hero_base_male | 새 남자 주인공 기본(현대 옷·맨손, 대표가 고른 그림), 768×1024, 발 바닥선 1004 |
| 2026-11-19 | hero_base_female | 새 여자 주인공 기본(현대 옷·맨손, 대표가 고른 그림), 768×1024, 발 바닥선 1004 |
| 2026-11-19 | portrait_male | 새 남자 주인공 얼굴(손 인사), 768, 손가락 노란 테두리 얼룩 제거 |
| 2026-11-19 | hero_stand_tired_male | 새 남자 주인공 지친 모습(무릎 짚고 숨 고르기), 768×1024, 기본 그림과 같은 크기·바닥선 |
| 2026-11-19 | hero_idle_male | 새 남자 주인공 전투 대기(주먹 자세, 오른쪽), 768×1024, 기본 그림과 같은 크기·바닥선 |
| 2026-11-19 | hero_attack_male | 새 남자 주인공 주먹 공격 6칸 판, 3840×800(칸 640×800), 발 바닥선 780, 충격 표시는 4칸 주먹 앞 |
| 2026-11-19 | hero_victory_male | 새 남자 주인공 승리(주먹 치켜들고 점프), 768×1024, 기본 그림과 같은 크기 · 점프라 발끝 975 |
| 2026-11-19 | hero_tired_male | 새 남자 주인공 전투에서 쓰러짐(주저앉아 어지러움·별), 768×1024, 기본 그림과 같은 크기·바닥선 |
| 2026-11-19 | hero_stand_tired_female | 새 여자 주인공 지친 모습(무릎 짚고 숨 고르기), 768×1024, 남자 그림과 같은 크기·바닥선 |
| 2026-11-19 | hero_idle_female | 새 여자 주인공 전투 대기(주먹 자세, 오른쪽), 768×1024, 남자 그림과 같은 크기·바닥선 |
| 2026-11-19 | hero_attack_female | 새 여자 주인공 주먹 공격 6칸 판, 3840×800(칸 640×800), 발 바닥선 780, 충격 표시는 4칸 주먹 앞 |
| 2026-11-19 | hero_victory_female | 새 여자 주인공 승리(주먹 치켜들고 점프), 768×1024, 남자 승리와 같은 크기 · 발끝 975 |
| 2026-11-19 | hero_tired_female | 새 여자 주인공 전투에서 쓰러짐(주저앉아 어지러움·별), 768×1024, 남자 그림과 같은 크기·바닥선 |
| 2026-11-19 | portrait_female | 새 여자 주인공 얼굴(손 인사), 768, 남자 얼굴과 같은 크기 |
| 2026-11-19 | hero_warrior_male | 주인공 전사 서기 · 남(후드티 위 어깨 갑옷·가죽 가슴받이·빨간 목도리, 한손검), 768×1024, 다른 주인공 그림과 같은 크기·바닥선 |
| 2026-11-19 | hero_warrior_attack_male | 주인공 전사 공격 6칸 · 남(검 가로 베기+하얀 궤적), 3840×800, 넷째 칸 망토·궤적이 칸에 들어가게 주먹 공격보다 약 12% 작게 |
| 2026-11-19 | hero_warrior_female | 주인공 전사 서기 · 여, 768×1024, 남자 전사와 같은 크기·바닥선 |
| 2026-11-19 | hero_warrior_attack_female | 주인공 전사 공격 6칸 · 여(검 가로 베기+하얀 궤적), 3840×800, 남자 전사 공격과 같은 크기 |
| 2026-11-19 | hero_archer_male | 주인공 궁수 서기 · 남(초록 두건 망토·화살통·장궁), 768×1024, 같은 크기·바닥선 |
| 2026-11-19 | hero_archer_attack_male | 주인공 궁수 공격 6칸 · 남(시위 당겨 쏘기, 넷째 칸에 날아가는 화살), 3840×800 |
| 2026-11-19 | hero_archer_female | 주인공 궁수 서기 · 여, 768×1024, 남자 궁수와 같은 크기·바닥선 |
| 2026-11-19 | hero_archer_attack_female | 주인공 궁수 공격 6칸 · 여(시위 당겨 쏘기, 넷째 칸 화살), 3840×800, 붉은·노란 테두리 얼룩 제거 |
| 2026-11-19 | hero_mage_male | 주인공 마법사 서기 · 남(보라 모자·긴 겉옷, 수정 지팡이), 768×1024, 같은 크기·바닥선 |
| 2026-11-19 | hero_mage_attack_male | 주인공 마법사 공격 6칸 · 남(지팡이 내밀어 푸른 마법 구슬), 3840×800, 넷째 칸 겉옷·마법진이 넓어 다른 직업보다 조금 작게 |
| 2026-11-19 | hero_mage_female | 주인공 마법사 서기 · 여, 768×1024, 남자 마법사와 같은 크기·바닥선 |
| 2026-11-19 | hero_mage_attack_female | 주인공 마법사 공격 6칸 · 여(지팡이 휘둘러 푸른 마법 구슬), 3840×800 |
| 2026-11-19 | hero_rogue_male | 주인공 도적 서기 · 남(두건·입 가린 목도리·빨간 망토, 양손 단검), 768×1024, 같은 크기·바닥선 |
| 2026-11-19 | hero_rogue_attack_male | 주인공 도적 공격 6칸 · 남(낮게 달려들어 X자 두 번 베기), 3840×800 |
| 2026-11-19 | hero_rogue_female | 주인공 도적 서기 · 여, 768×1024, 남자 도적과 같은 크기·바닥선 |
| 2026-11-19 | hero_rogue_attack_female | 주인공 도적 공격 6칸 · 여(낮게 달려들어 X자 두 번 베기), 3840×800 |
| 2026-11-19 | hero_priest_male | 주인공 사제 서기 · 남(흰·금 망토와 띠, 해 문양 지팡이), 768×1024, 지팡이 둘레 붉은 얼룩 제거 |
| 2026-11-19 | hero_priest_attack_male | 주인공 사제 공격 6칸 · 남(지팡이 들어 금빛 빛 터뜨리기), 3840×800, 붉은·노란 테두리 얼룩과 흩어진 점 제거 |
| 2026-11-19 | hero_priest_female | 주인공 사제 서기 · 여, 768×1024, 남자 사제와 같은 크기·바닥선 |
| 2026-11-19 | hero_priest_attack_female | 주인공 사제 공격 6칸 · 여(지팡이 휘둘러 금빛 빛), 3840×800, 넓은 노란 번짐·붉은 얼룩 제거 |
| 2026-11-19 | hero_knight_male | 주인공 기사 서기 · 남(은 갑옷·파란 망토, 별 문양 방패·한손검), 768×1024, 같은 크기·바닥선 |
| 2026-11-19 | hero_knight_attack_male | 주인공 기사 공격 6칸 · 남(방패 밀치기+푸른 파동→검 찌르기), 3840×800, 뿌연 회색 배경 띠 제거 |
| 2026-11-19 | hero_knight_female | 주인공 기사 서기 · 여, 768×1024, 남자 기사와 같은 크기·바닥선 |
| 2026-11-19 | hero_knight_attack_female | 주인공 기사 공격 6칸 · 여(방패 밀치기+푸른 파동→검 찌르기), 3840×800 |
| 2026-11-20 | title_npcMarta, title_npcMina, title_npcDorgun, title_npcEliel, title_npcHart, title_npcSera | 마을 사람 마지막 부탁 칭호 배지 6종, 512 (3×2 한 장에서 잘라냄) |
| 2026-11-20 | title_npcLumi, title_npcGaren, title_guildLegend, title_basiliskSlayer, title_wayfarers, title_firstHello | 칭호 배지 6종, 512 (3×2 한 장에서 잘라냄) |
| 2026-11-20 | title_pairWeaponsmith, title_pairRunesmith, title_pairJeweler, title_pairPotionMerchant, title_pairPeddler, title_pairBeastKnight | 숨은 직업 짝 칭호 배지 6종, 512 (3×2 한 장에서 잘라냄) |
| 2026-11-20 | pet_egg_rare, pet_egg_hero, pet_egg_legend | 등급별 알 3종(희귀·영웅·전설), 512, 같은 비율 · 전설 알 넓은 빛 번짐·떠다니는 반짝이 제거(얇은 테두리 빛만) |
| 2026-11-20 | title_pairPathfinder, title_pairPaladin, title_pairNightThief, title_pairRanger | 숨은 직업 짝 칭호 배지 4종, 512 — 칭호 배지 22종 완료 |
| 2026-11-20 | equip_monGoblinDagger, equip_monKoboldHelm, equip_monOrcAxe, equip_monLizardNecklace, equip_monSkeletonBoots, equip_monOgreBracers, equip_monArmorChest | 인간형 몬스터 전용 장비 7종(위 줄 몬스터), 512 (4×2 한 장에서 잘라냄) |
| 2026-11-20 | equip_monDoppelHood, equip_monClockSpear, equip_monCentaurBow, equip_monNagaBangle, equip_monDullahanCloak, equip_monDeathSword | 인간형 몬스터 전용 장비 6종(아래 줄 몬스터), 512 — 전용 장비 13종 완료 |
| 2026-11-20 | ending_02_face_to_face | 결말 마주 봄 — 옛 주인공(배낭·등불)을 새 주인공(남, 후드티·청바지·맨손)으로 편집해 덮어씀, 852×1846 |
| 2026-11-20 | ending_02_face_to_face_female | 결말 마주 봄 · 여(새 주인공, 포니테일), 852×1846 — 받은 그림 비율(934×1684)이 달라 양옆을 조금 잘라 맞춤 |
| 2026-11-20 | farewell_01_gate | 이별 문 앞 — 망토 입은 옛 주인공을 새 주인공(남, 후드티·청바지)으로 편집해 덮어씀, 852×1846 |
| 2026-11-20 | farewell_01_gate_female | 이별 문 앞 · 여(새 주인공, 포니테일), 852×1846 |
| 2026-11-20 | farewell_02_lookup | 이별 올려다봄 — 새 주인공(남, 빛 구슬을 든 손)으로 편집해 덮어씀, 852×1846 |
| 2026-11-20 | farewell_02_lookup_female | 이별 올려다봄 · 여(새 주인공, 빛 구슬을 든 손), 852×1846 |
| 2026-11-20 | farewell_05_eyes | 이별 닫힌 문 — 새 주인공(남) 뒷모습으로 편집해 덮어씀, 852×1846 |
| 2026-11-20 | farewell_05_eyes_female | 이별 닫힌 문 · 여(새 주인공, 포니테일), 852×1846 |
| 2026-11-20 | ending_03_promise | 결말 약속(악수) — 왼쪽 소매를 남색 후드티 소매로 편집해 덮어씀, 852×1846 |
| 2026-11-20 | farewell_04_light | 이별 · 빛을 받는 손 — 주인공 소매를 남색 후드티로 고친 편집본 (덮어씀) |
| 2026-11-20 | skill_drill, skill_track, skill_manaSense, skill_firstAid, skill_lockpick, skill_runTogether | 생활 스킬 아이콘 묶음 1 (512, 테두리 없음, 넓은 빛 번짐 제거) |
| 2026-11-20 | skill_focusForge, skill_masterTouch, skill_quickRepair, skill_masterBlade, skill_runeCarve, skill_quickBrew | 생활 스킬 아이콘 묶음 2 (512, 테두리 없음, 넓은 빛 번짐 제거) |
| 2026-11-20 | skill_recipeHunch, skill_instantBrew, skill_specialSale, skill_bountyTouch, skill_harvestSense, skill_rootPull | 생활 스킬 아이콘 묶음 3 (512, 테두리 없음, 넓은 빛 번짐 제거) |
| 2026-11-20 | skill_sproutCare, skill_trueEye, skill_wideView, skill_memoryRead, skill_polish, skill_bargain | 생활 스킬 아이콘 묶음 4 (512, 테두리 없음, 넓은 빛 번짐 제거) |
| 2026-11-20 | skill_knack, skill_regular, skill_bigPack, skill_cheer, skill_snackPouch, skill_eggWarm | 생활 스킬 아이콘 묶음 5 (512, 테두리 없음, 넓은 빛 번짐 제거) — 생활 스킬 30장 완료 |
| 2026-11-20 | hero_rogue_male | 주인공 도적 서기 · 남 다시(후드 벗음, 회색 목도리는 목에만, 양손 단검), 768×1024, 같은 크기·바닥선 (덮어씀) |
| 2026-11-20 | hero_rogue_female | 주인공 도적 서기 · 여 다시(후드 벗음, 회색 목도리는 목에만, 양손 단검), 768×1024, 같은 크기·바닥선 (덮어씀) |
| 2026-11-20 | hero_rogue_attack_male | 주인공 도적 공격 · 남 다시(낮게 달려들어 X자 두 번 베기), 6칸 3840×800 (덮어씀) |
| 2026-11-20 | hero_rogue_attack_female | 주인공 도적 공격 · 여 다시(낮게 달려들어 X자 두 번 베기), 6칸 3840×800 (덮어씀) — 도적 다시 4장 완료 |
| 2026-11-20 | scene_erbard_arrive | 5막 에르바르드 도착 — 다리 위 작은 주인공을 후드 쓴 실루엣으로 편집 (덮어씀) |
| 2026-11-20 | scene_highland_first | 고원 첫발 — 거리 위 주인공을 후드 쓴 작은 뒷모습으로 편집 (덮어씀) |
| 2026-11-20 | scene_meet_lights | 등불들과 만남 — 돌길 위 주인공을 후드 쓴 작은 뒷모습으로 편집 (덮어씀) |
| 2026-11-20 | scene_act3_fivelamps | 3막 다섯 등불 — 절벽 위 주인공을 후드 쓴 작은 뒷모습으로 편집 (덮어씀) — 옛 주인공 장면 편집 완료 |
| 2026-11-20 | hero_blacksmith_male | 주인공 대장장이 서기 · 남(후드티 위 가죽 앞치마, 이마 보안경, 가죽 장갑, 대장 망치), 768×1024, 같은 크기·바닥선 |
| 2026-11-20 | hero_blacksmith_female | 주인공 대장장이 서기 · 여(가죽 앞치마, 이마 보안경, 가죽 장갑, 대장 망치), 768×1024 — 비율이 다른 직업보다 짧고 머리가 큼(다시 뽑으면 교체) |
| 2026-11-20 | hero_blacksmith_attack_female | 주인공 대장장이 공격 · 여(망치 머리 위로 들어 내려찍기, 달군 망치·불티), 6칸 3840×800, 도적 공격과 같은 키 |
| 2026-11-20 | hero_blacksmith_attack_male | 주인공 대장장이 공격 · 남(망치 내려찍기, 달군 망치·불티), 6칸 3840×800 |
| 2026-11-20 | hero_alchemist_male | 주인공 연금술사 서기 · 남(올리브 코트, 물약 띠, 목에 건 고글, 둥근 플라스크), 768×1024, 같은 크기·바닥선 |
| 2026-11-20 | hero_alchemist_female | 주인공 연금술사 서기 · 여(올리브 코트, 물약 띠, 목에 건 고글, 둥근 플라스크), 768×1024, 같은 바닥선 |
| 2026-11-20 | hero_alchemist_attack_female | 주인공 연금술사 공격 · 여(플라스크 던져 초록·보라 물약 터짐), 6칸 3840×800 |
| 2026-11-20 | hero_alchemist_attack_male | 주인공 연금술사 공격 · 남(플라스크 던져 초록·보라 물약 터짐), 6칸 3840×800 — 연금술사 4장 완료 |
| 2026-11-20 | hero_herbalist_male | 주인공 채집가 서기 · 남(밀짚모자, 잎무늬 조끼, 등 바구니, 낫), 768×1024, 같은 크기·바닥선 |
| 2026-11-20 | hero_herbalist_attack_male | 주인공 채집가 공격 · 남(낫 휘둘러 가시 덩굴·잎 날림), 6칸 3840×800 |
| 2026-11-20 | hero_herbalist_female | 주인공 채집가 서기 · 여(밀짚모자, 잎무늬 조끼, 등 바구니, 낫), 768×1024, 같은 바닥선 |
| 2026-11-20 | hero_herbalist_attack_female | 주인공 채집가 공격 · 여(낫 휘둘러 가시 덩굴·잎 날림), 6칸 3840×800 — 채집가 4장 완료 |
| 2026-11-20 | hero_appraiser_male | 주인공 감정사 서기 · 남(외눈 안경, 짙은 녹색 조끼, 보석 주머니, 돋보기), 768×1024, 같은 크기·바닥선 |
| 2026-11-20 | hero_appraiser_attack_male | 주인공 감정사 공격 · 남(돋보기로 빛을 모아 쏘는 광선), 6칸 3840×800, 노랑·빨강 번짐 제거 |
| 2026-11-20 | hero_appraiser_female | 주인공 감정사 서기 · 여(외눈 안경, 짙은 녹색 조끼, 보석 주머니, 돋보기), 768×1024, 같은 크기·바닥선 |
| 2026-11-20 | hero_appraiser_attack_female | 주인공 감정사 공격 · 여(돋보기로 빛을 모아 쏘는 광선), 6칸 3840×800 — 감정사 4장 완료 |
| 2026-11-20 | hero_merchant_male | 주인공 상인 서기 · 남(깃털 모자, 붉은 긴 코트, 돈주머니·저울, 금화), 768×1024, 같은 크기·바닥선 |
| 2026-11-20 | hero_merchant_attack_male | 주인공 상인 공격 · 남(금화 튕겨 날리기), 6칸 3840×800 — 검은 배경을 지워 투명하게 만듦 |
| 2026-11-20 | hero_merchant_female | 주인공 상인 서기 · 여(깃털 모자, 붉은 긴 코트, 돈주머니·저울, 금화), 768×1024, 같은 바닥선 |
| 2026-11-20 | hero_merchant_attack_female | 주인공 상인 공격 · 여(금화 튕겨 날리기), 6칸 3840×800 — 상인 4장 완료 |
| 2026-11-20 | hero_tamer_male | 주인공 조련사 서기 · 남(털깃 가죽 조끼, 호루라기, 깃털 지팡이, 팔 위 매), 768×1024, 같은 크기·바닥선 |
| 2026-11-20 | hero_tamer_attack_male | 주인공 조련사 공격 · 남(호루라기 불고 지팡이 휘두르면 매가 날아가고 초록 발톱 자국), 6칸 3840×800 (다시 뽑아 교체) |
| 2026-11-20 | hero_tamer_female | 주인공 조련사 서기 · 여(털깃 가죽 조끼, 호루라기, 깃털 지팡이, 팔 위 매), 768×1024, 같은 크기·바닥선 |
| 2026-11-20 | hero_tamer_attack_female | 주인공 조련사 공격 · 여(호루라기 → 매가 날아올라 덮치며 초록 발톱 자국 → 공중에서 돌아와 내려앉음), 6칸 3840×800 — 생산 직업 주인공 24장 완료 |
| 2026-11-20 | title_pairSpellblade, title_pairSage | 새 특별 짝 칭호 배지 — 마검사(불꽃·번개 검, 붉은 리본) · 현자(책·돋보기·4속성 별, 보라 리본), 512 |
| 2026-11-20 | skill_spellbladeSlash, skill_sageStrike | 새 특별 짝 전용 스킬 — 마검 베기(불·물·잎 베기 궤적) · 현자의 일섬(돋보기 빛줄기·과녁), 512, 넓은 빛 번짐 제거 |
| 2026-11-22 | title_pair_spellblade, title_pair_sage | 숨은 이명 배지 마검사 · 현자 — 다른 배지처럼 위 고리 두 개 더한 편집본, 512 (같은 이름 덮어쓰기, 옛 title_pairSpellblade · title_pairSage는 안 쓰임) |
| 2026-11-23 | tile_sky_wind_1, tile_sky_wind_2, tile_sky_wind_3 | 하이랜드 쿼터뷰 땅 칸 · 구름 초원(바람) 1층 풀밭 / 2층 무너진 회랑 / 3층 대리석 제단, 512×384, 세 장 같은 크기 · 바닥선 |
| 2026-11-23 | tile_sky_thunder_1, tile_sky_thunder_2, tile_sky_thunder_3 | 하이랜드 쿼터뷰 땅 칸 · 뇌운 봉우리(번개) 1층 보랏빛 바위 / 2층 무너진 회랑 / 3층 대리석 제단, 512×384, 같은 크기 · 바닥선 |
| 2026-11-23 | tile_sky_light_1, tile_sky_light_2, tile_sky_light_3 | 하이랜드 쿼터뷰 땅 칸 · 햇살 정원(빛) 1층 꽃밭 돌길 / 2층 무너진 회랑 / 3층 대리석 제단, 512×384, 같은 크기 · 바닥선 |
| 2026-11-23 | tile_sky_ice_1, tile_sky_ice_2, tile_sky_ice_3 | 하이랜드 쿼터뷰 땅 칸 · 서리 성채(얼음) 1층 눈 · 얼음 · 고드름 / 2층 눈 덮인 회랑 / 3층 대리석 제단, 512×384, 같은 크기 · 바닥선 |
| 2026-11-23 | tile_sky_water_1, tile_sky_water_2, tile_sky_water_3 | 하이랜드 쿼터뷰 땅 칸 · 물의 섬(물) 1층 젖은 돌 · 웅덩이 · 흐르는 물 / 2층 무너진 회랑 / 3층 대리석 제단, 512×384, 같은 크기 · 바닥선 — 땅 칸 15장 완료 |
