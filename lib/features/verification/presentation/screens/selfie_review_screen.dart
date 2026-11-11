import 'dart:io';

import 'package:flutter/material.dart';
import 'package:eros_app/features/verification/presentation/widgets/verification_copy.dart';

/// The picture just taken, with Use this and Retake (VF-F2 step 5).
///
/// While [sending], one progress state covers resizing, the upload and the submit. The decoded
/// picture is evicted from Flutter's image cache when this screen goes (primer rule 19).
class SelfieReviewScreen extends StatefulWidget {
  final String path;
  final bool sending;
  final VoidCallback onUse;
  final VoidCallback onRetake;

  const SelfieReviewScreen({
    super.key,
    required this.path,
    required this.sending,
    required this.onUse,
    required this.onRetake,
  });

  @override
  State<SelfieReviewScreen> createState() => _SelfieReviewScreenState();
}

class _SelfieReviewScreenState extends State<SelfieReviewScreen> {
  late final FileImage _image = FileImage(File(widget.path));

  @override
  void dispose() {
    _image.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: _image,
            fit: BoxFit.cover,
            semanticLabel: VerificationCopy.reviewTitle,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Semantics(
                          header: true,
                          child: const Text(
                            VerificationCopy.reviewTitle,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          VerificationCopy.reviewHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (widget.sending)
                    Semantics(
                      liveRegion: true,
                      child: const Column(
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 12),
                          Text(
                            VerificationCopy.sending,
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    ElevatedButton(
                      onPressed: widget.onUse,
                      child: const Text(VerificationCopy.useThis),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: widget.onRetake,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                      ),
                      child: const Text(VerificationCopy.retake),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
