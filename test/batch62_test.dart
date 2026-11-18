// 묶음 62: 개인정보 처리방침 3판(다시 동의) · /privacy · 수비대 분신 그림을 지금 직업 20가지로

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/core/rules/rules.dart';

void main() {
  group('약관 3판', () {
    test('처리방침만 3판 · 이용약관 · 위치 약관 · 운영정책은 그대로', () {
      final now = DateTime(2026, 11, 18, 18);
      expect(LegalRules.current(LegalKind.privacy, now).version, 3);
      expect(LegalRules.current(LegalKind.terms, now).version, 2);
      expect(LegalRules.current(LegalKind.location, now).version, 2);
      expect(LegalRules.current(LegalKind.operation, now).version, 2);
      final need = LegalRules.needed({for (final k in LegalKind.values) k: 2}, now);
      expect(need.map((v) => (v.kind, v.version)), [(LegalKind.privacy, 3)]);
      expect(need.single.summary, contains('부정 이용 막기'));
    });

    test('처리방침 3판 글 = 정책 문서 최신본 · 웹 /privacy 도 같은 글', () {
      final p = File('assets/legal/privacy.txt').readAsStringSync();
      for (final w in [
        '공성전(로그인하고 길드로 공성에 참여하는 경우)',
        '부정 이용 막기(로그인하고 함께하는 기능을 쓰는 경우)',
        '손으로 입력한 걸음',
        '진짜 앱 확인(App Check)',
        '위치 · 칸 번호는 남기지 않음',
        '거래 지갑 금화',
        'Google ML Kit을 써서 휴대폰 안에서만 처리',
        '그 공성전이 끝난 날부터 8주',
        '진짜 앱 확인 횟수: 8주',
        '공성권 장부: 계정 삭제를 요청해',
        '최근 50줄',
        '2026년 11월 18일',
      ]) {
        expect(p, contains(w), reason: w);
      }
      expect(p, isNot(contains('공성전 기록(공성권 사용, 수비대 배치, 영지 소유)')), reason: '길드 줄에서 공성전 줄로 옮김');
      final j = jsonDecode(File('firebase/functions/src/legal_texts.json').readAsStringSync()) as Map;
      expect(j['privacy'], p);
    });
  });

  group('수비대 분신 그림', () {
    test('지금 직업 20가지 → 그림 6장 (기획 연결표)', () {
      const table = {
        MonsterId.cloneWarrior: [JobId.warrior, JobId.blacksmith, JobId.adventurer, JobId.allCrafter],
        MonsterId.cloneArcher: [JobId.archer, JobId.herbalist, JobId.explorer, JobId.ashHunter],
        MonsterId.cloneMage: [JobId.mage, JobId.alchemist, JobId.appraiser, JobId.archaeologist],
        MonsterId.clonePriest: [JobId.priest, JobId.pilgrim],
        MonsterId.cloneRogue: [JobId.rogue, JobId.merchant, JobId.nightWalker],
        MonsterId.cloneKnight: [JobId.knight, JobId.tamer, JobId.gateHeir],
      };
      expect(table.values.expand((x) => x).length, 20);
      for (final e in table.entries) {
        for (final j in e.value) {
          expect(ErbardRules.cloneOf(j.name), e.key, reason: '${JobRules.info(j).name} → ${e.key.name}');
        }
      }
      expect(ErbardRules.cloneOf(null), MonsterId.cloneWarrior, reason: '직업 없음');
      // 예전 기록 대비 (#249 전 직업)
      expect(ErbardRules.cloneOf('hunter'), MonsterId.cloneArcher);
      expect(ErbardRules.cloneOf('healer'), MonsterId.clonePriest);
      expect(ErbardRules.cloneOf('beastKnight'), MonsterId.cloneKnight);
      expect(ErbardRules.cloneOf('없는직업'), MonsterId.cloneWarrior);
    });
  });
}
