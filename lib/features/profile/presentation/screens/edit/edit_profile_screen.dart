import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eros_app/core/constants/languages.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/data/repositories/profile_repository.dart';
import 'package:eros_app/features/profile/domain/enums/personality.dart';
import 'package:eros_app/features/profile/domain/enums/preferences.dart';
import 'package:eros_app/features/profile/domain/models/displayable_field.dart';
import 'package:eros_app/features/profile/domain/models/my_profile.dart';
import 'package:eros_app/features/profile/domain/models/update_user_request.dart';
import 'package:eros_app/features/profile/presentation/providers/my_profile_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_attributes_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_basics_screens.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_choice_screens.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_multi_choice_screen.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_text_screen.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/interest_groups.dart';
import 'package:eros_app/features/profile/presentation/widgets/editors/languages_editor.dart';

/// The photo editor arrives with PE-F4. Until then the Photos row is hidden.
const bool photosEditorEnabled = false;

/// The Q&A screens under `screens/qa/` are onboarding-only today: they start from an empty
/// draft rather than the user's answers, and finishing clears the onboarding draft and opens the
/// onboarding photo screen. The row stays hidden until they can edit existing answers.
const bool qaEditorEnabled = false;

/// Edit profile (RFC-004 §6.2): the whole profile in sections, from `GET /users/me`
/// ([myProfileProvider]). Tapping a row opens that field's editor; each save is a small PATCH
/// of just that field (D-1). The eye icon on a show/hide field flips its visibility straight
/// away. Name, date of birth and gender are locked (D-6).
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Edit profile', style: TextStyle(color: Colors.black)),
      ),
      body: profile.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _LoadError(
          message: error is ProfileRepositoryException ? error.message : 'We couldn\'t load your profile.',
          onRetry: () => ref.read(myProfileProvider.notifier).refresh(),
        ),
        data: (profile) => _Hub(profile: profile),
      ),
    );
  }
}

class _Hub extends ConsumerWidget {
  final MyProfile profile;

