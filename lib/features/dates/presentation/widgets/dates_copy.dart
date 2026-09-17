import 'package:eros_app/features/dates/data/models/date_models.dart';

/// Centralized copy for all date-related UI strings
///
/// Per §2 of dates-ui-tickets.md:
/// - Brand voice: warm, direct, unhurried
/// - Short sentences
/// - NO exclamation marks except on completed/ready screens
/// - NO em dashes anywhere in UI copy
/// - Partner referred to by {partnerName}, never "your match" or "them"
class DatesCopy {
  DatesCopy._();

  // ====================
  // EMPTY STATE (UI-2)
  // ====================

  static const String emptyStateHeading = 'What happens after you match?';

  static const List<String> emptyStateSteps = [
    'Pick the times you\'re both free',
    'You both commit with a small token deposit',
    'Rank three venues, we book the spot',
    'Confirm you\'re coming the day before',
    'Meet up and enjoy your date',
  ];

  static const String emptyStateButtonText = 'How Muse works';

  // ====================
  // STATUS PILLS (UI-3, UI-4)
  // ====================

  /// Get pill text for a given DateState
  /// Returns tuple: (pillText, tone)
  /// Tones: 'action', 'waiting', 'neutral', 'success', 'muted'
  static (String, String) statusPill({
    required DateState state,
    required String partnerName,
    required String tokenCost,
    required bool youSubmitted,
    required bool youPaid,
    required bool youRanked,
    required bool youConfirmed,
  }) {
    switch (state) {
      case DateState.awaitingAvailability:
        if (!youSubmitted) {
          return ('Pick your times', 'action');
        } else {
          return ('Waiting for $partnerName\'s times', 'waiting');
        }

      case DateState.awaitingDeposit:
        if (!youPaid) {
          return ('Commit with $tokenCost', 'action');
        } else {
          return ('Waiting for $partnerName to commit', 'waiting');
        }

      case DateState.awaitingVenueRanking:
        if (!youRanked) {
          return ('Rank your venues', 'action');
        } else {
          return ('Waiting for $partnerName\'s picks', 'waiting');
        }

      case DateState.venueAssigned:
      case DateState.venueConfirmationPending:
        return ('Booking your spot', 'waiting');

      case DateState.booked:
        return ('Booked. Confirm 24h before', 'neutral');

      case DateState.awaitingPresenceConfirmation:
        if (!youConfirmed) {
          return ('Confirm you\'re coming', 'action');
        } else {
          return ('Waiting for final confirmation', 'waiting');
        }

      case DateState.ready:
        return ('You\'re both confirmed', 'success');

      case DateState.completed:
        return ('Completed', 'neutral');

      case DateState.cancelled:
        return ('Cancelled', 'muted');

      case DateState.expired:
        return ('Expired', 'muted');
    }
  }

  // ====================
  // STATUS PILL EXPLANATIONS (UI-4)
  // ====================

  static String statusPillExplanation(DateState state) {
    switch (state) {
      case DateState.awaitingAvailability:
        return 'Both of you pick times you\'re free over the next three weeks. We find the earliest one that works for you both. If nothing overlaps you each get one more go.';

      case DateState.awaitingDeposit:
        return 'A small token deposit from each of you keeps the date real. If either of you cancels after both have paid, the person cancelling loses their deposit and the other gets theirs back. Miss the deadline and everything is refunded.';

      case DateState.awaitingVenueRanking:
        return 'We\'ve shortlisted venues near you both. Rank them and we\'ll book whichever you agree on most.';

      case DateState.venueAssigned:
      case DateState.venueConfirmationPending:
        return 'Our team is confirming your table. Nothing to do yet.';

      case DateState.booked:
        return 'You\'re booked. The day before, we\'ll ask you both to confirm you\'re still coming.';

      case DateState.awaitingPresenceConfirmation:
        return 'Final check. Once you\'ve both confirmed, you\'re all set.';

      case DateState.ready:
        return 'All set. Enjoy it.';

      case DateState.completed:
      case DateState.cancelled:
      case DateState.expired:
        return '';
    }
  }

