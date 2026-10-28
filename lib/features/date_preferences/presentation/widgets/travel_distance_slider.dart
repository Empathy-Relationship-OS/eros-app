import 'package:flutter/material.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/date_preferences/domain/models/date_preference_options.dart';

/// Every string this widget shows that isn't from the options.
abstract final class _Copy {
  static const anywhere = 'Anywhere';
  static const softLimit = 'We\'ll aim to keep dates within this. If the best place for you both '
      'is a little further, we may suggest it.';
}

/// How far the user will travel (RFC-005 §6.2): the city's [stops] from the options, then
/// Anywhere. Every label is the server's, in the city's unit (D-15, D-27).
///
/// [meters] null is Anywhere. A value that isn't one of [stops] (saved for a different first
/// city) shows as the nearest stop: see [snap].
class TravelDistanceSlider extends StatelessWidget {
  final List<TravelStop> stops;
  final int? meters;
  final ValueChanged<int?> onChanged;

  const TravelDistanceSlider({
    super.key,
    required this.stops,
    required this.meters,
    required this.onChanged,
  });

  /// [meters] as the slider shows it: null (Anywhere) stays null, anything else becomes the
  /// nearest of [stops] (the shorter one on a tie). With no stops, only Anywhere is left.
  static int? snap(List<TravelStop> stops, int? meters) {
    if (meters == null || stops.isEmpty) return null;
    var nearest = stops.first.meters;
    for (final stop in stops) {
      if ((stop.meters - meters).abs() < (nearest - meters).abs()) nearest = stop.meters;
    }
    return nearest;
  }

  /// The slider position for [meters]: a stop's index, or one past the last for Anywhere.
  int _index() {
    final snapped = snap(stops, meters);
    if (snapped == null) return stops.length;
    return stops.indexWhere((s) => s.meters == snapped);
  }

  String _label(int index) => index < stops.length ? stops[index].label : _Copy.anywhere;

  @override
  Widget build(BuildContext context) {
    final index = _index();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _label(index),
          key: const Key('travel-distance-value'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        if (stops.isNotEmpty) ...[
          Slider(
            value: index.toDouble(),
            max: stops.length.toDouble(),
            divisions: stops.length,
            label: _label(index),
            semanticFormatterCallback: (value) => _label(value.round()),
            activeColor: AppColors.primary,
            onChanged: (value) {
              final i = value.round();
              if (i != index) onChanged(i < stops.length ? stops[i].meters : null);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ExcludeSemantics(
                  child: Text(stops.first.label, style: TextStyle(color: Colors.grey[600])),
                ),
                ExcludeSemantics(
                  child: Text(_Copy.anywhere, style: TextStyle(color: Colors.grey[600])),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(_Copy.softLimit, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
      ],
    );
  }
}