  const _Hub({required this.profile});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// Sends a one-field visibility PATCH. A failure shows in a snackbar; the row keeps the
  /// server's state, because the provider only changes on success.
  Future<void> _toggle(BuildContext context, WidgetRef ref, UpdateUserRequest request) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(myProfileProvider.notifier).saveSection(request);
    } on ProfileValidationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.getUserMessage())));
    } on ProfileRepositoryException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// An eye for a `DisplayableField` row: none when there's nothing to show (no value, or
  /// "prefer not to say", which is always hidden).
  _Visibility? _eye<T>(
    BuildContext context,
    WidgetRef ref,
    DisplayableField<T> field,
    UpdateUserRequest Function(DisplayableField<T> flipped) build, {
    bool hasValue = true,
  }) {
    if (!hasValue) return null;
    return _Visibility(
      visible: field.visible,
      onToggle: () => _toggle(context, ref, build(DisplayableField(field: field.field, visible: !field.visible))),
    );
  }

  /// Rows for a `DisplayableField` enum edited with [EditDisplayableChoiceScreen].
  Widget _choiceRow<T extends Enum>(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String question,
    required List<T> values,
    required String Function(T) labelOf,
    required DisplayableField<T?> field,
    required UpdateUserRequest Function(DisplayableField<T?>) buildRequest,
    T? preferNotToSay,
  }) {
    final value = field.field;
    return _EditRow(
      label: label,
      value: value == null ? null : labelOf(value),
      visibility: _eye(context, ref, field, buildRequest,
          hasValue: value != null && value != preferNotToSay),
      onTap: () => _open(
        context,
        EditDisplayableChoiceScreen<T>(
          title: label,
          question: question,
          values: values,
          labelOf: labelOf,
          initial: field,
          preferNotToSay: preferNotToSay,
          buildRequest: buildRequest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    final languages = p.spokenLanguages.field;
    final ethnicity = p.ethnicity.field;
    final brain = p.brainAttributes.field;
    final body = p.bodyAttributes.field;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (p.profileCompleteness != null) _CompletenessBar(percent: p.profileCompleteness!),
        if (photosEditorEnabled)
          _Section(title: 'Photos', rows: [
            _EditRow(label: 'Photos', value: 'Edit your photos', onTap: () {}),
          ]),
        _Section(title: 'About me', rows: [
          _EditRow(
            label: 'Bio',
            value: p.bio,
            maxLines: 3,
            onTap: () => _open(
              context,
              EditTextScreen(
                title: 'Bio',
                question: 'Tell us about yourself',
                fieldName: 'Bio',
                initial: p.bio,
                maxLength: 300,
                maxLines: 5,
                hintText: 'e.g. Coffee enthusiast, loves hiking...',
                buildRequest: (text) => UpdateUserRequest(bio: text),
              ),
            ),
          ),
          _EditRow(
            label: 'Occupation',
            value: p.occupation,
            onTap: () => _open(
              context,
              EditTextScreen(
                title: 'Occupation',
                question: 'What do you do?',
                fieldName: 'Occupation',
                initial: p.occupation ?? '',
                maxLength: 50,
                labelText: 'Job / Occupation',
                hintText: 'e.g. Software Engineer',
                buildRequest: (text) => UpdateUserRequest(occupation: text),
              ),
            ),
          ),
        ]),
        _Section(title: 'Basics', rows: [
          _EditRow(
            label: 'Height',
            value: '${p.heightCm} cm',
            onTap: () => _open(context, EditHeightScreen(initialHeightCm: p.heightCm)),
          ),
          _EditRow(
            label: 'Education',
            value: p.educationLevel.displayName,
            onTap: () => _open(context, EditEducationScreen(initial: p.educationLevel)),
          ),
          _EditRow(
            label: 'Location',
            value: p.city,
            onTap: () => _open(context, EditCityScreen(initialCity: p.city)),
          ),
          _EditRow(
            label: 'Languages',
            value: languages.map((l) => l.name).join(', '),
            visibility: _eye(context, ref, p.spokenLanguages, (f) => UpdateUserRequest(spokenLanguages: f),
                hasValue: languages.isNotEmpty),
            onTap: () => _open(
              context,
              EditMultiChoiceScreen<Language>(
                title: 'Languages',
                question: 'What languages do you speak?',
                options: Languages.all,
                labelOf: (l) => l.name,
                min: 1,
                initial: languages,
                initialVisible: p.spokenLanguages.visible,
                listTileBuilder: (context, language, isSelected, onTap) =>
                    LanguageOptionTile(language: language, isSelected: isSelected, onTap: onTap),
                buildRequest: (selected, visible) =>
                    UpdateUserRequest(spokenLanguages: DisplayableField(field: selected, visible: visible)),
              ),
            ),
          ),
        ]),
        _Section(title: 'Interests', rows: [
          _EditRow(
            label: 'Interests',
            value: p.interests.join(', '),
            maxLines: 3,
            onTap: () => _open(
              context,
              EditMultiChoiceScreen<String>(
                title: 'Interests',
                question: 'What are you into?',
                groups: interestGroups,
                labelOf: (i) => i,
                min: minInterests,
                max: maxInterests,
                initial: p.interests,
                searchHint: 'Search interests...',
                emptyText: 'No interests found',
                buildRequest: (selected, _) => UpdateUserRequest(interests: selected),
              ),
            ),
          ),
        ]),
        _Section(title: 'Personality', rows: [
          _EditRow(
            label: 'Traits',
            value: p.traits.map((t) => t.displayName).join(', '),
            maxLines: 3,
            onTap: () => _open(
              context,
              EditMultiChoiceScreen<Trait>(
                title: 'Traits',
                question: 'How would you describe yourself?',
                options: Trait.values,
                labelOf: (t) => t.displayName,
                min: 3,
                max: 10,
                initial: p.traits,
                searchHint: 'Search traits...',
                emptyText: 'No traits found',
                buildRequest: (selected, _) => UpdateUserRequest(traits: selected),
              ),
            ),
          ),
          _EditRow(
            label: 'Star sign',
            value: p.starSign.field?.displayName,
            visibility: _eye(context, ref, p.starSign, (f) => UpdateUserRequest(starSign: f),
                hasValue: p.starSign.field != null),
            onTap: () => _open(context, EditStarSignScreen(initial: p.starSign)),
          ),
        ]),
        _Section(title: 'Habits', rows: [
          _choiceRow<AlcoholConsumption>(context, ref,
              label: 'Drinking',
              question: 'How often do you drink?',
              values: AlcoholConsumption.values,
              labelOf: (v) => v.displayName,
              field: p.alcoholConsumption,
              preferNotToSay: AlcoholConsumption.preferNotToSay,
              buildRequest: (f) => UpdateUserRequest(alcoholConsumption: f)),
          _choiceRow<SmokingStatus>(context, ref,
              label: 'Smoking',
              question: 'Do you smoke?',
              values: SmokingStatus.values,
              labelOf: (v) => v.displayName,
              field: p.smokingStatus,
              preferNotToSay: SmokingStatus.preferNotToSay,
              buildRequest: (f) => UpdateUserRequest(smokingStatus: f)),
          _choiceRow<Diet>(context, ref,
              label: 'Diet',
              question: 'What is your diet?',
              values: Diet.values,
              labelOf: (v) => v.displayName,
              field: p.diet,
              preferNotToSay: Diet.preferNotToSay,
              buildRequest: (f) => UpdateUserRequest(diet: f)),
        ]),
        _Section(title: 'Relationship goals', rows: [
          _choiceRow<DateIntentions>(context, ref,
              label: 'Dating intentions',
              question: 'How do you want to date?',
              values: DateIntentions.values,
              labelOf: (v) => v.displayName,
              field: p.dateIntentions,
              buildRequest: (f) => UpdateUserRequest(dateIntentions: DisplayableField(field: f.field!, visible: f.visible))),
          _choiceRow<RelationshipType>(context, ref,
              label: 'Relationship type',
              question: 'What best describes you?',
              values: RelationshipType.values,
              labelOf: (v) => v.displayName,
              field: p.relationshipType,
              buildRequest: (f) => UpdateUserRequest(relationshipType: DisplayableField(field: f.field!, visible: f.visible))),
          _choiceRow<KidsPreference>(context, ref,
              label: 'Kids',
              question: 'Do you want kids?',
              values: KidsPreference.values,
              labelOf: (v) => v.displayName,
              field: p.kidsPreference,
              preferNotToSay: KidsPreference.preferNotToSay,
              buildRequest: (f) => UpdateUserRequest(kidsPreference: DisplayableField(field: f.field!, visible: f.visible))),
        ]),
        _Section(title: 'Identity', rows: [
          _choiceRow<SexualOrientation>(context, ref,
              label: 'Sexual orientation',
              question: 'What best describes you?',
              values: SexualOrientation.values,
              labelOf: (v) => v.displayName,
              field: p.sexualOrientation,
              preferNotToSay: SexualOrientation.preferNotToSay,
              buildRequest: (f) => UpdateUserRequest(sexualOrientation: DisplayableField(field: f.field!, visible: f.visible))),
          _choiceRow<Pronouns>(context, ref,
              label: 'Pronouns',
              question: 'What are your pronouns?',
              values: Pronouns.values,
              labelOf: (v) => v.displayName,
              field: p.pronouns,
              preferNotToSay: Pronouns.preferNotToSay,
              buildRequest: (f) => UpdateUserRequest(pronouns: f)),
          _choiceRow<Religion>(context, ref,
              label: 'Religion',
              question: 'What is your religion?',
              values: Religion.values,
              labelOf: (v) => v.displayName,
              field: p.religion,
              preferNotToSay: Religion.preferNotToSay,
              buildRequest: (f) => UpdateUserRequest(religion: f)),
          _choiceRow<PoliticalView>(context, ref,
              label: 'Politics',
              question: 'What are your political views?',
              values: PoliticalView.values,
              labelOf: (v) => v.displayName,
              field: p.politicalView,
              preferNotToSay: PoliticalView.preferNotToSay,
              buildRequest: (f) => UpdateUserRequest(politicalView: f)),
          _EditRow(
            label: 'Ethnicity',
            value: ethnicity.map((e) => e.displayName).join(', '),
            visibility: _eye(context, ref, p.ethnicity, (f) => UpdateUserRequest(ethnicity: f),
                hasValue: ethnicity.isNotEmpty),
            onTap: () => _open(
              context,
              EditMultiChoiceScreen<Ethnicity>(
                title: 'Ethnicity',
                question: 'What is your ethnicity?',
                options: Ethnicity.values,
                labelOf: (e) => e.displayName,
                min: 1, // the backend rejects an empty list
                initial: ethnicity,
                initialVisible: p.ethnicity.visible,
                buildRequest: (selected, visible) =>
                    UpdateUserRequest(ethnicity: DisplayableField(field: selected, visible: visible)),
              ),
            ),
          ),
        ]),
        _Section(title: 'Brain & body', rows: [
          _EditRow(
            label: 'Brain',
            value: brain?.map((b) => b.displayName).join(', '),
            visibility: _eye(context, ref, p.brainAttributes, (f) => UpdateUserRequest(brainAttributes: f),
                hasValue: brain?.isNotEmpty == true),
            onTap: () => _openBrain(context),
          ),
          _EditRow(
            label: 'About my brain',
            value: p.brainDescription.field,
            maxLines: 3,
            visibility: _eye(context, ref, p.brainDescription, (f) => UpdateUserRequest(brainDescription: f),
                hasValue: p.brainDescription.field?.isNotEmpty == true),
            onTap: () => _openBrain(context),
          ),
          _EditRow(
            label: 'Body',
            value: body?.map((b) => b.displayName).join(', '),
            visibility: _eye(context, ref, p.bodyAttributes, (f) => UpdateUserRequest(bodyAttributes: f),
                hasValue: body?.isNotEmpty == true),
            onTap: () => _openBody(context),
          ),
          _EditRow(
            label: 'About my body',
            value: p.bodyDescription.field,
            maxLines: 3,
            visibility: _eye(context, ref, p.bodyDescription, (f) => UpdateUserRequest(bodyDescription: f),
                hasValue: p.bodyDescription.field?.isNotEmpty == true),
            onTap: () => _openBody(context),
          ),
        ]),
        if (qaEditorEnabled)
          _Section(title: 'Q&A', rows: [
            _EditRow(label: 'Your answers', value: 'Edit your Q&A', onTap: () {}),
          ]),
        _Section(title: 'Account', rows: [
          _EditRow(label: 'Name', value: '${p.firstName} ${p.lastName}', locked: true),
          _EditRow(label: 'Date of birth', value: _formatDate(p.dateOfBirth), locked: true),
          _EditRow(label: 'Gender', value: p.gender.displayName, locked: true),
        ]),
      ],
    );
  }

  void _openBrain(BuildContext context) => _open(
        context,
        EditAttributesScreen<BrainAttribute>(
          title: 'Brain',
          question: 'Anything about how your brain works?',
          values: BrainAttribute.values,
          labelOf: (b) => b.displayName,
          initialAttributes: profile.brainAttributes,
          initialDescription: profile.brainDescription,
          buildRequest: (attributes, description) =>
              UpdateUserRequest(brainAttributes: attributes, brainDescription: description),
        ),
      );

  void _openBody(BuildContext context) => _open(
        context,
        EditAttributesScreen<BodyAttribute>(
          title: 'Body',
          question: 'Anything about your body?',
          values: BodyAttribute.values,
          labelOf: (b) => b.displayName,
          initialAttributes: profile.bodyAttributes,
          initialDescription: profile.bodyDescription,
          buildRequest: (attributes, description) =>
              UpdateUserRequest(bodyAttributes: attributes, bodyDescription: description),
        ),
      );

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  static String _formatDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';
}