  // ====================
  // CTA PANEL (UI-4)
  // ====================

  static String ctaButtonText(DateState state, {required bool youPaid}) {
    switch (state) {
      case DateState.awaitingAvailability:
        return 'Pick your times';
      case DateState.awaitingDeposit:
        return youPaid ? '' : 'Commit'; // tokenCost appended in widget
      case DateState.awaitingVenueRanking:
        return 'Rank venues';
      case DateState.awaitingPresenceConfirmation:
        return 'I\'m coming';
      default:
        return '';
    }
  }

  static String ctaCaption({
    required DateState state,
    required String partnerName,
    required int availabilityRound,
    required bool youPaid,
    required bool youRanked,
    required bool youConfirmed,
  }) {
    switch (state) {
      case DateState.awaitingAvailability:
        if (availabilityRound == 2) {
          return 'No overlap last time. Round 2 of 2.';
        }
        return '';

      case DateState.awaitingDeposit:
        if (youPaid) {
          return 'You\'ve committed. Waiting for $partnerName.';
        }
        return ''; // Deadline countdown shown in widget

      case DateState.awaitingVenueRanking:
        if (youRanked) {
          return 'Waiting for $partnerName\'s picks';
        }
        return ''; // Deadline countdown shown in widget

      case DateState.awaitingPresenceConfirmation:
        if (youConfirmed) {
          return 'Waiting for $partnerName to confirm';
        }
        return 'Confirm you\'ll be there';

      case DateState.ready:
        return 'You\'re both confirmed. See you there.';

      default:
        return '';
    }
  }

  // ====================
  // AVAILABILITY PICKER (UI-5)
  // ====================

  static const String availabilityTitle = 'When are you free?';

  static String availabilitySubtitle(int round) =>
      'Round $round of 2. Pick at least 3 times.';

  static const String availabilityDiscardConfirm = 'Discard changes?';

  static String availabilityCounter(int count, int required) =>
      '$count of $required free times picked';

  static String availabilityMarkedCount(int marked) =>
      '$marked marked (max 200)';

  static const String availabilitySendButton = 'Send my times';

  static String availabilityPartnerLegend(String partnerName) =>
      '$partnerName has already picked. Their free times are marked.';

  static String availabilityPartnerBusyHint(String partnerName) =>
      '$partnerName is busy then';

  static const String availabilityNoOverlapTitle = 'No overlap yet. Round 2 of 2.';

  static const String availabilityNoOverlapBody =
      'Neither of you picked the same time. Have one more go, and try marking more slots as free.';

  static String availabilityTimeFoundHeading(String timeRange) =>
      'You\'ve found a time: $timeRange';

  // ====================
  // DEPOSIT SHEET (UI-6)
  // ====================

  static const String depositHeading = 'Commit to your date';

  static const String depositRefundCaption =
      'Refunded in full if the date falls through before you both commit.';

  static String depositBalanceLabel(String balance) => 'Your balance: $balance';

  static const String depositTopUpButton = 'Top up tokens';

  static String depositPartnerStatus(String partnerName, bool paid) =>
      '$partnerName: ${paid ? 'committed' : 'not yet'}';

  static const String depositDeadlineCaption =
      'If either of you hasn\'t committed by then, the date expires and any deposit is refunded.';

  static const String depositSuccessBothPaid = 'You\'re both in';

  static String depositSuccessWaiting(String partnerName) =>
      'Committed. Waiting for $partnerName.';

  // ====================
  // VENUE RANKING (UI-7)
  // ====================

  static const String venueRankingTitle = 'Rank your venues';

  static const String venueRankingSubtitle =
      'Drag to order. We\'ll book the one you both like most.';

  static const String venueRankingSingleCaption =
      'Only one venue is available right now. Confirm to continue.';

  static const String venueRankingConfirmSingle = 'Confirm venue';

  static String venueRankingReadOnly(String partnerName) =>
      'Your ranking is in. Waiting for $partnerName.';

  static const String venueRankingSendButton = 'Send my ranking';

  static String venueAssignedHeading(String venueName) => 'It\'s $venueName';

