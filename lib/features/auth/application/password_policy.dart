/// Registration password rules (CLAUDE.md §9). Pure functions only: the
/// password is evaluated in memory and never stored, logged or sent
/// anywhere except `createUserWithEmailAndPassword`.
library;

const passwordMinLength = 8;

/// One checklist line under the register screen's password field.
enum PasswordRule {
  minLength('At least $passwordMinLength characters'),
  mixedCase('Upper and lower case letters'),
  number('A number'),
  symbol('A symbol (e.g. ! @ # \$)');

  const PasswordRule(this.label);

  final String label;

  bool isMetBy(String password) => switch (this) {
    PasswordRule.minLength => password.length >= passwordMinLength,
    PasswordRule.mixedCase =>
      password.contains(RegExp('[a-z]')) && password.contains(RegExp('[A-Z]')),
    PasswordRule.number => password.contains(RegExp('[0-9]')),
    // Anything that isn't a letter, digit or whitespace counts.
    PasswordRule.symbol => password.contains(RegExp(r'[^A-Za-z0-9\s]')),
  };
}

enum PasswordStrength { empty, weak, fair, good, strong }

class PasswordCheck {
  const PasswordCheck._(this.met, this.strength);

  /// The rules this password satisfies.
  final Set<PasswordRule> met;
  final PasswordStrength strength;

  /// Whether every rule passes — the minimum for Create account.
  bool get meetsPolicy => met.length == PasswordRule.values.length;
}

PasswordCheck evaluatePassword(String password) {
  final met = {
    for (final rule in PasswordRule.values)
      if (rule.isMetBy(password)) rule,
  };
  final PasswordStrength strength;
  if (password.isEmpty) {
    strength = PasswordStrength.empty;
  } else if (met.length == PasswordRule.values.length) {
    strength = password.length >= 12
        ? PasswordStrength.strong
        : PasswordStrength.good;
  } else if (met.length >= 3) {
    strength = PasswordStrength.fair;
  } else {
    strength = PasswordStrength.weak;
  }
  return PasswordCheck._(met, strength);
}
