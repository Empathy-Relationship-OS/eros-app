import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Marketing consent state
class MarketingConsentState {
  final bool acceptsMarketing;
  final bool isLoading;

  const MarketingConsentState({
    this.acceptsMarketing = false,
    this.isLoading = false,
  });

  MarketingConsentState copyWith({bool? acceptsMarketing, bool? isLoading}) {
    return MarketingConsentState(
      acceptsMarketing: acceptsMarketing ?? this.acceptsMarketing,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Marketing consent notifier
class MarketingConsentNotifier extends StateNotifier<MarketingConsentState> {
  static const String _storageKey = 'accepts_marketing';

  MarketingConsentNotifier() : super(const MarketingConsentState()) {
    _loadFromStorage();
  }

  /// Load marketing consent from local storage
  Future<void> _loadFromStorage() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final acceptsMarketing = prefs.getBool(_storageKey) ?? false;
      state = MarketingConsentState(acceptsMarketing: acceptsMarketing);
    } catch (e) {
      state = const MarketingConsentState();
    }
  }

  /// Set marketing consent
  Future<void> setMarketingConsent(bool accepts) async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_storageKey, accepts);
      state = MarketingConsentState(acceptsMarketing: accepts);
    } catch (e) {
      // Silently fail - non-critical feature
      state = state.copyWith(isLoading: false);
    }
  }

  /// Get current marketing consent value (for sending to backend)
  bool getMarketingConsent() {
    return state.acceptsMarketing;
  }

  /// Clear marketing consent (for logout)
  Future<void> clearMarketingConsent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      state = const MarketingConsentState();
    } catch (e) {
      // Silently fail
    }
  }
}

/// Marketing consent provider
final marketingConsentProvider =
    StateNotifierProvider<MarketingConsentNotifier, MarketingConsentState>((
      ref,
    ) {
      return MarketingConsentNotifier();
    });