  static const String venueAssignedButton = 'Back to your date';

  static String venueRankingSent(String partnerName) =>
      'Ranking sent. Waiting for $partnerName.';

  static const String venueStillSorting =
      'We\'re still sorting venues for this date. Try again shortly.';

  // ====================
  // BOOKING CARD (UI-8)
  // ====================

  static const String bookingDirections = 'Directions';

  static const String bookingAddToCalendar = 'Add to calendar';

  static const String bookingRefLabel = 'Booking ref';

  static const String bookingConfirmingCaption =
      'We\'re confirming your table. You\'ll see the booking here once it\'s done.';

  static String bookingCalendarTitle(String partnerName, String venueName) =>
      'Date with $partnerName at $venueName';

  static String bookingConfirmedCaption(String venueName, String timeRange) =>
      'You\'re both confirmed. $venueName at $timeRange.';

  // ====================
  // PRESENCE CONFIRMATION (UI-8)
  // ====================

  static const String presenceYouLabel = 'You';

  static String presencePartnerLabel(String partnerName) => partnerName;

  static const String presenceNotYet = 'not yet';

  static const String presenceConfirmedStatus = 'confirmed';

  static const String presenceButtonText = 'I\'m coming';

  static String presenceConfirmedWaiting(String partnerName) =>
      'Confirmed. Waiting for $partnerName.';

  static const String presenceBothConfirmed = 'You\'re both confirmed';

  // ====================
  // CANCEL FLOW (UI-9)
  // ====================

  static const String cancelPreCommitmentTitle = 'Cancel this date?';

  static String cancelPreCommitmentBody(String partnerName) =>
      'Anything you\'ve paid comes straight back to you. $partnerName will be told the date is off.';

  static const String cancelPostCommitmentTitle =
      'Cancel and lose your deposit?';

  static String cancelPostCommitmentBody(String partnerName, String tokenCost) =>
      'You\'ve both committed, so cancelling now means your $tokenCost deposit goes to $partnerName and yours is not refunded.';

  static const String cancelLateExtra = 'This is a late cancellation.';

  static const String cancelReasonPlaceholder = 'Add a note (optional)';

  static const String cancelKeepButton = 'Keep the date';

  static const String cancelConfirmButton = 'Cancel date';

  static String cancelRefund(String amount) => '$amount tokens refunded to your wallet.';

  static const String cancelSomethingChanged = 'Something changed. Updated.';

  // ====================
  // TERMINAL PANELS (UI-10)
  // ====================

  static const String completedHeading = 'You met!';

  static const String completedBody = 'Hope it went well.';

  static const String cancelledHeading = 'This date was cancelled';

  static const String cancelledBody =
      'If you had a deposit in play, check your wallet for any refund.';

  static const String expiredHeading = 'This date ran out of time';

  static const String expiredBody =
      'It can happen when times don\'t overlap, a deadline passes, or no venue was free. Any deposit has been refunded.';

  static const String terminalBackButton = 'Back to dates';

  // ====================
  // MATCH HANDOFF (UI-11)
  // ====================

  static String matchHandoffBanner(String partnerName) =>
      'Your date with $partnerName is ready to plan';

  static const String matchHandoffButton = 'Plan the date';

  static String matchHandoffTopBanner(String partnerName) =>
      'You matched with $partnerName. First, pick your times.';

  // ====================
  // HISTORY (UI-3)
  // ====================

  static const String historyTitle = 'History';

  static const String historyTabPast = 'Past';

  static const String historyTabCancelled = 'Cancelled';

  static const String historyEmptyPast = 'No past dates yet';

  static const String historyEmptyCancelled = 'Nothing here. That\'s a good sign.';

  // ====================
  // GENERAL
  // ====================

  static const String howMuseWorksButton = 'How Muse works';

  static const String reportProblem = 'Report a problem';

  static const String cancelDate = 'Cancel date';

  static const String errorRetry = 'Something went wrong. Try again.';

  static const String errorConnection = 'Connection error. Check your internet.';

  static const String errorDateNotAvailable = 'That date isn\'t available.';
}
