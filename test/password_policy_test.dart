import 'package:flutter_test/flutter_test.dart';

import 'package:team_project_manager/features/auth/application/password_policy.dart';

void main() {
  Set<PasswordRule> met(String p) => evaluatePassword(p).met;

  test('each rule in isolation', () {
    expect(met('abcdefgh'), {PasswordRule.minLength});
    expect(met('aB'), {PasswordRule.mixedCase});
    expect(met('7'), {PasswordRule.number});
    expect(met('!'), {PasswordRule.symbol});
  });

  test('length boundary is exactly 8', () {
    expect(PasswordRule.minLength.isMetBy('Aa1!aaa'), isFalse);
    expect(PasswordRule.minLength.isMetBy('Aa1!aaaa'), isTrue);
  });

  test('whitespace is not a symbol; unicode punctuation is', () {
    expect(PasswordRule.symbol.isMetBy('Aa1 aaaa'), isFalse);
    expect(PasswordRule.symbol.isMetBy('Aa1€aaaa'), isTrue);
  });

  test('meetsPolicy only when all four rules pass', () {
    expect(evaluatePassword('Passw0rd!').meetsPolicy, isTrue);
    expect(evaluatePassword('password1!').meetsPolicy, isFalse); // no upper
    expect(evaluatePassword('PASSWORD1!').meetsPolicy, isFalse); // no lower
    expect(evaluatePassword('Password!!').meetsPolicy, isFalse); // no digit
    expect(evaluatePassword('Password12').meetsPolicy, isFalse); // no symbol
    expect(evaluatePassword('Pa0!').meetsPolicy, isFalse); // too short
  });

  test('strength levels', () {
    expect(evaluatePassword('').strength, PasswordStrength.empty);
    expect(evaluatePassword('abc').strength, PasswordStrength.weak);
    expect(evaluatePassword('Password1').strength, PasswordStrength.fair);
    expect(evaluatePassword('Passw0rd!').strength, PasswordStrength.good);
    expect(evaluatePassword('Passw0rd!Long').strength, PasswordStrength.strong);
  });
}
