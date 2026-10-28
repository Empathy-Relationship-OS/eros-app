import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';
import 'package:eros_app/features/date_preferences/presentation/widgets/travel_distance_slider.dart';
import 'package:flutter_test/flutter_test.dart';

const _texas = [
  TravelStop(label: '2 miles', meters: 3219),
  TravelStop(label: '5 miles', meters: 8047),
  TravelStop(label: '40 miles', meters: 64374),
];

void main() {
  group('TravelDistanceSlider.snap', () {
    test('keeps a stop and Anywhere as they are', () {
      expect(TravelDistanceSlider.snap(_texas, 8047), 8047);
      expect(TravelDistanceSlider.snap(_texas, null), isNull);
    });

    test('moves any other value to the nearest stop', () {
      expect(TravelDistanceSlider.snap(_texas, 1609), 3219);
      expect(TravelDistanceSlider.snap(_texas, 24140), 8047);
      expect(TravelDistanceSlider.snap(_texas, 100000), 64374);
    });

    test('picks the shorter stop on a tie', () {
      expect(TravelDistanceSlider.snap(_texas, (3219 + 8047) ~/ 2), 3219);
    });

    test('is Anywhere when the city has no stops', () {
      expect(TravelDistanceSlider.snap(const [], 8047), isNull);
    });
  });
}
