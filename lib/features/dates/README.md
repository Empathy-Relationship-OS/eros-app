# Dates Module - Frontend Integration

This README documents the Muse Flutter app's architecture patterns for implementing the dates feature (UI-0 discovery task).

## 1. State Management

**Pattern:** Riverpod with StateNotifier for complex state

- `StateNotifier<T>` for feature state that requires business logic
- `Provider` for services and repositories
- `FutureProvider` for async data fetching
- `StateProvider` for simple state

**Example from wallet:**
```dart
class PurchaseNotifier extends StateNotifier<PurchaseState> {
  final WalletRepository _walletRepository;
  final Ref _ref;

  PurchaseNotifier(this._walletRepository, this._ref)
    : super(const PurchaseState());
}

final purchaseProvider = StateNotifierProvider.autoDispose<PurchaseNotifier, PurchaseState>((ref) {
  final walletRepository = ref.watch(walletRepositoryProvider);
  return PurchaseNotifier(walletRepository, ref);
});
```

**For dates module:**
- Use `StateNotifier` for date list state, date detail state, availability picker state
- Use `FutureProvider` for initial date fetches
- Use `.autoDispose` for screen-level providers to prevent memory leaks

## 2. Router

**Pattern:** MaterialApp with named routes (defined in `main.dart`)

- Routes declared in `routes:` map
- Navigation via `Navigator.pushNamed()` or `MaterialPageRoute()`
- Arguments passed via `RouteSettings.arguments` and retrieved in `onGenerateRoute`

**Example from main.dart:**
```dart
routes: {
  '/match': (context) => const HomeScreen(),
  '/profile/preview': (context) => const ProfilePreviewScreen(),
}

onGenerateRoute: (settings) {
  if (settings.name == '/profile-creation/qa/answer') {
    final question = settings.arguments as QuestionDTO;
    return MaterialPageRoute(
      builder: (context) => AnswerInputScreen(question: question),
    );
  }
  return null;
}
```

**For dates module:**
- Main dates tab: Already exists in `HomeScreen` bottom nav (index 1)
- Detail route: `/dates/:dateId` - implement in `onGenerateRoute` accepting `dateId` as argument
- History route: Push via `MaterialPageRoute` (no need for named route)
- Picker routes: Push via `MaterialPageRoute` with state passed as constructor arguments

**Route regained focus:** Deferred - no existing pattern in app yet. Will implement when needed.

## 3. HTTP Client

**Pattern:** ApiClient (Dio wrapper) with automatic Firebase auth injection

- Located: `lib/core/network/api_client.dart`
- Auto-injects Firebase ID token via `AuthInterceptor`
- Endpoints defined in `lib/core/network/api_endpoints.dart` (strongly-typed)
- Error handling via `ApiException` hierarchy

**Example:**
```dart
class MatchRepository {
  final ApiClient _apiClient;

  Future<DailyBatchResponse?> fetchDailyBatch() async {
    final response = await _apiClient.get<Map<String, dynamic>?>(
      ApiEndpoints.match.fetchBatch(),
    );
    return response == null ? null : DailyBatchResponse.fromJson(response);
  }
}
```

**For dates module:**
- Add endpoint methods to `_DatesEndpoints` class (already exists as placeholder)
- Create `DatesRepository` following same pattern as `MatchRepository`
- Use `_logger.d()` for debug logging with emojis (📅, 🔍, ✅, 🚨)
- Catch specific exceptions: `ValidationException`, `ConflictException`, `NotFoundException`

## 4. Current User UID

**Access via:** `AuthService.getUserId()`

**Provider:**
```dart
final authService = ref.watch(authServiceProvider);
final currentUid = authService.getUserId(); // Throws if not authenticated
```

**Usage:** Every `DateDetail` helper method needs the current UID to determine "me" vs "partner"

## 5. Theme & Reusable Components

