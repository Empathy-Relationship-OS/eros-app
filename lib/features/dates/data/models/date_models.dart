/// Date models and DTOs for the dates feature
/// Translates wire format (Kotlin backend) to Dart
///
/// Wire conventions:
/// - Enums: UPPER_SNAKE strings
/// - Instant: ISO-8601 UTC strings ("2026-09-20T19:00:00Z")
/// - BigDecimal: JSON strings ("5.00"), not numbers
/// - Nullable fields: present as null, never omitted

// ====================
// ENUMS
// ====================

enum DateState {
  awaitingAvailability,
  awaitingDeposit,
  awaitingVenueRanking,
  venueAssigned,
  venueConfirmationPending,
  booked,
  awaitingPresenceConfirmation,
  ready,
  completed,
  cancelled,
  expired;

  bool get isTerminal =>
      this == DateState.completed ||
      this == DateState.cancelled ||
      this == DateState.expired;
}

enum SlotAvailability {
  available,
  unavailable,
  noPreference; // Request-only, never returned by backend
}

enum ParticipantDepositStatus {
  paid,
  pending,
  notApplicable,
}

enum TimelineStep {
  dateType,
  availability,
  deposit,
  venue,
  confirmation,
  date,
}

enum StepStatus {
  complete,
  current,
  pending,
  skipped,
}

enum CancellationTier {
  preCommitment,
  postCommitment,
  late,
}

enum CancellationSource {
  user,
  admin,
  system,
}

// ====================
// ENUM HELPERS
// ====================

/// Convert camelCase enum to UPPER_SNAKE wire format
/// Example: awaitingDeposit -> AWAITING_DEPOSIT
String enumToWire(Enum e) =>
    e.name.replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m[0]}').toUpperCase();

/// Convert UPPER_SNAKE wire format to camelCase enum
/// Example: AWAITING_DEPOSIT -> awaitingDeposit
T enumFromWire<T extends Enum>(List<T> values, String wire) =>
    values.firstWhere(
      (v) => enumToWire(v) == wire,
      orElse: () =>
          throw FormatException('Unknown ${T.toString()} value: $wire'),
    );

/// Parse nullable Instant (ISO-8601 UTC string) to DateTime
DateTime? _instant(dynamic v) => v == null ? null : DateTime.parse(v as String);

/// Serialize DateTime to wire format (ISO-8601 UTC string)
String _wireInstant(DateTime d) => d.toUtc().toIso8601String();

// ====================
// REQUEST MODELS
// ====================

/// Slot submission for availability picker
class AvailabilitySlotSubmission {
  final DateTime slotStart; // Must be UTC on the 30-minute grid
  final SlotAvailability availability;

  const AvailabilitySlotSubmission({
    required this.slotStart,
    required this.availability,
  });

  Map<String, dynamic> toJson() => {
        'slotStart': _wireInstant(slotStart),
        'availability': enumToWire(availability),
      };
}

/// Request to submit availability slots
class SubmitAvailabilityRequest {
  final List<AvailabilitySlotSubmission> slots;

  const SubmitAvailabilityRequest(this.slots);

  Map<String, dynamic> toJson() =>
      {'slots': slots.map((s) => s.toJson()).toList()};
}

/// Venue ranking submission
class VenueRankingSubmission {
  final int venueId;
  final int rank; // 1..N, unique

  const VenueRankingSubmission({required this.venueId, required this.rank});

  Map<String, dynamic> toJson() => {'venueId': venueId, 'rank': rank};
}

/// Request to submit venue rankings
class SubmitRankingsRequest {
  final List<VenueRankingSubmission> rankings; // One per offered venue

  const SubmitRankingsRequest(this.rankings);

  Map<String, dynamic> toJson() =>
      {'rankings': rankings.map((r) => r.toJson()).toList()};
}

/// Request to cancel a date
class CancelDateRequest {
  final String? reason;

  const CancelDateRequest({this.reason});

  Map<String, dynamic> toJson() =>
      {'reason': reason}; // Always send body, even {"reason": null}
}

// ====================
// RESPONSE MODELS
// ====================

/// Date summary for list views
class DateSummary {
  final int dateId;
  final int matchId;
  final String partnerId;
  final String partnerName;
  final String? partnerThumbnailUrl;
  final DateState state;
  final DateTime createdAt;
  final DateTime? scheduledStart;
  final String? venueName;
  final String activityName;

  const DateSummary({
    required this.dateId,
    required this.matchId,
    required this.partnerId,
    required this.partnerName,
    this.partnerThumbnailUrl,
    required this.state,
    required this.createdAt,
    this.scheduledStart,
    this.venueName,
    required this.activityName,
  });

