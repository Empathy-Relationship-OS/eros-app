import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:eros_app/core/auth/auth_service.dart';
import 'package:eros_app/core/constants/languages.dart';
import 'package:eros_app/core/network/api_client.dart';
import 'package:eros_app/core/network/exceptions/api_exception.dart';
import 'package:eros_app/core/network/interceptors/logging_interceptor.dart';
import 'package:eros_app/features/legal/data/repositories/age_signal_repository.dart';
import 'package:eros_app/features/legal/domain/models/store_age_signal.dart';
import 'package:eros_app/features/legal/presentation/providers/age_signal_providers.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/enums/gender.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/create_user_request.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_age_signals_platform.dart';

/// Records each POST and answers it with [answer], or throws [error].
class _PostApiClient implements ApiClient {
  _PostApiClient({this.answer = const {'recorded': true}, this.error});

  final Map<String, dynamic> answer;
  ApiException? error;
  final posts = <({String path, dynamic data})>[];

  @override
  Future<T> post<T>(String path, {dynamic data, Map<String, dynamic>? queryParameters, Options? options}) async {
    posts.add((path: path, data: data));
    if (error != null) throw error!;
    return answer as T;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CreateUserRequest _request({StoreAgeSignal? ageSignal}) => CreateUserRequest(
      userId: 'user1',
      firstName: 'Alex',
      lastName: 'Smith',
      email: 'alex@example.com',
      heightCm: 175,
      dateOfBirth: DateTime(1995, 5, 1),
      city: 'London',
      educationLevel: EducationLevel.university,
      gender: Gender.female,
      preferredLanguage: Languages.all.first,
      coordinatesLatitude: 51.5,
      coordinatesLongitude: -0.1,
      interests: const ['HIKING', 'COFFEE', 'JAZZ', 'GOLF', 'READING'],
      traits: const [Trait.adventurous, Trait.ambitious, Trait.creative],
      spokenLanguages: DisplayableField(field: [Languages.all.first]),
      religion: DisplayableField(field: null, visible: false),
      alcoholConsumption: DisplayableField(field: null, visible: false),
      smokingStatus: DisplayableField(field: null, visible: false),
      diet: DisplayableField(field: null, visible: false),
      dateIntentions: DisplayableField(field: DateIntentions.notSure, visible: false),
      relationshipType: DisplayableField(field: RelationshipType.monogamous, visible: false),
      kidsPreference: DisplayableField(field: KidsPreference.preferNotToSay, visible: false),
      sexualOrientation: DisplayableField(field: SexualOrientation.preferNotToSay, visible: false),
      pronouns: DisplayableField(field: null, visible: false),
      starSign: DisplayableField(field: null, visible: false),
      ethnicity: DisplayableField(field: [], visible: false),
      brainAttributes: DisplayableField(field: null, visible: false),
      brainDescription: DisplayableField(field: null, visible: false),
      bodyAttributes: DisplayableField(field: null, visible: false),
      bodyDescription: DisplayableField(field: null, visible: false),
      ageSignal: ageSignal,
    );

const _underageBody = {'error': 'UNDERAGE', 'message': 'You need to be 18 or over to use Muse'};

class _CaptureOutput extends LogOutput {
  final lines = <String>[];

  @override
  void output(OutputEvent event) => lines.addAll(event.lines);
}

class _AlwaysLog extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => true;
}

/// Answers every request with an empty JSON object, as a backend that doesn't echo would.
class _EmptyAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream,
          Future<void>? cancelFuture) async =>
      ResponseBody.fromString('{}', 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  void close({bool force = false}) {}
}