class _LoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _CompletenessBar extends StatelessWidget {
  final int percent;

  const _CompletenessBar({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile $percent% complete',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> rows;

  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Visibility {
  final bool visible;
  final VoidCallback onToggle;

  const _Visibility({required this.visible, required this.onToggle});
}

/// One hub row: label, current value ("Add" when empty), an optional show/hide eye, and a
/// chevron. A locked row can't be tapped and says why.
class _EditRow extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback? onTap;
  final _Visibility? visibility;
  final bool locked;
  final int maxLines;

  const _EditRow({
    required this.label,
    required this.value,
    this.onTap,
    this.visibility,
    this.locked = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value == null || value!.trim().isEmpty;
    final eye = visibility;

    return InkWell(
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text(
                    isEmpty ? 'Add' : value!,
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      color: isEmpty ? AppColors.primary : Colors.black,
                      fontWeight: isEmpty ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (locked) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Contact support to change this',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
            if (eye != null)
              IconButton(
                tooltip: eye.visible ? 'Shown on your profile. Tap to hide' : 'Hidden. Tap to show on your profile',
                icon: Icon(
                  eye.visible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: eye.visible ? AppColors.primary : Colors.grey[500],
                ),
                onPressed: eye.onToggle,
              ),
            Icon(
              locked ? Icons.lock_outline : Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
