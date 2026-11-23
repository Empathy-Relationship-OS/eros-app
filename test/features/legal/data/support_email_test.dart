import 'package:eros_app/core/config/support_config.dart';
import 'package:eros_app/features/legal/data/support_email.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a data request carries its subject and the account id only', () {
    final uri = supportEmailUri(SupportRequest.dataRequest, 'uid-123', to: 'help@example.com');

    expect(uri.scheme, 'mailto');
    expect(uri.path, 'help@example.com');
    expect(uri.queryParameters.keys, unorderedEquals(['subject', 'body']));
    expect(uri.queryParameters['subject'], 'Data request');
    expect(uri.queryParameters['body']!.trim(), 'Account id: uid-123');
  });

  test('a complaint carries its subject', () {
    final uri = supportEmailUri(SupportRequest.complaint, 'uid-123', to: 'help@example.com');

    expect(uri.queryParameters['subject'], 'Complaint');
    expect(uri.queryParameters['body']!.trim(), 'Account id: uid-123');
  });

  test('spaces are %20, not +, so every mail app reads them', () {
    final uri = supportEmailUri(SupportRequest.dataRequest, 'uid-123', to: 'help@example.com');

    expect(uri.toString(), contains('subject=Data%20request'));
    expect(uri.toString(), isNot(contains('+')));
  });

  test('goes to the support address by default', () {
    final uri = supportEmailUri(SupportRequest.complaint, 'uid-123');

    expect(uri.path, SupportConfig.supportEmail);
  });
}