### Color Scheme
**Brand:** Warm orange gradient (Muse branding)
- Primary: `AppColors.primary` / `AppColors.primaryOrange` (#FF8A65)
- Background: `AppColors.background` (#FFF4EE - subtle warm tint)
- Card: `AppColors.cardBackground` (white)
- Text: `AppColors.textPrimary` (black), `textSecondary` (grey), `textTertiary` (light grey)
- Success: `AppColors.success` (green)
- Error: `AppColors.error` (red)

### Spacing Scale
8, 12, 16, 20, 24, 32, 48

### Border Radius
- Cards/buttons: 12px (`BorderRadius.circular(12)`)
- Bottom sheets: 20px top corners

### Existing Components ✅

**ProfileProgressBar** (`lib/features/profile/presentation/widgets/profile_progress_bar.dart`)
- Linear progress with step count and percentage
- Can be adapted for date flow if needed

**Card theming:**
```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  ),
)
```

**ElevatedButton:**
- Styled with orange primary background
- White foreground text
- 12px border radius
- Disabled state: `AppColors.disabled`

**BottomSheet:**
- Theme defined in `AppTheme.bottomSheetTheme`
- 20px top border radius
- White background, elevation 4

### Components Created ✅

**DateStatusPill** - Status pill widget ✅
- Outline pill with trailing info icon
- Multiple tones: action (orange), waiting (grey), success (green), neutral, muted
- Location: `lib/features/dates/presentation/widgets/date_status_pill.dart`

**PartnerHeader** - Partner avatar widget ✅
- Square with large radius (16px)
- Initial-letter fallback when photo URL is null
- Location: `lib/features/dates/presentation/widgets/partner_header.dart`

**DatesEmptyState** - Empty state for dates tab ✅
- Icon + heading + stepper + "How Muse works" button
- Used for "What happens after you match?" (UI-2)
- Location: `lib/features/dates/presentation/widgets/dates_empty_state.dart`

**Other Shared Widgets Created:**
- `DateStepper` - Timeline stepper (full & compact variants)
- `DateFacts` - Icon rows for time, venue, activity
- `DateFormats` - Date/time formatting utilities
- `DeadlineCountdown` - Live countdown widget
- `TokenAmount` - Token amount formatting
- `DatesCopy` - Centralized UI strings

### Screens Implemented ✅

**UI-0 through UI-4 Complete:**
- ✅ Discovery & documentation (README.md)
- ✅ Shared widgets (9 widgets created)
- ✅ Empty state (DatesEmptyState)
- ✅ Active dates list & history (DatesScreen, DateHistoryScreen)
- ✅ Date detail screen (DateDetailScreen)

**Pending (UI-5 through UI-12):**
- ❌ Availability picker (UI-5)
- ❌ Deposit sheet (UI-6)
- ❌ Venue ranking (UI-7)
- ❌ Booking card and presence confirmation (UI-8)
- ❌ Cancel flow (UI-9)
- ❌ Terminal panels (UI-10)
- ❌ Match to date handoff (UI-11)
- ❌ Polish pass (UI-12)

## 6. Wallet

**Balance Provider:** `walletBalanceProvider` (StateNotifier)

**Access:**
```dart
final walletState = ref.watch(walletBalanceProvider);
final balance = walletState.balance?.availableBalance ?? '0.00';
```

**Top-up Route:**
- Screen: `PaymentScreen` (lib/features/wallet/presentation/screens/payment_screen.dart)
- Navigation: Push via `MaterialPageRoute` with package selection via `purchaseProvider`
- **For dates deposit deep-link:** Pass `returnRoute` argument to indicate where to return after top-up

**Top-up pattern for UI-6:**
```dart
// When balance insufficient, navigate to wallet top-up
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => const WalletScreen(), // Or PaymentScreen if package pre-selected
  ),
);
// On return, the depositProvider should refetch balance and retry deposit
```

## 7. Matches Screen Integration

**Location:** `lib/features/matching/presentation/screens/match_screen.dart`

**Match Action Call:**
```dart
final mutualMatch = await ref.read(matchRepositoryProvider).takeMatchAction(matchId, liked);

if (mutualMatch != null) {
  // Returns MutualMatchInfo with matchId, user1Id, user2Id, matchedAt
  // Backend also returns dateId in MutualMatchResponse (per integration doc)
}
```

**Note:** Currently `MatchRepository.takeMatchAction()` returns `MutualMatchInfo?` but does NOT include `dateId`. The integration doc specifies that `PATCH /match/action/{matchId}` should return:

```json
{
  "mutualMatchInfo": {...},
  "dateId": 7
}
```

**Action needed:** Update `MutualMatchInfo` model or create `MutualMatchResponse` wrapper that includes `dateId` field. This is required for UI-11 (Match to date handoff).

## 8. Repository Pattern

All repositories follow this structure:

1. Inject `ApiClient` via constructor
2. Use `ApiEndpoints` for endpoint strings (never hardcode)
3. Catch `ApiException` subclasses for specific error handling
4. Add descriptive logging with emojis
5. Return `null` for 204 responses when appropriate
6. Let exceptions bubble to UI for user-facing messages

**Template for DatesRepository:**
```dart
class DatesRepository {
  final ApiClient _apiClient;
  final Logger _logger = Logger();

  DatesRepository(this._apiClient);

  Future<List<DateSummary>> fetchActiveDates() async {
    try {
      _logger.d('📅 Fetching active dates');

      final response = await _apiClient.get<List<dynamic>>(
        ApiEndpoints.dates.getList(filter: 'active'),
      );

      final dates = response
        .map((json) => DateSummary.fromJson(json as Map<String, dynamic>))
        .toList();

      _logger.d('✅ Fetched ${dates.length} active dates');
      return dates;
    } on ApiException catch (e) {
      _logger.e('🚨 Failed to fetch active dates', error: e);
      rethrow;
    }
  }
}
```

## 9. Testing Approach

**Widget Tests:** Used for critical flows
- Example: `test/features/profile/presentation/widgets/` (if they exist)
- For dates: Test state transitions, pill text, stepper rendering

**Integration Tests:** Not currently in use

**Golden Tests:** Not currently in use

**For dates module:** Start with basic widget tests for critical components (stepper, status pills, empty states). Defer golden tests for polish pass (UI-12).

## 10. File Structure

```
lib/features/dates/
├── data/
│   ├── models/
│   │   └── date_models.dart         # All DTOs, enums, helpers
│   └── repositories/
│       └── dates_repository.dart     # API calls
├── domain/
│   └── (not used in current app pattern)
└── presentation/
    ├── providers/
    │   ├── dates_list_provider.dart
    │   ├── date_detail_provider.dart
    │   └── availability_provider.dart
    ├── screens/
    │   ├── dates_tab_screen.dart
    │   ├── date_detail_screen.dart
    │   ├── date_history_screen.dart
    │   ├── availability_picker_screen.dart
    │   ├── deposit_sheet.dart
    │   └── venue_ranking_screen.dart
    └── widgets/
        ├── date_stepper.dart
        ├── date_status_pill.dart
        ├── deadline_countdown.dart
        ├── partner_header.dart
        ├── date_facts.dart
        ├── token_amount.dart
        ├── date_formats.dart
        └── dates_copy.dart
```

## 11. Next Steps (Implementation Backlog)

Following the order in `dates-ui-tickets.md`:

- [x] **UI-0:** This README
- [ ] **UI-1:** Shared widgets and formatting
- [ ] **UI-2:** Empty state ("What happens after you match?")
- [ ] **UI-3:** Active date card(s) and history
- [ ] **UI-4:** Date detail screen with stepper and CTA panel
- [ ] **UI-5:** Availability picker
- [ ] **UI-6:** Deposit sheet
- [ ] **UI-7:** Venue ranking
- [ ] **UI-8:** Booking card and presence confirmation
- [ ] **UI-9:** Cancel flow
- [ ] **UI-10:** Terminal panels
- [ ] **UI-11:** Match to date handoff
- [ ] **UI-12:** Polish pass

## 12. Open Questions

1. **Route regained focus detection:** Deferred until we see how refetch patterns work in practice
2. **Bottom nav badge for dates tab:** Exists in `HomeScreen`, need to add badge logic when active dates have "action" pill tone
3. **MutualMatchResponse with dateId:** Need to verify backend returns this field or update model accordingly