  factory DateSummary.fromJson(Map<String, dynamic> json) => DateSummary(
        dateId: json['dateId'] as int,
        matchId: json['matchId'] as int,
        partnerId: json['partnerId'] as String,
        partnerName: json['partnerName'] as String,
        partnerThumbnailUrl: json['partnerThumbnailUrl'] as String?,
        state: enumFromWire(DateState.values, json['state'] as String),
        createdAt: _instant(json['createdAt'])!,
        scheduledStart: _instant(json['scheduledStart']),
        venueName: json['venueName'] as String?,
        activityName: json['activityName'] as String,
      );
}

/// Timeline step DTO for stepper UI
class TimelineStepDto {
  final TimelineStep step;
  final StepStatus status;
  final String label;
  final DateTime? completedAt;
  final ParticipantDepositStatus? you;
  final ParticipantDepositStatus? partner;

  const TimelineStepDto({
    required this.step,
    required this.status,
    required this.label,
    this.completedAt,
    this.you,
    this.partner,
  });

  factory TimelineStepDto.fromJson(Map<String, dynamic> json) =>
      TimelineStepDto(
        step: enumFromWire(TimelineStep.values, json['step'] as String),
        status: enumFromWire(StepStatus.values, json['status'] as String),
        label: json['label'] as String,
        completedAt: _instant(json['completedAt']),
        you: json['you'] == null
            ? null
            : enumFromWire(
                ParticipantDepositStatus.values, json['you'] as String),
        partner: json['partner'] == null
            ? null
            : enumFromWire(
                ParticipantDepositStatus.values, json['partner'] as String),
      );
}

/// Deposit status for both participants
class DepositStatus {
  final ParticipantDepositStatus user1;
  final ParticipantDepositStatus user2;

  const DepositStatus({required this.user1, required this.user2});

  factory DepositStatus.fromJson(Map<String, dynamic> json) => DepositStatus(
        user1: enumFromWire(
            ParticipantDepositStatus.values, json['user1'] as String),
        user2: enumFromWire(
            ParticipantDepositStatus.values, json['user2'] as String),
      );
}

/// Full date detail model
class DateDetail {
  final int dateId;
  final int matchId;
  final String user1Id;
  final String user2Id;
  final int activityId;
  final String activityName;
  final String tokenCost; // Decimal string, e.g. "5.00"
  final int cityId;
  final String cityName;
  final DateState state;
  final int availabilityRound;
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final DateTime? depositDeadline;
  final DateTime? rankingDeadline;
  final int? venueId;
  final String? venueName;
  final String? venueAddress;
  final DateTime? venueBookedAt;
  final String? bookingReference;
  final DepositStatus depositStatus;
  final bool cancellable;
  final List<TimelineStepDto> timeline; // Always 6, fixed order
  final DateTime createdAt;
  final DateTime updatedAt;

