/// A first and last name given by a sign-in provider, used to prefill the name step of profile
/// creation (RFC-011 D-7). The user can change both there.
class ProviderName {
  final String firstName;
  final String lastName;

  const ProviderName({required this.firstName, required this.lastName});

  /// The given and family names when the provider sent them; otherwise [displayName] split on
  /// its first space ("Mary Ann Smith" gives "Mary" and "Ann Smith"). Null when there is no name.
  static ProviderName? from({String? givenName, String? familyName, String? displayName}) {
    final given = givenName?.trim() ?? '';
    final family = familyName?.trim() ?? '';
    if (given.isNotEmpty || family.isNotEmpty) {
      return ProviderName(firstName: given, lastName: family);
    }

    final display = displayName?.trim() ?? '';
    if (display.isEmpty) return null;
    final space = display.indexOf(RegExp(r'\s'));
    if (space < 0) return ProviderName(firstName: display, lastName: '');
    return ProviderName(
      firstName: display.substring(0, space),
      lastName: display.substring(space + 1).trim(),
    );
  }
}
