import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/city_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/height_editor.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/star_sign_editor.dart';

/// Edits the height. Nothing is sent unless the user changes it, so a stored height in cm
/// isn't rounded through feet and inches just by opening this screen.
class EditHeightScreen extends ConsumerStatefulWidget {
  final int initialHeightCm;

  const EditHeightScreen({super.key, required this.initialHeightCm});

  @override
  ConsumerState<EditHeightScreen> createState() => _EditHeightScreenState();
}

class _EditHeightScreenState extends ConsumerState<EditHeightScreen> {
  int? _heightCm;

  bool get _isDirty => _heightCm != null && _heightCm != widget.initialHeightCm;

  Future<void> _save() =>
      ref.read(myProfileProvider.notifier).saveSection(UpdateUserRequest(heightCm: _heightCm));

  @override
  Widget build(BuildContext context) {
    return EditSectionScaffold(
      title: 'Height',
      isDirty: _isDirty,
      canSave: _isDirty,
      onSave: _save,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EditQuestion('What\'s your height?'),
            const SizedBox(height: 32),
            HeightEditor(
              initialHeightCm: widget.initialHeightCm,
              onChanged: (heightCm) => setState(() => _heightCm = heightCm),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edits the home city and its coordinates (free text on the backend, RFC-004 D-14).
class EditCityScreen extends ConsumerStatefulWidget {
  final String initialCity;

  const EditCityScreen({super.key, required this.initialCity});

  @override
  ConsumerState<EditCityScreen> createState() => _EditCityScreenState();
}

class _EditCityScreenState extends ConsumerState<EditCityScreen> {
  HomeCity? _picked;
  bool _cleared = false;

  bool get _isDirty => _picked != null && !_cleared && _picked!.name != widget.initialCity;

  @override
  Widget build(BuildContext context) {
    return EditSectionScaffold(
      title: 'Location',
      isDirty: _isDirty,
      canSave: _isDirty,
      onSave: () => ref.read(myProfileProvider.notifier).saveSection(UpdateUserRequest(
            city: _picked!.name,
            coordinatesLatitude: _picked!.latitude,
            coordinatesLongitude: _picked!.longitude,
          )),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EditQuestion('Where are you based?'),
            const SizedBox(height: 24),
            CityEditor(
              initialCity: widget.initialCity,
              onCitySelected: (city) => setState(() {
                _picked = city;
                _cleared = false;
              }),
              onQueryCleared: () => setState(() => _cleared = true),
            ),
          ],
        ),
      ),
    );
  }
}

/// Edits the star sign and whether it shows. Clearing it saves it hidden, as onboarding does.
class EditStarSignScreen extends ConsumerStatefulWidget {
  final DisplayableField<StarSign?> initial;

  const EditStarSignScreen({super.key, required this.initial});

  @override
  ConsumerState<EditStarSignScreen> createState() => _EditStarSignScreenState();
}

class _EditStarSignScreenState extends ConsumerState<EditStarSignScreen> {
  late StarSign? _selected = widget.initial.field;
  late bool _visible = widget.initial.visible;

  bool get _effectiveVisible => _selected != null && _visible;

  bool get _isDirty => _selected != widget.initial.field || _effectiveVisible != widget.initial.visible;

  @override
  Widget build(BuildContext context) {
    return EditSectionScaffold(
      title: 'Star sign',
      isDirty: _isDirty,
      canSave: _isDirty,
      onSave: () => ref.read(myProfileProvider.notifier).saveSection(
            UpdateUserRequest(starSign: DisplayableField(field: _selected, visible: _effectiveVisible)),
          ),
      body: StarSignEditor(
        selected: _selected,
        visible: _visible,
        onSelected: (sign) => setState(() => _selected = sign),
        onVisibleChanged: (visible) => setState(() => _visible = visible),
      ),
    );
  }
}