  const DateDetail({
    required this.dateId,
    required this.matchId,
    required this.user1Id,
    required this.user2Id,
    required this.activityId,
    required this.activityName,
    required this.tokenCost,
    required this.cityId,
    required this.cityName,
    required this.state,
    required this.availabilityRound,
    this.scheduledStart,
    this.scheduledEnd,
    this.depositDeadline,
    this.rankingDeadline,
    this.venueId,
    this.venueName,
    this.venueAddress,
    this.venueBookedAt,
    this.bookingReference,
    required this.depositStatus,
    required this.cancellable,
    required this.timeline,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DateDetail.fromJson(Map<String, dynamic> json) => DateDetail(
        dateId: json['dateId'] as int,
        matchId: json['matchId'] as int,
        user1Id: json['user1Id'] as String,
        user2Id: json['user2Id'] as String,
        activityId: json['activityId'] as int,
        activityName: json['activityName'] as String,
        tokenCost: json['tokenCost'] as String,
        cityId: json['cityId'] as int,
        cityName: json['cityName'] as String,
        state: enumFromWire(DateState.values, json['state'] as String),
        availabilityRound: json['availabilityRound'] as int,
        scheduledStart: _instant(json['scheduledStart']),
        scheduledEnd: _instant(json['scheduledEnd']),
        depositDeadline: _instant(json['depositDeadline']),
        rankingDeadline: _instant(json['rankingDeadline']),
        venueId: json['venueId'] as int?,
        venueName: json['venueName'] as String?,
        venueAddress: json['venueAddress'] as String?,
        venueBookedAt: _instant(json['venueBookedAt']),
        bookingReference: json['bookingReference'] as String?,
        depositStatus:
            DepositStatus.fromJson(json['depositStatus'] as Map<String, dynamic>),
        cancellable: json['cancellable'] as bool,
        timeline: (json['timeline'] as List)
            .map((e) => TimelineStepDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: _instant(json['createdAt'])!,
        updatedAt: _instant(json['updatedAt'])!,
      );

  // Helpers every screen needs
  String partnerId(String myUid) => user1Id == myUid ? user2Id : user1Id;

  ParticipantDepositStatus myDeposit(String myUid) =>
      user1Id == myUid ? depositStatus.user1 : depositStatus.user2;

  ParticipantDepositStatus partnerDeposit(String myUid) =>
      user1Id == myUid ? depositStatus.user2 : depositStatus.user1;
}

/// Availability slot DTO
class SlotDto {
  final DateTime slotStart;
  final SlotAvailability availability; // Only available/unavailable come back

  const SlotDto({required this.slotStart, required this.availability});

  factory SlotDto.fromJson(Map<String, dynamic> json) => SlotDto(
        slotStart: _instant(json['slotStart'])!,
        availability: enumFromWire(
            SlotAvailability.values, json['availability'] as String),
      );
}

/// Availability view response
class AvailabilityView {
  final int dateId;
  final int currentRound;
  final List<SlotDto> mySlots;
  final List<SlotDto> partnerSlots;

  const AvailabilityView({
    required this.dateId,
    required this.currentRound,
    required this.mySlots,
    required this.partnerSlots,
  });

  factory AvailabilityView.fromJson(Map<String, dynamic> json) =>
      AvailabilityView(
        dateId: json['dateId'] as int,
        currentRound: json['currentRound'] as int,
        mySlots: (json['mySlots'] as List)
            .map((e) => SlotDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        partnerSlots: (json['partnerSlots'] as List)
            .map((e) => SlotDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Deposit payment response
class DepositPaymentResponse {
  final String newBalance; // Decimal string
  final bool bothPaid;
  final bool transitionedToRanking;

  const DepositPaymentResponse({
    required this.newBalance,
    required this.bothPaid,
    required this.transitionedToRanking,
  });

  factory DepositPaymentResponse.fromJson(Map<String, dynamic> json) =>
      DepositPaymentResponse(
        newBalance: json['newBalance'] as String,
        bothPaid: json['bothPaid'] as bool,
        transitionedToRanking: json['transitionedToRanking'] as bool,
      );
}

/// Venue option
class VenueOption {
  final int venueId;
  final int optionOrder;
  final String name;
  final String address;
  final String? thumbnailUrl; // Always null today

  const VenueOption({
    required this.venueId,
    required this.name,
    required this.address,
    this.thumbnailUrl,
    required this.optionOrder,
  });

  factory VenueOption.fromJson(Map<String, dynamic> json) => VenueOption(
        venueId: json['venueId'] as int,
        name: json['name'] as String,
        address: json['address'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String?,
        optionOrder: json['optionOrder'] as int,
      );
}

/// Venue ranking
class VenueRanking {
  final int venueId;
  final int rank;

  const VenueRanking({required this.venueId, required this.rank});

  factory VenueRanking.fromJson(Map<String, dynamic> json) => VenueRanking(
        venueId: json['venueId'] as int,
        rank: json['rank'] as int,
      );
}

/// Venue options response
class VenueOptions {
  final int dateId;
  final List<VenueOption> options; // 1..3, sorted by optionOrder
  final List<VenueRanking> myRankings; // Empty until caller submits

  const VenueOptions({
    required this.dateId,
    required this.options,
    required this.myRankings,
  });

  factory VenueOptions.fromJson(Map<String, dynamic> json) {
    final optionsList = (json['options'] as List)
        .map((e) => VenueOption.fromJson(e as Map<String, dynamic>))
        .toList();
    optionsList.sort((a, b) => a.optionOrder.compareTo(b.optionOrder));

    return VenueOptions(
      dateId: json['dateId'] as int,
      options: optionsList,
      myRankings: (json['myRankings'] as List)
          .map((e) => VenueRanking.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Ranking submission response
class RankingSubmissionResponse {
  final bool bothSubmitted;
  final bool venueAssigned;
  final int? assignedVenueId;

  const RankingSubmissionResponse({
    required this.bothSubmitted,
    required this.venueAssigned,
    this.assignedVenueId,
  });

  factory RankingSubmissionResponse.fromJson(Map<String, dynamic> json) =>
      RankingSubmissionResponse(
        bothSubmitted: json['bothSubmitted'] as bool,
        venueAssigned: json['venueAssigned'] as bool,
        assignedVenueId: json['assignedVenueId'] as int?,
      );
}

/// Participant presence status
class ParticipantPresence {
  final String userId;
  final bool confirmed;
  final DateTime? confirmedAt;

  const ParticipantPresence({
    required this.userId,
    required this.confirmed,
    this.confirmedAt,
  });

  factory ParticipantPresence.fromJson(Map<String, dynamic> json) =>
      ParticipantPresence(
        userId: json['userId'] as String,
        confirmed: json['confirmed'] as bool,
        confirmedAt: _instant(json['confirmedAt']),
      );
}

/// Presence confirmation status
class PresenceConfirmationStatus {
  final int dateId;
  final ParticipantPresence user1;
  final ParticipantPresence user2;

  const PresenceConfirmationStatus({
    required this.dateId,
    required this.user1,
    required this.user2,
  });

  factory PresenceConfirmationStatus.fromJson(Map<String, dynamic> json) =>
      PresenceConfirmationStatus(
        dateId: json['dateId'] as int,
        user1: ParticipantPresence.fromJson(
            json['user1'] as Map<String, dynamic>),
        user2: ParticipantPresence.fromJson(
            json['user2'] as Map<String, dynamic>),
      );

  ParticipantPresence me(String myUid) =>
      user1.userId == myUid ? user1 : user2;

  ParticipantPresence partner(String myUid) =>
      user1.userId == myUid ? user2 : user1;
}

/// Refund details
class Refund {
  final String userId;
  final String amount; // Decimal string
  final int? transactionId;

  const Refund({
    required this.userId,
    required this.amount,
    this.transactionId,
  });

  factory Refund.fromJson(Map<String, dynamic> json) => Refund(
        userId: json['userId'] as String,
        amount: json['amount'] as String,
        transactionId: json['transactionId'] as int?,
      );
}

/// Cancellation result
class CancellationResult {
  final int dateId;
  final CancellationTier tier;
  final Map<String, Refund> refunds; // Keyed by userId
  final CancellationSource cancellationSource;
  final DateTime cancelledAt;

  const CancellationResult({
    required this.dateId,
    required this.tier,
    required this.refunds,
    required this.cancellationSource,
    required this.cancelledAt,
  });

  factory CancellationResult.fromJson(Map<String, dynamic> json) =>
      CancellationResult(
        dateId: json['dateId'] as int,
        tier:
            enumFromWire(CancellationTier.values, json['tier'] as String),
        refunds: (json['refunds'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, Refund.fromJson(v as Map<String, dynamic>)),
        ),
        cancellationSource: enumFromWire(
            CancellationSource.values, json['cancellationSource'] as String),
        cancelledAt: _instant(json['cancelledAt'])!,
      );

  Refund? mine(String myUid) => refunds[myUid];
}

/// Mutual match response (from PATCH /match/action/{matchId} on 200)
class MutualMatchResponse {
  final int matchId;
  final int dateId;
  final String user1Id;
  final String user2Id;
  final DateTime matchedAt;

  const MutualMatchResponse({
    required this.matchId,
    required this.dateId,
    required this.user1Id,
    required this.user2Id,
    required this.matchedAt,
  });

  factory MutualMatchResponse.fromJson(Map<String, dynamic> json) {
    final matchInfo = json['mutualMatchInfo'] as Map<String, dynamic>;
    return MutualMatchResponse(
      matchId: matchInfo['matchId'] as int,
      user1Id: matchInfo['user1Id'] as String,
      user2Id: matchInfo['user2Id'] as String,
      matchedAt: _instant(matchInfo['matchedAt'])!,
      dateId: json['dateId'] as int,
    );
  }
}

// ====================
// CONSTANTS
// ====================

/// Backend constants hardcoded for client-side validation
class DatesConstants {
  DatesConstants._();

  static const int slotGridMinutes = 30;
  static const int dateDurationMinutes = 120;
  static const int minLeadHours = 48;
  static const int horizonDays = 21;
  static const int minAvailableSlots = 3;
  static const int maxMarkedSlots = 200;
  static const int maxAvailabilityRounds = 2;
  static const int depositWindowHours = 48;
  static const int rankingWindowHours = 48;
  static const int presenceWindowHours = 24;
  static const int maxVenueOptions = 3;
}

// ====================
// SLOT GRID HELPER
// ====================

/// Round a local DateTime down to the nearest 30-minute UTC grid point
DateTime snapToGrid(DateTime t) {
  final u = t.toUtc();
  return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute - (u.minute % 30));
}
