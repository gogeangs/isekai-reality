# 아르카 전투 화면 — Unity 시험판

Flutter 전투 화면과 움직임 · 연출을 비교하려고 만든 Unity 2D 시험 프로젝트입니다.
전투 한 장면만 있습니다 (메뉴 · 저장 · 서버 · 광고 없음).

- Unity 6.3 LTS (6000.3.x) · URP 2D · C# · 외부 유료 에셋 없음
- 기존 Flutter 코드는 건드리지 않았습니다

## 여는 순서

1. **Unity Hub ▸ Add ▸ Add project from disk** → 이 폴더(`unity/ArcaBattle`)를 고릅니다.
   - 설치된 Unity 버전이 6000.3.28f1 과 다르면 Hub 가 버전을 바꿀지 묻습니다 → 가지고 있는 6000.3 (또는 6000.x) 로 열면 됩니다.
2. 처음 열 때는 그림 가져오기로 몇 분 걸립니다. 끝나면 스스로 아래를 해 둡니다 (Console 창에 `[Arca]` 로 시작하는 글이 뜸).
   - URP 2D 렌더러 만들고 켜기 (`Assets/Settings/`)
   - 세로 화면 · 2D 모드
   - 전투 장면 `Assets/Scenes/ArcaBattle.unity` 만들고 열기 (Play 는 항상 이 장면에서 시작)
3. **Game 창 화면 크기**: Game 탭 위쪽 `Free Aspect` ▸ `+` 로 `1170 × 2532`(아이폰) 과 `750 × 1334`(SE) 를 추가해 고릅니다.
4. **▶ Play** 를 누르면 바로 전투가 시작됩니다.

> 만약 장면이 안 열렸으면 메뉴 **Arca ▸ 전투 장면 열기**, 설정이 덜 됐으면 **Arca ▸ 처음 설정 다시 하기**.

## 수치 고치기

| 파일 | 내용 | 언제 반영 |
|---|---|---|
| `Assets/Resources/ArcaBattleConfig` | 주인공 · 몬스터 HP · 공격, 치명타, 강타 · 방어 · 펫, 동료 7명, 기본 모습 | 「다시 하기」 때 |
| `Assets/Resources/ArcaStageLayout` | 자리 · 크기, 숨쉬기, 공격 칸 시간, 흔들림, 살랑임 | **재생 중 바로** |

Project 창에서 파일을 누르면 Inspector(오른쪽 창)에서 숫자를 고칠 수 있습니다.

## 화면에서 할 수 있는 것

- 아래 버튼: **강타**(다음 공격 크게) · **방어 태세**(다음 반격 막기) · **펫**(게이지가 차면) · **1배/2배**
- 동료 칸의 버튼: 동료 스킬 (쿨타임)
- 무대 위 **살랑임 켬/끔**: 머리카락 · 망토 살랑임 셰이더 시험
- 무대 위 **모습 바꾸기**: 성별 · 직업 · 동료 둘 · 배경 · 펫 고르고 다시 시작

## 폴더

```
Assets/
  Resources/Art/      그림 (webp 는 Unity 가 못 읽어 png · jpg 로 바꿔 넣음)
  Resources/Fonts/    고운바탕 · Noto Sans KR (OFL 무료 글꼴)
  Resources/Shaders/  ArcaSprite — 번쩍임 · 살랑임
  Resources/*.asset   전투 수치 · 배치 수치
  Scripts/Runtime/    전투 코드
  Scripts/Editor/     처음 설정 · 그림 가져오기 설정 · (선택) 6칸 Sprite Editor 나누기
```

6칸 그림은 코드(`ArtLibrary`)가 칸 너비 = 그림 너비 ÷ 6, 기준점(Pivot) = 발 바닥으로 잘라 씁니다.
Sprite Editor 에서 칸을 눈으로 보고 싶으면 메뉴 **Arca ▸ 6칸 그림을 Sprite Editor 칸으로 나누기 (선택)**.
