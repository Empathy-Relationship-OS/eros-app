import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:eros_app/core/constants/media_constants.dart';
import 'package:eros_app/core/theme/app_colors.dart';
import 'package:eros_app/features/profile/presentation/providers/photo_edit_provider.dart';
import 'package:eros_app/features/profile/presentation/screens/edit/edit_section_scaffold.dart';
import 'package:eros_app/features/profile/presentation/widgets/photo_slot_tile.dart';

/// Shown before removing or replacing the verification photo (RFC-004 §4.4).
const verificationPhotoWarning =
    'This is the photo we used to verify you. If you change it, you\'ll lose your Verified badge '
    'and need to verify again before you can arrange new dates. Dates you\'ve already arranged '
    'aren\'t affected.';

/// Shown after a save that removed or replaced the verification photo.
const verificationResetNotice =
    'Your Verified badge has been removed because the photo we verified you with was changed. '
    'You\'ll need to verify again before you can arrange new dates.';

/// The photo editor (RFC-004 §6.3, PE-F4): a 2 by 3 grid of the user's photos.
///
/// Tapping an empty slot picks a photo, which starts uploading straight away. Tapping a photo
/// offers Replace and Remove. Long press and drag reorders; position 1 is the main photo.
/// Nothing reaches the profile until **Save**, which commits the whole set at once
/// ([PhotoEditNotifier.save]). Leaving with changes asks first; uploads left behind expire on
/// their own.
class EditPhotosScreen extends ConsumerWidget {
  const EditPhotosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(photoEditProvider);
    final notifier = ref.read(photoEditProvider.notifier);

    return EditSectionScaffold(
      title: 'Photos',
      isDirty: state.isDirty,
      canSave: state.canSave,
      onSave: () async {
        final messenger = ScaffoldMessenger.of(context);
        final saved = await notifier.save();
        if (saved.verificationReset) {
          messenger.showSnackBar(const SnackBar(
            content: Text(verificationResetNotice),
            duration: Duration(seconds: 6),
          ));
        }
      },
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const EditQuestion('Your photos'),
                  const SizedBox(height: 8),
                  Text(
                    '${state.photos.length}/${MediaConstants.maxPhotos} photos '
                    '(at least ${MediaConstants.minPhotos})',
                    style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                  if (state.photos.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Long press and drag to reorder. The first photo is your main photo.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  if (state.error != null && !state.isSaving)
                    Padding(
                      key: const Key('photo-edit-error'),
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(state.error!, style: TextStyle(color: Colors.red[700])),
                    ),
                  const SizedBox(height: 24),
                  ReorderableGridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: MediaConstants.maxPhotos,
                    onReorder: (from, to) {
                      if (from < state.photos.length && to < state.photos.length) {
                        notifier.reorder(from, to);
                      }
                    },
                    // The dragged copy is drawn in an overlay with no Material above it; without one
                    // its text gets Flutter's yellow "missing Material" underline.
                    dragWidgetBuilder: (index, child) => Material(
                      type: MaterialType.transparency,
                      child: Opacity(opacity: 0.8, child: child),
                    ),
                    itemBuilder: (context, index) {
                      final photo = index < state.photos.length ? state.photos[index] : null;
                      return _EditPhotoSlot(
                        key: ValueKey(photo == null ? 'empty-$index' : _keyOf(photo)),
                        index: index,
                        photo: photo,
                        onTap: () => photo == null
                            ? notifier.add()
                            : _showActions(context, ref, index, photo),
                        onRetry: photo is StagedPhoto ? () => notifier.retry(photo.localId) : null,
                      );
                    },
                  ),
                  if (state.photos.length < MediaConstants.minPhotos)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Add at least ${MediaConstants.minPhotos} photos to save.',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  // Save waits for every new photo, so say why it is off rather than leave a
                  // reorder looking as if it did nothing.
                  if (state.photos.any((p) => p is StagedPhoto && p.status is StageFailed))
                    const Padding(
                      key: Key('upload-failed-hint'),
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'A photo didn\'t upload, so you can\'t save yet. Tap retry on it, or tap the photo to remove it.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else if (state.photos.any((p) => p is StagedPhoto && p.status is StageUploading))
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text(
                        'You can save once your new photos have uploaded.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  static String _keyOf(EditablePhoto photo) => switch (photo) {
        SavedPhoto(:final id) => 'saved-$id',
        StagedPhoto(:final localId) => localId,
      };

  Future<void> _showActions(BuildContext context, WidgetRef ref, int index, EditablePhoto photo) async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Replace'),
              onTap: () => Navigator.of(context).pop(_PhotoAction.replace),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove'),
              onTap: () => Navigator.of(context).pop(_PhotoAction.remove),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    if (photo is SavedPhoto && photo.isVerificationPhoto) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change your verification photo?'),
          content: const Text(verificationPhotoWarning),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep photo')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action == _PhotoAction.replace ? 'Replace' : 'Remove'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final notifier = ref.read(photoEditProvider.notifier);
    switch (action) {
      case _PhotoAction.replace:
        await notifier.replace(index);
      case _PhotoAction.remove:
        notifier.remove(index);
    }
  }
}

enum _PhotoAction { replace, remove }

/// One editor slot: a saved photo (cached by id), a staged one with its upload state, or empty.
class _EditPhotoSlot extends StatelessWidget {
  final int index;
  final EditablePhoto? photo;
  final VoidCallback onTap;
  final VoidCallback? onRetry;

  const _EditPhotoSlot({super.key, required this.index, required this.photo, required this.onTap, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    return PhotoSlotTile(
      index: index,
      isPrimary: index == 0,
      primaryLabel: 'Main photo',
      // The editor's background is white, like the cards' default, so use the choice cards' grey.
      backgroundColor: Colors.grey[100],
      onTap: onTap,
      image: switch (photo) {
        null => null,
        SavedPhoto(:final id, :final url) => CachedNetworkImage(
            imageUrl: url,
            // Signed URLs change on every fetch; the id doesn't (primer rule 12).
            cacheKey: 'photo-$id',
            memCacheWidth: 600,
            fit: BoxFit.cover,
            errorWidget: (_, _, _) => const Icon(Icons.broken_image_outlined),
          ),
        StagedPhoto(:final localPath) => Image.file(
            File(localPath),
            fit: BoxFit.cover,
            cacheWidth: 600,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          ),
      },
      overlays: [
        if (photo is SavedPhoto && photo.isVerificationPhoto)
          Positioned(
            left: 8,
            bottom: 8,
            child: Container(
              key: const Key('verified-tag'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.white, size: 12),
                  SizedBox(width: 4),
                  Text('Verified', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        if (photo is StagedPhoto) ..._stagedOverlays(photo.status),
      ],
    );
  }

  List<Widget> _stagedOverlays(StageStatus status) => switch (status) {
        StageUploading(:final progress) => [
            Positioned.fill(
              child: Container(
                key: const Key('upload-progress'),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    value: progress > 0 ? progress : null,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        // No tooltip on the retry button: a tooltip claims the long press, so the tile could not
        // be dragged. The label says what happened instead.
        StageFailed() => [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      key: const Key('upload-retry'),
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 36, semanticLabel: 'Retry upload'),
                      onPressed: onRetry,
                    ),
                    const Text(
                      'Upload failed',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        StageReady() => const [],
      };
}
