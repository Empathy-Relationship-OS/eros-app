import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:eros_app/core/constants/user_text_limits.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/safety/data/models/safety_models.dart';
import 'package:eros_app/features/safety/presentation/providers/report_provider.dart';
import 'package:eros_app/features/safety/presentation/widgets/safety_copy.dart';

/// The report fields: a reason from the API, an optional description and up to 3 images.
///
/// Used by `ReportSheet` and by the cancel dialog's "I don't feel safe". Everything typed or
/// picked lives in [reportProvider], so a failed upload never loses the description.
class ReportForm extends ConsumerStatefulWidget {
  final String dateId;

  /// A reason to choose when the reasons load, if the person hasn't chosen one.
  final String? initialReasonCode;

  const ReportForm({super.key, required this.dateId, this.initialReasonCode});

  @override
  ConsumerState<ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends ConsumerState<ReportForm> {
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: ref.read(reportProvider(widget.dateId)).description,
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final notifier = ref.read(reportProvider(widget.dateId).notifier);
    try {
      final picked = await ref.read(evidenceImagePickerProvider).pickImage(
            source: ImageSource.gallery,
            imageQuality: 85,
            maxWidth: 2000,
            maxHeight: 2000,
          );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      await notifier.addImage(bytes: bytes, path: picked.path, reportedMimeType: picked.mimeType);
    } catch (_) {
      if (mounted) notifier.showImageError(SafetyCopy.imagePickFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportProvider(widget.dateId));
    final notifier = ref.read(reportProvider(widget.dateId).notifier);
    final reasons = ref.watch(safetyReasonsProvider);
    final enabled = !state.isSubmitting;

    final initialReason = widget.initialReasonCode;
    if (initialReason != null && state.reasonCode == null) {
      final loaded = reasons.valueOrNull;
      if (loaded != null && loaded.any((r) => r.code == initialReason)) {
        // After this frame: a provider can't change while the tree builds.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) notifier.preselectReason(initialReason);
        });
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading(SafetyCopy.reasonHeading),
        reasons.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                SafetyCopy.reasonsFailed,
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () => ref.invalidate(safetyReasonsProvider),
                child: const Text(SafetyCopy.retry),
              ),
            ],
          ),
          data: (list) => _ReasonList(
            reasons: list,
            selected: state.reasonCode,
            onSelected: enabled ? notifier.selectReason : null,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descriptionController,
          onChanged: notifier.setDescription,
          enabled: enabled,
          minLines: 2,
          maxLines: 5,
          maxLength: UserTextLimits.reportDescription,
          keyboardType: TextInputType.multiline,
          decoration: const InputDecoration(
            hintText: SafetyCopy.descriptionHint,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        const _Heading(SafetyCopy.imagesHeading),
        _EvidenceRow(
          images: state.images,
          canAdd: enabled && state.canAddImage,
          onAdd: _pickImage,
          onRemove: enabled ? notifier.removeImage : null,
        ),
        if (state.hasFailedImage)
          const _Note(SafetyCopy.imageFailed, color: AppColors.error),
        if (state.imageError != null) _Note(state.imageError!, color: AppColors.error),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      );
}

class _Note extends StatelessWidget {
  final String text;
  final Color color;
  const _Note(this.text, {required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(text, style: TextStyle(fontSize: 13, color: color)),
      );
}

class _ReasonList extends StatelessWidget {
  final List<SafetyReason> reasons;
  final String? selected;
  final ValueChanged<String>? onSelected;

  const _ReasonList({required this.reasons, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (code) {
        if (code != null) onSelected?.call(code);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final reason in reasons)
            RadioListTile<String>(
              value: reason.code,
              enabled: onSelected != null,
              title: Text(reason.label),
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeColor: AppColors.primary,
            ),
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  final List<EvidenceImage> images;
  final bool canAdd;
  final VoidCallback onAdd;
  final ValueChanged<String>? onRemove;

  const _EvidenceRow({
    required this.images,
    required this.canAdd,
    required this.onAdd,
    required this.onRemove,
  });

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final image in images) _thumbnail(image),
        if (images.length < SafetyLimits.maxEvidenceImages)
          Semantics(
            button: true,
            label: SafetyCopy.addImage,
            child: InkWell(
              onTap: canAdd ? onAdd : null,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.textSecondary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _thumbnail(EvidenceImage image) {
    return SizedBox(
      key: ValueKey(image.localId),
      width: _size,
      height: _size,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              image.bytes,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: AppColors.divider),
            ),
          ),
          if (image.status == EvidenceUploadStatus.uploading)
            Container(
              color: Colors.black26,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: SafetyCopy.imageUploading),
              ),
            ),
          if (image.status == EvidenceUploadStatus.failed)
            Container(
              decoration: BoxDecoration(
                color: Colors.black38,
                border: Border.all(color: AppColors.error, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.error_outline, color: Colors.white),
            ),
          Positioned(
            top: -4,
            right: -4,
            child: IconButton(
              tooltip: SafetyCopy.removeImage,
              onPressed: onRemove == null ? null : () => onRemove!(image.localId),
              icon: const CircleAvatar(
                radius: 11,
                backgroundColor: Colors.white,
                child: Icon(Icons.close, size: 14, color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
