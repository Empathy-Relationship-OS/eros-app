# Dates module: frontend integration guide

**Audience:** a Claude Code agent implementing the client side of the dates flow in the **Flutter** app.
**Source of truth:** `dates/src/main/kotlin/com/eros/dates/routes/DateRoutes.kt` and `models/DateDTOs.kt` on `main`. Where this doc and the code disagree, the code wins; update this doc.
**Backend status:** T0 to T18 merged to `main` (PR #203), plus the review fixes from `docs/reviews/PR-203-dates-module-review.md` (PRs #204 to #210, merged 2026-09-16). All user-facing endpoints below are live. The wire contract (routes, DTOs, enums, constants) did not change in the fix PRs; only behaviour notes in §4, §7 and §9 were updated.

Read this file top to bottom once. Section 8 is the implementation backlog; each task there is self-contained.

---

## 1. What the backend does for you

A **date** is created automatically when two users mutually like each other. From that point the backend drives a fixed pipeline and the client's job is to (a) show where the date is, (b) collect the user's input at the three points where the user has to act, and (c) let them cancel.

```
mutual match ─► AWAITING_AVAILABILITY ─► AWAITING_DEPOSIT ─► AWAITING_VENUE_RANKING
                    (user acts)             (user acts)           (user acts)
                                                                       │
         ┌─────────────────────────────────────────────────────────────┘
         ▼
   VENUE_ASSIGNED ─► VENUE_CONFIRMATION_PENDING ─► BOOKED ─► AWAITING_PRESENCE_CONFIRMATION ─► READY ─► COMPLETED
      (ops team, no user action)                              (user acts, T-24h)

   Any non-terminal state ─► CANCELLED (user / admin / system)
   Deadline or no-mutual-time ─► EXPIRED
```

Three things the client never has to do: create a date, compute deadlines, or poll a scheduler. Timeouts are evaluated lazily by the backend on every read **and at the start of every mutating action**, so `GET /dates/{id}` always returns the current truth, and a POST against a date whose deadline has just passed returns 409 with the new state named in `message` rather than acting on stale state.

## 2. Transport conventions

- Base path: same host as the rest of the API. All routes below are under `/dates` (user) and `/admin/dates` (ops).
- Auth: `Authorization: Bearer <firebase-id-token>` on every request. User routes require role `USER`.
- JSON via kotlinx.serialization. **Enums are UPPER_SNAKE strings. `Instant` fields are ISO-8601 UTC strings (`"2026-09-20T19:00:00Z"`). `BigDecimal` fields are JSON strings, not numbers (`"5.00"`).** IDs (`dateId`, `matchId`, `venueId`, `activityId`, `cityId`) are integers; user IDs are Firebase UID strings.
- Nullable fields are emitted as `null`, never omitted.
- Errors are always `{ "error": string, "message": string }` with these codes:

| HTTP | `error` | When |
|---|---|---|
| 400 | `bad_request` | Domain validation failed (message is user-readable, e.g. "Insufficient available slots: must mark at least 3 slots as AVAILABLE (you marked 2)") |
| 400 | `invalid_input` | Bad path/query param, or a `require()` guard tripped (see §7 quirks) |
| 400 | `invalid_request_body` / `malformed_request` | Body failed to deserialise |
| 401 | `unauthorized` | Missing or invalid Firebase token |
| 403 | `forbidden` | Caller is not a participant in the date |
| 404 | `not_found` | Date does not exist |
| 409 | `conflict` | Wrong state, already done, deadline passed |
| 409 | `insufficient_balance` | Deposit: not enough tokens |
| 500 | `server_error` / `database_error` | Backend fault |

Treat 409 as "refetch the date and re-render", never as a retry. Because every mutating endpoint applies due lifecycle transitions before acting, a 409 frequently means the date moved on (expired, completed, or the partner acted first) rather than that the client did something wrong.

## 3. Where a date comes from

`PATCH /match/action/{matchId}` with body `{ "liked": true }` returns:

- `204 No Content`: no mutual match, nothing to do.
- `200 OK` with `MutualMatchResponse`:

```json
{ "mutualMatchInfo": { "matchId": 42, "user1Id": "uid-a", "user2Id": "uid-b", "matchedAt": "2026-09-12T10:00:00Z" },
  "dateId": 7 }
```

The date is created in state `AWAITING_AVAILABILITY`. There is no separate "start a date" call.

## 4. Endpoints (user-facing)

### 4.1 `GET /dates?filter=active|past|cancelled`
Returns `DateSummaryDTO[]`. `active` = every non-terminal state; `past` = `COMPLETED`; `cancelled` = `CANCELLED` and `EXPIRED`. No filter returns all. Sorting is not guaranteed; sort client-side by `scheduledStart ?? createdAt`.

### 4.2 `GET /dates/{dateId}`
Returns `DateDetailDTO`. This is the single screen model for the date; it includes the six-step `timeline` (§5). Call it after every mutating action and on every screen focus.

### 4.3 `GET /dates/{dateId}/availability` and `POST /dates/{dateId}/availability`
POST body `SubmitAvailabilityRequest`; both return `AvailabilityViewDTO`.

Rules the backend enforces (mirror them in the UI so users rarely hit a 400):
- Slots are 30-minute grid points, UTC, expressed as the slot **start**: minutes must be `:00` or `:30`, seconds zero.
- Every slot must be at least **48 hours** from now and at most **21 days** from now.
- At least **3** slots marked `AVAILABLE`; at most **200** marked slots in total.
- Tri-state: `AVAILABLE`, `UNAVAILABLE`, or `NO_PREFERENCE`. Sending `NO_PREFERENCE` for a slot **deletes** any previous mark for it; untouched slots are simply not sent. `NO_PREFERENCE` never comes back in a GET.
- A POST replaces the caller's whole submission for the current round.
- Only legal in `AWAITING_AVAILABILITY` (409 otherwise). Re-submitting before the partner has submitted is allowed and replaces.
- A date lasts **120 minutes**, so a slot start at 19:00 means 19:00 to 21:00.

What happens after both submit: the backend picks the earliest slot both marked `AVAILABLE` (tier 1); failing that, the earliest slot one marked `AVAILABLE` and the other left unmarked (tier 2); anything either marked `UNAVAILABLE` is excluded. If a slot is found the date moves to `AWAITING_DEPOSIT` with `scheduledStart`, `scheduledEnd`, `depositDeadline` set. If not, `availabilityRound` becomes 2 and both users must submit again (previous marks are not carried over). After round 2 fails the date is `EXPIRED`. `MAX_AVAILABILITY_ROUNDS = 2`, so "rounds remaining" is `2 - currentRound`.

The response includes `partnerSlots` so the UI can show the partner's marks as a hint once they have submitted (empty list until then).

### 4.4 `POST /dates/{dateId}/deposit`
No body. Debits `tokenCost` tokens from the caller's wallet. Returns `DepositPaymentResponse`. 409 `conflict` if not `AWAITING_DEPOSIT`, already paid, or `depositDeadline` passed; 409 `insufficient_balance` if the wallet cannot cover it (route the user to the wallet top-up flow). When `transitionedToRanking` is `true` the venue options exist and the ranking screen can open immediately.

If the deadline passes with either user unpaid the date becomes `EXPIRED` and whoever paid is refunded automatically.

### 4.5 `GET /dates/{dateId}/venue-options`
Returns `VenueOptionsDTO` with **up to 3** options ordered by `optionOrder` (normally 3; fewer only if the city has fewer eligible venues, see quirk 8), plus `myRankings` (empty until the caller submits). `thumbnailUrl` is always `null` for now. If no venue at all is eligible the backend expires the date (`NO_VENUE_AVAILABLE`) and refunds both deposits, so the client only ever sees this endpoint succeed with 1 to 3 options.

### 4.6 `POST /dates/{dateId}/venue-rankings`
Body `SubmitRankingsRequest`: one entry per offered `venueId`, ranks `1..N` each used once, where N is `options.length` (today the request DTO rejects anything other than exactly 3, see quirk 8). One submission per user (409 on resubmit). Returns `RankingSubmissionResponse`. When `venueAssigned` is true the date is now `VENUE_ASSIGNED` and the ops team takes over; the user's next action is presence confirmation at T-24h. If the partner never ranks, the backend assigns using the available rankings once `rankingDeadline` (48h) passes.

### 4.7 `POST /dates/{dateId}/confirm-presence`
No body. Legal only in `AWAITING_PRESENCE_CONFIRMATION`, which the backend enters automatically once `now >= scheduledStart - 24h` and the date is `BOOKED`. Returns `PresenceConfirmationStatusDTO`. When both confirm the date is `READY`. 409 if already confirmed, wrong state, or outside the window.

Note: the client should only offer the button when `state == AWAITING_PRESENCE_CONFIRMATION`. Do not compute the window locally.

### 4.8 `POST /dates/{dateId}/cancel`
Body `CancelDateRequest`. **Always send a JSON body, at minimum `{}`**; the route unconditionally deserialises one. Legal from any non-terminal state (`cancellable` on the detail DTO tells you). Returns `CancellationResultDTO`. Due transitions are applied first, so a date whose `scheduledEnd` has passed is completed or expired before the cancel is evaluated and the call returns 409; do not offer cancel once `scheduledEnd` is in the past even if the last-fetched `cancellable` was `true`.

Refund rules to surface in the confirmation dialog, keyed on the current state:
- Before both deposits are paid (`AWAITING_AVAILABILITY`, `AWAITING_DEPOSIT`): everyone who paid gets 100% back. Tier `PRE_COMMITMENT`.
- After both paid: the canceller gets **0%**, the partner gets **100%**. Tier `POST_COMMITMENT`, or `LATE` if inside 24h of `scheduledStart` (same money, flagged for future penalties).

The `refunds` map is keyed by user ID. Look up `refunds[myUid]`.

## 5. Timeline projection (the stepper)

`DateDetailDTO.timeline` is always **six** steps in this fixed order: `DATE_TYPE`, `AVAILABILITY`, `DEPOSIT`, `VENUE`, `CONFIRMATION`, `DATE`. Each has `status` in `COMPLETE | CURRENT | PENDING | SKIPPED`. Non-terminal dates have exactly one `CURRENT`; `COMPLETED` has none (all complete); `CANCELLED`/`EXPIRED` have none and mark unreached steps `SKIPPED`. Render the stepper purely from this list; do not derive it from `state`.

The `DEPOSIT` step additionally carries `you` and `partner` (`PAID | PENDING | NOT_APPLICABLE | null`) for a "you paid, waiting on them" row. `completedAt` is best-effort and may be `null` on a complete step.

Mapping `state` to the primary call-to-action:

| `state` | CTA | Endpoint |
|---|---|---|
| `AWAITING_AVAILABILITY` | Pick your times (round `availabilityRound` of 2) | 4.3 |
| `AWAITING_DEPOSIT` | Pay `tokenCost` tokens before `depositDeadline` | 4.4 |
| `AWAITING_VENUE_RANKING` | Rank the 3 venues before `rankingDeadline` | 4.5, 4.6 |
| `VENUE_ASSIGNED`, `VENUE_CONFIRMATION_PENDING` | None. "We're booking your table at {venueName}" | |
| `BOOKED` | None. Show venue, address, `scheduledStart`. "Confirm 24h before" | |
| `AWAITING_PRESENCE_CONFIRMATION` | Confirm you're coming | 4.7 |
| `READY` | None. "You're both confirmed" | |
| `COMPLETED` | None | |
| `CANCELLED`, `EXPIRED` | None. Generic copy; the reason is not exposed (see quirk 9) | |

Cancel is a secondary action whenever `cancellable == true`.

## 6. Models (Dart)

Plain Dart, no codegen required. If the project already uses `freezed`/`json_serializable`, translate these shapes into that style but keep the field names and the enum wire values exactly as below. Put them in `lib/features/dates/data/models/`.

Wire rules the models encode: enums are UPPER_SNAKE strings; `Instant` is an ISO-8601 UTC string, parsed with `DateTime.parse(...)` (already UTC because of the `Z`) and serialised with `toUtc().toIso8601String()`; `BigDecimal` arrives as a **string** such as `"5.00"`, keep it as `String` (or `Decimal` from `package:decimal`) and never `double`; nullable fields are present as `null`.

```dart
// ---------- enums ----------
enum DateState {
  awaitingAvailability, awaitingDeposit, awaitingVenueRanking,
  venueAssigned, venueConfirmationPending, booked,
  awaitingPresenceConfirmation, ready,
  completed, cancelled, expired;

  bool get isTerminal => this == completed || this == cancelled || this == expired;
}

enum SlotAvailability { available, unavailable, noPreference } // noPreference is request-only
enum ParticipantDepositStatus { paid, pending, notApplicable }
enum TimelineStep { dateType, availability, deposit, venue, confirmation, date }
enum StepStatus { complete, current, pending, skipped }
enum CancellationTier { preCommitment, postCommitment, late }
enum CancellationSource { user, admin, system }

/// camelCase enum name <-> UPPER_SNAKE wire value, e.g. awaitingDeposit <-> AWAITING_DEPOSIT.
String enumToWire(Enum e) =>
    e.name.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]}').toUpperCase();

T enumFromWire<T extends Enum>(List<T> values, String wire) =>
    values.firstWhere((v) => enumToWire(v) == wire,
        orElse: () => throw FormatException('Unknown ${T.toString()} value: $wire'));

DateTime? _instant(dynamic v) => v == null ? null : DateTime.parse(v as String);
String _wireInstant(DateTime d) => d.toUtc().toIso8601String();

// ---------- requests ----------
class AvailabilitySlotSubmission {
  final DateTime slotStart; // must be UTC on the 30-minute grid
  final SlotAvailability availability;
  const AvailabilitySlotSubmission({required this.slotStart, required this.availability});
  Map<String, dynamic> toJson() =>
      {'slotStart': _wireInstant(slotStart), 'availability': enumToWire(availability)};
}

class SubmitAvailabilityRequest {
  final List<AvailabilitySlotSubmission> slots;
  const SubmitAvailabilityRequest(this.slots);
  Map<String, dynamic> toJson() => {'slots': slots.map((s) => s.toJson()).toList()};
}

class VenueRankingSubmission {
  final int venueId;
  final int rank; // 1..N, unique
  const VenueRankingSubmission({required this.venueId, required this.rank});
  Map<String, dynamic> toJson() => {'venueId': venueId, 'rank': rank};
}

class SubmitRankingsRequest {
  final List<VenueRankingSubmission> rankings; // one per offered venue
  const SubmitRankingsRequest(this.rankings);
  Map<String, dynamic> toJson() => {'rankings': rankings.map((r) => r.toJson()).toList()};
}

class CancelDateRequest {
  final String? reason;
  const CancelDateRequest({this.reason});
  Map<String, dynamic> toJson() => {'reason': reason}; // always send a body, even {"reason": null}
}

// ---------- responses ----------
class ApiError implements Exception {
  final int status;
  final String error;   // e.g. "conflict", "insufficient_balance", "bad_request"
  final String message; // user-readable for bad_request; show verbatim as a fallback
  const ApiError(this.status, this.error, this.message);
  factory ApiError.fromJson(int status, Map<String, dynamic> j) =>
      ApiError(status, j['error'] as String, j['message'] as String);
}

class DateSummary {
  final int dateId, matchId;
  final String partnerId, partnerName;
  final String? partnerThumbnailUrl;
  final DateState state;
  final DateTime createdAt;
  final DateTime? scheduledStart;
  final String? venueName;
  final String activityName;
  const DateSummary({required this.dateId, required this.matchId, required this.partnerId,
      required this.partnerName, this.partnerThumbnailUrl, required this.state,
      required this.createdAt, this.scheduledStart, this.venueName, required this.activityName});
  factory DateSummary.fromJson(Map<String, dynamic> j) => DateSummary(
        dateId: j['dateId'] as int, matchId: j['matchId'] as int,
        partnerId: j['partnerId'] as String, partnerName: j['partnerName'] as String,
        partnerThumbnailUrl: j['partnerThumbnailUrl'] as String?,
        state: enumFromWire(DateState.values, j['state'] as String),
        createdAt: _instant(j['createdAt'])!, scheduledStart: _instant(j['scheduledStart']),
        venueName: j['venueName'] as String?, activityName: j['activityName'] as String,
      );
}

class TimelineStepDto {
  final TimelineStep step;
  final StepStatus status;
  final String label;
  final DateTime? completedAt;
  final ParticipantDepositStatus? you, partner; // DEPOSIT step only
  const TimelineStepDto({required this.step, required this.status, required this.label,
      this.completedAt, this.you, this.partner});
  factory TimelineStepDto.fromJson(Map<String, dynamic> j) => TimelineStepDto(
        step: enumFromWire(TimelineStep.values, j['step'] as String),
        status: enumFromWire(StepStatus.values, j['status'] as String),
        label: j['label'] as String, completedAt: _instant(j['completedAt']),
        you: j['you'] == null ? null : enumFromWire(ParticipantDepositStatus.values, j['you'] as String),
        partner: j['partner'] == null ? null : enumFromWire(ParticipantDepositStatus.values, j['partner'] as String),
      );
}

class DepositStatus {
  final ParticipantDepositStatus user1, user2;
  const DepositStatus({required this.user1, required this.user2});
  factory DepositStatus.fromJson(Map<String, dynamic> j) => DepositStatus(
        user1: enumFromWire(ParticipantDepositStatus.values, j['user1'] as String),
        user2: enumFromWire(ParticipantDepositStatus.values, j['user2'] as String),
      );
}

class DateDetail {
  final int dateId, matchId, activityId, cityId, availabilityRound;
  final String user1Id, user2Id, activityName, cityName;
  final String tokenCost; // decimal string, e.g. "5.00"
  final DateState state;
  final DateTime? scheduledStart, scheduledEnd, depositDeadline, rankingDeadline, venueBookedAt;
  final int? venueId;
  final String? venueName, venueAddress, bookingReference;
  final DepositStatus depositStatus;
  final bool cancellable;
  final List<TimelineStepDto> timeline; // always 6, fixed order
  final DateTime createdAt, updatedAt;

  const DateDetail({required this.dateId, required this.matchId, required this.user1Id,
      required this.user2Id, required this.activityId, required this.activityName,
      required this.tokenCost, required this.cityId, required this.cityName, required this.state,
      required this.availabilityRound, this.scheduledStart, this.scheduledEnd, this.depositDeadline,
      this.rankingDeadline, this.venueId, this.venueName, this.venueAddress, this.venueBookedAt,
      this.bookingReference, required this.depositStatus, required this.cancellable,
      required this.timeline, required this.createdAt, required this.updatedAt});

  factory DateDetail.fromJson(Map<String, dynamic> j) => DateDetail(
        dateId: j['dateId'] as int, matchId: j['matchId'] as int,
        user1Id: j['user1Id'] as String, user2Id: j['user2Id'] as String,
        activityId: j['activityId'] as int, activityName: j['activityName'] as String,
        tokenCost: j['tokenCost'] as String,
        cityId: j['cityId'] as int, cityName: j['cityName'] as String,
        state: enumFromWire(DateState.values, j['state'] as String),
        availabilityRound: j['availabilityRound'] as int,
        scheduledStart: _instant(j['scheduledStart']), scheduledEnd: _instant(j['scheduledEnd']),
        depositDeadline: _instant(j['depositDeadline']), rankingDeadline: _instant(j['rankingDeadline']),
        venueId: j['venueId'] as int?, venueName: j['venueName'] as String?,
        venueAddress: j['venueAddress'] as String?, venueBookedAt: _instant(j['venueBookedAt']),
        bookingReference: j['bookingReference'] as String?,
        depositStatus: DepositStatus.fromJson(j['depositStatus'] as Map<String, dynamic>),
        cancellable: j['cancellable'] as bool,
        timeline: (j['timeline'] as List).map((e) => TimelineStepDto.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: _instant(j['createdAt'])!, updatedAt: _instant(j['updatedAt'])!,
      );

  // Helpers every screen needs.
  String partnerId(String myUid) => user1Id == myUid ? user2Id : user1Id;
  ParticipantDepositStatus myDeposit(String myUid) => user1Id == myUid ? depositStatus.user1 : depositStatus.user2;
  ParticipantDepositStatus partnerDeposit(String myUid) => user1Id == myUid ? depositStatus.user2 : depositStatus.user1;
}

class SlotDto {
  final DateTime slotStart;
  final SlotAvailability availability; // only available / unavailable come back
  const SlotDto({required this.slotStart, required this.availability});
  factory SlotDto.fromJson(Map<String, dynamic> j) => SlotDto(
        slotStart: _instant(j['slotStart'])!,
        availability: enumFromWire(SlotAvailability.values, j['availability'] as String),
      );
}

class AvailabilityView {
  final int dateId, currentRound;
  final List<SlotDto> mySlots, partnerSlots;
  const AvailabilityView({required this.dateId, required this.currentRound,
      required this.mySlots, required this.partnerSlots});
  factory AvailabilityView.fromJson(Map<String, dynamic> j) => AvailabilityView(
        dateId: j['dateId'] as int, currentRound: j['currentRound'] as int,
        mySlots: (j['mySlots'] as List).map((e) => SlotDto.fromJson(e as Map<String, dynamic>)).toList(),
        partnerSlots: (j['partnerSlots'] as List).map((e) => SlotDto.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class DepositPaymentResponse {
  final String newBalance; // decimal string
  final bool bothPaid, transitionedToRanking;
  const DepositPaymentResponse({required this.newBalance, required this.bothPaid, required this.transitionedToRanking});
  factory DepositPaymentResponse.fromJson(Map<String, dynamic> j) => DepositPaymentResponse(
        newBalance: j['newBalance'] as String, bothPaid: j['bothPaid'] as bool,
        transitionedToRanking: j['transitionedToRanking'] as bool);
}

class VenueOption {
  final int venueId, optionOrder;
  final String name, address;
  final String? thumbnailUrl; // always null today
  const VenueOption({required this.venueId, required this.name, required this.address, this.thumbnailUrl, required this.optionOrder});
  factory VenueOption.fromJson(Map<String, dynamic> j) => VenueOption(
        venueId: j['venueId'] as int, name: j['name'] as String, address: j['address'] as String,
        thumbnailUrl: j['thumbnailUrl'] as String?, optionOrder: j['optionOrder'] as int);
}

class VenueRanking {
  final int venueId, rank;
  const VenueRanking({required this.venueId, required this.rank});
  factory VenueRanking.fromJson(Map<String, dynamic> j) => VenueRanking(venueId: j['venueId'] as int, rank: j['rank'] as int);
}

class VenueOptions {
  final int dateId;
  final List<VenueOption> options;   // 1..3, sorted by optionOrder
  final List<VenueRanking> myRankings; // empty until the caller submits
  const VenueOptions({required this.dateId, required this.options, required this.myRankings});
  factory VenueOptions.fromJson(Map<String, dynamic> j) => VenueOptions(
        dateId: j['dateId'] as int,
        options: (j['options'] as List).map((e) => VenueOption.fromJson(e as Map<String, dynamic>)).toList()
          ..sort((a, b) => a.optionOrder.compareTo(b.optionOrder)),
        myRankings: (j['myRankings'] as List).map((e) => VenueRanking.fromJson(e as Map<String, dynamic>)).toList());
}

class RankingSubmissionResponse {
  final bool bothSubmitted, venueAssigned;
  final int? assignedVenueId;
  const RankingSubmissionResponse({required this.bothSubmitted, required this.venueAssigned, this.assignedVenueId});
  factory RankingSubmissionResponse.fromJson(Map<String, dynamic> j) => RankingSubmissionResponse(
        bothSubmitted: j['bothSubmitted'] as bool, venueAssigned: j['venueAssigned'] as bool,
        assignedVenueId: j['assignedVenueId'] as int?);
}

class ParticipantPresence {
  final String userId;
  final bool confirmed;
  final DateTime? confirmedAt;
  const ParticipantPresence({required this.userId, required this.confirmed, this.confirmedAt});
  factory ParticipantPresence.fromJson(Map<String, dynamic> j) => ParticipantPresence(
        userId: j['userId'] as String, confirmed: j['confirmed'] as bool, confirmedAt: _instant(j['confirmedAt']));
}

class PresenceConfirmationStatus {
  final int dateId;
  final ParticipantPresence user1, user2;
  const PresenceConfirmationStatus({required this.dateId, required this.user1, required this.user2});
  factory PresenceConfirmationStatus.fromJson(Map<String, dynamic> j) => PresenceConfirmationStatus(
        dateId: j['dateId'] as int,
        user1: ParticipantPresence.fromJson(j['user1'] as Map<String, dynamic>),
        user2: ParticipantPresence.fromJson(j['user2'] as Map<String, dynamic>));
  ParticipantPresence me(String myUid) => user1.userId == myUid ? user1 : user2;
  ParticipantPresence partner(String myUid) => user1.userId == myUid ? user2 : user1;
}

class Refund {
  final String userId;
  final String amount; // decimal string
  final int? transactionId;
  const Refund({required this.userId, required this.amount, this.transactionId});
  factory Refund.fromJson(Map<String, dynamic> j) =>
      Refund(userId: j['userId'] as String, amount: j['amount'] as String, transactionId: j['transactionId'] as int?);
}

class CancellationResult {
  final int dateId;
  final CancellationTier tier;
  final Map<String, Refund> refunds; // keyed by userId
  final CancellationSource cancellationSource;
  final DateTime cancelledAt;
  const CancellationResult({required this.dateId, required this.tier, required this.refunds,
      required this.cancellationSource, required this.cancelledAt});
  factory CancellationResult.fromJson(Map<String, dynamic> j) => CancellationResult(
        dateId: j['dateId'] as int,
        tier: enumFromWire(CancellationTier.values, j['tier'] as String),
        refunds: (j['refunds'] as Map<String, dynamic>).map((k, v) => MapEntry(k, Refund.fromJson(v as Map<String, dynamic>))),
        cancellationSource: enumFromWire(CancellationSource.values, j['cancellationSource'] as String),
        cancelledAt: _instant(j['cancelledAt'])!);
  Refund? mine(String myUid) => refunds[myUid];
}

// From PATCH /match/action/{matchId} on a mutual match (200). 204 means no match.
class MutualMatchResponse {
  final int matchId, dateId;
  final String user1Id, user2Id;
  final DateTime matchedAt;
  const MutualMatchResponse({required this.matchId, required this.dateId, required this.user1Id, required this.user2Id, required this.matchedAt});
  factory MutualMatchResponse.fromJson(Map<String, dynamic> j) {
    final m = j['mutualMatchInfo'] as Map<String, dynamic>;
    return MutualMatchResponse(matchId: m['matchId'] as int, user1Id: m['user1Id'] as String,
        user2Id: m['user2Id'] as String, matchedAt: _instant(m['matchedAt'])!, dateId: j['dateId'] as int);
  }
}
```

Constants the client may hardcode (they are backend constants in `dates/DatesConstants.kt`; put them in one `DatesConstants` Dart class): slot grid 30 min, date duration 120 min, min lead 48 h, horizon 21 days, min 3 available slots, max 200 marked slots, 2 availability rounds, 48 h deposit window, 48 h ranking window, 24 h presence window, 3 venue options.

Slot grid helper the availability picker needs, so the UI can never produce a misaligned slot:

```dart
/// Round a local DateTime down to the nearest 30-minute UTC grid point.
DateTime snapToGrid(DateTime t) {
  final u = t.toUtc();
  return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute - (u.minute % 30));
}
```

## 7. Quirks and gotchas (current behaviour on `main`)

1. `GET /dates/{id}/venue-options` by a non-participant returns **400 `invalid_input`**, not 403; when options have not been generated yet it returns **500 `server_error`**, not 404. Only call it when `state == AWAITING_VENUE_RANKING` or later and you will not see either.
2. `POST /venue-rankings` in the wrong state returns **400 `invalid_input`** rather than 409. Treat both as "refetch".
3. `POST /cancel` with no body fails with 400 `malformed_request`. Send `{}`.
4. `partnerSlots` is only meaningful after the partner submits; it is not a "partner is typing" signal.
5. `availabilityRound` resets nothing on the client; if it went from 1 to 2 the user must re-enter slots from scratch.
6. `DateSummaryDTO` has no `partnerId`-relative deadline fields. If the list needs "pay by" badges, fetch detail or wait for a backend follow-up.
7. There is no push or websocket. Partner progress (they paid, they ranked, they confirmed) is only visible by refetching. Refetch on screen focus and after every own action; optionally poll every 30 to 60 s while a date is in a "waiting on partner" state.
8. `SubmitRankingsRequest` validates `rankings.size == 3` at deserialisation, but option generation can persist only 1 or 2 options when the city is short of venues; such a date cannot be ranked until the backend relaxes the DTO to `1..options.size`. Build the ranking UI for N options and send N rankings; do not pad.
9. Neither `expiryReason` nor `cancellationReason` is on `DateDetailDTO`, so the terminal screen cannot say why. `EXPIRED` covers: no mutual time after 2 rounds, deposit deadline missed, no venue available, and (new in #209) ops never booked the venue before the date; all but the first refund every paid deposit automatically. `CANCELLED` covers user, admin and system cancels. If product wants distinct copy, adding both fields to the DTO is a backend follow-up.

Backend follow-ups these imply (not the client's job; they are items L1 to L3 in `docs/reviews/PR-203-dates-module-review.md` and are still open as of #210): map `IllegalArgumentException`/`IllegalStateException` in `DateRoutes.kt` venue-options and `VenueSelectionServiceImpl` to `ForbiddenException`/`ConflictException`/`NotFoundException`; make `CancelDateRequest` optional in the route; relax `SubmitRankingsRequest.init` to validate against the offered option count instead of the `VENUE_OPTION_COUNT` constant. The admin role guard (C1) is fixed as of #204.

## 8. Implementation backlog for the client agent

Do these in order; each is one PR. "Done" means the listed acceptance checks pass against a local backend (`./gradlew run` with seeded venues; see `dates/src/test/kotlin/com/eros/dates/integration/README.md` for how the integration tests seed data over HTTP).

**FE-1 Models and API client.** Add the §6 Dart models under `lib/features/dates/data/models/` and a `DatesApi` (using whatever HTTP client the app already uses, `dio` or `http`) with one method per endpoint in §4, plus `matchAction` returning `MutualMatchResponse?` (204 → null). Non-2xx responses throw `ApiError`. Serialise every `DateTime` via `toUtc().toIso8601String()`, never local offsets. Acceptance: unit tests that a `DateDetail` JSON fixture parses with all 6 timeline steps, that `enumToWire`/`enumFromWire` round-trip every enum, and that a 409 `insufficient_balance` body becomes an `ApiError` with `error == 'insufficient_balance'`.

**FE-2 Match to date handoff.** On `200` from `matchAction`, navigate to the date detail screen for `dateId`. Acceptance: mutual like lands on a screen showing `AWAITING_AVAILABILITY`.

**FE-3 Dates list.** Tabs Active / Past / Cancelled backed by `?filter=`. Row shows partner thumbnail and name, `activityName`, `scheduledStart` if set, `venueName` if set, and a state chip. Acceptance: three tabs render the right subsets; empty states exist.

**FE-4 Date detail and stepper.** Render `timeline` as a six-step vertical stepper straight from the list (§5); a `Stepper`-free custom column is fine. Below it, a state-driven CTA panel per the §5 table, switched on `DateState`. Refetch when the route regains focus (`RouteAware`/`didPopNext` or an app-lifecycle listener) and after every action. Acceptance: for a fixture of each of the 11 states the correct CTA (or none) is shown and exactly one step is `CURRENT` for non-terminal states.

**FE-5 Availability picker.** Calendar/grid over the window `[now+48h, now+21d]` shown in the user's local timezone, every cell backed by a UTC `DateTime` from `snapToGrid`. Three-state tap cycle: unmarked → AVAILABLE → UNAVAILABLE → unmarked (unmarked sends `NO_PREFERENCE` only for slots that were previously marked, else omit). Local validation: at least 3 AVAILABLE, at most 200 marked. Show round `n` of 2 and, after the partner submits, overlay `partnerSlots`. Submit → refetch detail; if state is now `AWAITING_DEPOSIT` go to FE-6, if `availabilityRound` incremented show "no overlap, try again", if `EXPIRED` show the terminal screen. Acceptance: submitting 2 available slots is blocked locally; a misaligned slot cannot be produced by the UI; backend 400 messages are shown verbatim as a fallback.

**FE-6 Deposit.** Show `tokenCost`, current wallet balance, `depositDeadline` countdown, and partner deposit status from `depositStatus`. Pay → on `insufficient_balance` deep-link to top-up; on success update the balance from `newBalance` and, if `transitionedToRanking`, go to FE-7. Acceptance: both branches exercised; a second tap after success is a no-op (409 handled).

**FE-7 Venue ranking.** Fetch options; `ReorderableListView` over the N returned venues (N is 1 to 3), rank = position + 1; submit exactly N unique ranks `1..N`. If `myRankings` is non-empty on load, show read-only "waiting on partner". On `venueAssigned` show the assigned venue. Acceptance: cannot submit a partial ranking; resubmission attempt is disabled.

**FE-8 Booking and presence.** For `VENUE_ASSIGNED`/`VENUE_CONFIRMATION_PENDING`/`BOOKED` show the read-only booking card (venue, address, `scheduledStart`/`End` localised, `bookingReference` when present). For `AWAITING_PRESENCE_CONFIRMATION` show the confirm button and both participants' status from the response; on `READY` show the confirmed state. Acceptance: button only appears in `AWAITING_PRESENCE_CONFIRMATION`; after confirming, the partner-pending row is visible.

**FE-9 Cancel.** Secondary action wherever `cancellable`. Confirmation dialog whose copy is chosen by the refund rule in §4.8 (derive tier client-side from state and `scheduledStart` only for the dialog copy; trust the response for what actually happened). Optional reason field. Send `{}` when no reason. Acceptance: pre- and post-commitment copy verified; the result screen shows `result.mine(myUid)?.amount`.

**FE-10 Terminal and error states.** `COMPLETED`, `CANCELLED`, `EXPIRED` screens; generic handling that maps 401 → re-auth, 403/404 → back to list with toast, 409 and the §7 400s → refetch. Acceptance: no unhandled error surfaces as a crash.

Out of scope for the client: venue photos (backend returns `null`), notifications, disputes, feedback, reputation (RFC-001 items not in the MVP), and anything under `/admin/dates`.

## 9. Admin surface (for a later ops UI, not the consumer app)

All under `/admin/dates`, Firebase-authenticated and guarded by `requireRoles("ADMIN", "EMPLOYEE")`; a `USER` token gets 403. `GET /bookings?daysAhead=7` and `GET /cancelled?daysAhead=7` return `BookingSheetDTO` (dates grouped by venue with contact info); `GET /{dateId}` returns `AdminDateDetailDTO` (detail plus full state history); `POST /{dateId}/venue/contacted` `{contactedAt}`; `POST /{dateId}/booking` `{bookingReference, bookedAt, notes?}`; `POST /{dateId}/venue/release` `{reason, replacementVenueId?}` returning `VenueReleaseResultDTO`; `POST /sweep` applies all due timeouts (capped at 500 dates). Shapes are in `DateDTOs.kt`.
