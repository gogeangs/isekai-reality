/// 이용 연령 (11-11 #86): 만 14세 이상만. 출생 연도만 묻고 생년월일·실명은 받지 않는다.
class AgeRules {
  AgeRules._();

  static const int minAge = 14;

  /// 올해 나이(연 나이 차)가 정확히 14면 생일이 지났는지 한 번 더 묻는다.
  static bool needsBirthdayQuestion(int birthYear, DateTime now) =>
      now.year - birthYear == minAge;

  /// 이용할 수 있는지. [birthdayPassed] 는 [needsBirthdayQuestion] 일 때만 쓴다.
  static bool allowed(int birthYear, DateTime now, {bool? birthdayPassed}) {
    final diff = now.year - birthYear;
    if (diff > minAge) return true;
    if (diff < minAge) return false;
    return birthdayPassed == true;
  }

  /// 받을 수 있는 출생 연도인지 (네 자리, 1900년부터 올해까지)
  static bool validYear(int? y, DateTime now) =>
      y != null && y >= 1900 && y <= now.year;

  static const String blockedLine = '만 14세 이상만 이용할 수 있어요';
}