void main() {
  group('CreateUserRequest.ageSignal', () {
    test('rides on POST /users when there is one', () {
      expect(_request(ageSignal: adultSignal).toJson()['ageSignal'],
          {'source': 'APPLE', 'band': 'ADULT'});
    });

    test('is left out when there is none', () {
      expect(_request().toJson().containsKey('ageSignal'), isFalse);
    });

    test('survives copyWith', () {
      expect(_request(ageSignal: adultSignal).copyWith(firstName: 'Sam').ageSignal, adultSignal);
    });
  });

  group('ProfileRepository.createUser and 403 UNDERAGE', () {
    ProfileRepository repository(_PostApiClient client) => ProfileRepository(
          apiClient: client,
          authService: AuthService(auth: _FakeFirebaseAuth()),
          logger: Logger(level: Level.off),
        );

    test('UNDERAGE becomes UnderageSignUpException', () async {
      final client = _PostApiClient(
          error: const ForbiddenException('under 18', originalError: _underageBody));

      await expectLater(repository(client).createUser(_request(ageSignal: minorSignal)),
          throwsA(isA<UnderageSignUpException>()));
    });

    test('another 403 keeps the generic message', () async {
      final client = _PostApiClient(
          error: const ForbiddenException('no', originalError: {'error': 'ACCOUNT_NOT_ALLOWED'}));

      await expectLater(repository(client).createUser(_request()),
          throwsA(isA<ProfileRepositoryException>()));
    });

    test('isUnderageRefusal reads the code, not the status', () {
      expect(isUnderageRefusal(const ForbiddenException('x', originalError: _underageBody)), isTrue);
      expect(isUnderageRefusal(const ForbiddenException('x')), isFalse);
      expect(isUnderageRefusal(const ConflictException('x', originalError: _underageBody)), isFalse);
    });
  });

  group('AgeSignalRepository.send', () {
    test('POSTs the signal to /users/me/age-signal and returns recorded', () async {
      final client = _PostApiClient(answer: const {'recorded': false});

      final recorded = await AgeSignalRepository(client).send(minorSignal);

      expect(recorded, isFalse);
      expect(client.posts.single.path, '/users/me/age-signal');
      expect(client.posts.single.data, {'source': 'GOOGLE', 'band': 'AGE_13_15'});
    });
  });

  group('ExistingUserAgeSignal.sendOnce', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('reads and sends once, then never again for that user', () async {
      final service = FixedAgeSignalService(minorSignal);
      final client = _PostApiClient();
      final sync = ExistingUserAgeSignal(service, AgeSignalRepository(client), prefs);

      await sync.sendOnce('user1');
      await sync.sendOnce('user1');

      expect(service.reads, 1);
      expect(client.posts.single.data, minorSignal.toJson());
      // A flag only: the band is never stored on the phone.
      expect(prefs.getKeys(), {'age_signal_asked_user1'});
      expect(prefs.getBool('age_signal_asked_user1'), isTrue);
    });

    test('no signal sends nothing and is not asked again', () async {
      final service = FixedAgeSignalService(null);
      final client = _PostApiClient();
      final sync = ExistingUserAgeSignal(service, AgeSignalRepository(client), prefs);

      await sync.sendOnce('user1');
      await sync.sendOnce('user1');

      expect(service.reads, 1);
      expect(client.posts, isEmpty);
    });

    test('a failed send is tried again on the next launch', () async {
      final service = FixedAgeSignalService(adultSignal);
      final client = _PostApiClient(error: const NetworkException('offline'));
      final sync = ExistingUserAgeSignal(service, AgeSignalRepository(client), prefs);

      await sync.sendOnce('user1');
      client.error = null;
      await sync.sendOnce('user1');

      expect(client.posts, hasLength(2));
      expect(sync.wasAsked('user1'), isTrue);
    });

    test('another user on the same phone is asked too', () async {
      final service = FixedAgeSignalService(adultSignal);
      final sync = ExistingUserAgeSignal(service, AgeSignalRepository(_PostApiClient()), prefs);

      await sync.sendOnce('user1');
      await sync.sendOnce('user2');

      expect(service.reads, 2);
    });

    test('a user that sign-up marked is never asked', () async {
      final service = FixedAgeSignalService(adultSignal);
      final sync = ExistingUserAgeSignal(service, AgeSignalRepository(_PostApiClient()), prefs);

      await ExistingUserAgeSignal.markAskedIn(prefs, 'user1');
      await sync.sendOnce('user1');

      expect(service.reads, 0);
    });
  });

  group('logging (primer rule 3)', () {
    ({Dio dio, _CaptureOutput output}) loggedDio() {
      final output = _CaptureOutput();
      final logger =
          Logger(filter: _AlwaysLog(), printer: SimplePrinter(colors: false), output: output);
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8940'))
        ..httpClientAdapter = _EmptyAdapter()
        ..interceptors.add(LoggingInterceptor(logger: logger));
      return (dio: dio, output: output);
    }

    test('prints no age band on POST /users', () async {
      final (:dio, :output) = loggedDio();

      await dio.post('/users', data: {'firstName': 'Sam', 'ageSignal': minorSignal.toJson()});

      final log = output.lines.join('\n');
      expect(log, isNot(contains('AGE_13_15')));
      expect(log, contains('Sam'), reason: 'the rest of the body is still printed');
    });

    test('prints no body on POST /users/me/age-signal', () async {
      final (:dio, :output) = loggedDio();

      await dio.post('/users/me/age-signal', data: minorSignal.toJson());

      final log = output.lines.join('\n');
      expect(log, isNot(contains('AGE_13_15')));
      expect(log, contains('POST /users/me/age-signal'));
    });
  });
}
