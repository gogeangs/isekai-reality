# 이세계가 현실이라면? : 여명의 탑 아르카

페이즈 1 (상태창 + 동네 탐험) Flutter 프로젝트입니다.

## 처음 실행하기

이 폴더에는 게임 코드(`lib/`)와 테스트(`test/`)만 들어 있습니다.
아이폰·안드로이드용 폴더는 Flutter가 만들어 줍니다.

```bash
cd isekai_reality
flutter create --org kr.itso --project-name isekai_reality .   # android/ios 폴더 생성 (lib는 그대로 둠)
flutter pub get
flutter test        # 규칙 테스트 실행
flutter run         # 연결된 휴대폰이나 시뮬레이터에서 실행
```

목업 그림을 `assets/images/`에 넣으면 화면에 나타납니다. 파일 이름은 그 폴더의 README를 보세요.

## 폴더 구조

```
lib/
  main.dart, app.dart          앱 시작, 하단 메뉴 5개
  core/
    rules/                     게임 규칙 (화면과 분리된 순수 계산)
      rule_constants.dart      ← 밸런스 숫자는 모두 여기
      level_rules.dart         레벨 곡선 100 + 25 × (레벨 − 1)
      exp_rules.dart           하루 경험치 (걸음은 경험치 대신 던전 열쇠)
      dungeon_gauge_rules.dart 2,500보 = 열쇠 1개, 하루 4개, 이월 3개
      stat_rules.dart          스탯 4종 (10에서 시작, 줄지 않음), 전투력·전투 체력
      title_rules.dart         칭호 8종
      job_rules.dart           7일째 직업 각성 4종
      step_goal_rules.dart     맞춤 걸음 목표 제안
      quest_rules.dart         일일 퀘스트 3개
    models/                    하루 기록(DailyRecord), 플레이어 상태(PlayerState)
  features/
    status/                    메인 상태창 화면, 예시 데이터
    bulssi/                    불씨 대사 고르기
  theme/                       목업 색상
test/
  rules_test.dart              규칙 단위 테스트
  widget_test.dart             앱 실행 확인
```

## 설계 원칙

- 상태(레벨·스탯·칭호)는 저장하지 않고 **하루 기록에서 매번 다시 계산**합니다. 밸런스 숫자를 바꾸면 과거 기록에도 바로 반영됩니다.
- 건강 데이터는 기기 안에서만 계산합니다.

## 지금 상태와 다음 작업

- [x] 게임 규칙 엔진과 테스트
- [x] 메인 상태창 (예시 데이터, 공부 기록 버튼 동작)
- [ ] 건강 앱 연동 (아이폰 HealthKit, 안드로이드 Health Connect)
- [ ] 각성 화면, 레벨업 연출
- [ ] 고잔동 지도, 장소 아이콘, 잿빛 안개
- [ ] 던전 입장·전투·결과, 필드 몬스터
- [ ] 기록·칭호 도감 화면
- [ ] 기록 저장 (기기 저장소)
