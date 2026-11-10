import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/core/format.dart';

void main() {
  test('받침에 맞는 조사 (11-11 #52)', () {
    expect(josa('큰쥐', '을/를'), '큰쥐를');
    expect(josa('슬라임', '을/를'), '슬라임을');
    expect(josa('이슬', '이/가'), '이슬이');
    expect(josa('불씨', '이/가'), '불씨가');
    expect(josa('대장간', '은/는'), '대장간은');
    expect(josa('여관', '와/과'), '여관과');
    expect(josa('지도', '와/과'), '지도와');
    expect(josa('마을', '으로/로'), '마을로'); // ㄹ 받침
    expect(josa('던전', '으로/로'), '던전으로');
    expect(josa('철 단검 +3', '을/를'), '철 단검 +3을'); // 삼
    expect(josa('가죽 모자 +2', '을/를'), '가죽 모자 +2를'); // 이
    expect(josa('Bob', '이/가'), 'Bob가');
    expect(josa('Neil', '이/가'), 'Neil이');
    expect(josa('고대의 분노한 큰쥐', '이/가'), '고대의 분노한 큰쥐가');
  });
}
