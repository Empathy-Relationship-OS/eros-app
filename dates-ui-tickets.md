# Dates module: UI tickets for the Flutter app

**Audience:** a Claude Code subagent implementing the user-facing dates experience in the Muse Flutter app.
**Read first:** `dates-frontend-integration.md` (wire contract, models, FE-1 to FE-10). This file does not repeat that contract. Where a ticket below says "per FE-n", the data plumbing lives in that FE task; the ticket here is the screen, component and copy work that sits on top of it.
**Design reference:** two Breeze screenshots in `screenshots/dates/`. They set the *feel* (single hero card, warm neutral background, quiet vertical stepper, one status pill, one primary action). They do **not** set the order of steps or the copy. See §1.

Work through the tickets in order. Each is one PR. Every PR that adds a screen also adds a `flutter test` widget test for its states and a golden or screenshot for the happy path.

---

## 1. Muse vs Breeze: the order is different

Breeze's onboarding stepper (screenshot 1) reads: pay, pick a day and time, we arrange the spot, confirm presence, meet. Muse's lifecycle, as fixed by `DateDetailDTO.timeline`, is:

| # | `TimelineStep` | What the user sees it as | User acts? |
|---|---|---|---|
| 1 | `DATE_TYPE` | The kind of date (`activityName`, e.g. "Drinks"). Set when the match is made. | No |
| 2 | `AVAILABILITY` | Pick times you're free (up to 2 rounds) | Yes |
| 3 | `DEPOSIT` | Both commit with a token deposit | Yes |
| 4 | `VENUE` | Rank three venues, Muse books the spot | Yes (rank), then ops |
| 5 | `CONFIRMATION` | Confirm you're coming, 24h before | Yes |
| 6 | `DATE` | Meet | No |

Key difference to keep straight in copy and layout: in Muse you agree a **time before you pay**, and you **rank venues** rather than having one picked for you. Every piece of copy in this file already reflects that. Do not reuse Breeze's wording.

Render the stepper strictly from the `timeline` list (six items, fixed order, statuses `COMPLETE | CURRENT | PENDING | SKIPPED`). Never derive step state from `DateState` (§5 of the integration doc).

## 2. Copy conventions

- Brand voice: warm, direct, unhurried. Short sentences. No exclamation marks except on the completed/ready screens.
- **No em dashes anywhere in UI copy.** Use a comma, a full stop, or a hyphen with spaces where a range is needed ("Tue 31 Mar, 19:00 - 21:00").
- Times are shown in the device's local timezone, always with the weekday: `EEE d MMM, HH:mm`. Durations are two hours, so where space allows show the range.
- Tokens: `tokenCost` is a decimal string. Format with the existing wallet formatter if one exists; otherwise strip a trailing `.00` and append the word "token"/"tokens" ("5 tokens").
- Partner is always referred to by `partnerName`, never "your match" or "them" when the name is available.

Status pill copy, keyed on `DateState` (used by UI-3 and UI-4):

| `DateState` | Pill text | Pill tone |
|---|---|---|
| `AWAITING_AVAILABILITY` (you not yet submitted) | Pick your times | action |
| `AWAITING_AVAILABILITY` (you submitted, partner not) | Waiting for {partnerName}'s times | waiting |
| `AWAITING_DEPOSIT` (you unpaid) | Commit with {tokenCost} | action |
| `AWAITING_DEPOSIT` (you paid, partner not) | Waiting for {partnerName} to commit | waiting |
| `AWAITING_VENUE_RANKING` (not ranked) | Rank your venues | action |
| `AWAITING_VENUE_RANKING` (ranked) | Waiting for {partnerName}'s picks | waiting |
| `VENUE_ASSIGNED`, `VENUE_CONFIRMATION_PENDING` | Booking your spot | waiting |
| `BOOKED` | Booked. Confirm 24h before | neutral |
| `AWAITING_PRESENCE_CONFIRMATION` (you unconfirmed) | Confirm you're coming | action |
| `AWAITING_PRESENCE_CONFIRMATION` (you confirmed) | Waiting for final confirmation | waiting |
| `READY` | You're both confirmed | success |
| `COMPLETED` | Completed | neutral |
| `CANCELLED` | Cancelled | muted |
| `EXPIRED` | Expired | muted |

"You submitted" for availability is inferred from `GET /dates/{id}/availability` returning a non-empty `mySlots` (only fetch this when state is `AWAITING_AVAILABILITY`). Deposit uses `DateDetail.myDeposit(uid)`. Ranking uses `myRankings.isNotEmpty`. Presence uses the last `PresenceConfirmationStatus` response, or fall back to the "unconfirmed" pill if none has been fetched.

---

## UI-0 Discovery (no product change)

Before writing any widget, read the app and write a 20-line `lib/features/dates/README.md` recording:

1. State management in use (Riverpod, Bloc, Provider, plain `ChangeNotifier`) and how an async list/detail is normally modelled. Reuse it; do not introduce a second pattern.
2. Router (`go_router`, `auto_route`, `Navigator 2`) and how a tab route and a pushed detail route are declared. Note how "route regained focus" is detected elsewhere in the app, if at all.
3. HTTP client and where the Firebase ID token is attached. `DatesApi` (FE-1) must slot into that, not around it.
4. How the current user's UID is exposed to widgets (needed by every `DateDetail` helper).
5. Theme: the colour tokens, text styles, radius and spacing scale, and whether a `Pill`/`Chip`, `PrimaryButton`, `Avatar`, `BottomSheet` helper and an `EmptyState` widget already exist. List what exists so later tickets reuse them.
6. Wallet: where balance is read, and the route name of the top-up flow (UI-6 deep-links to it).
7. The matches/likes screen and where the `PATCH /match/action` call is made today (UI-11 hooks in there).

Acceptance: README exists, and every later ticket's "reuse existing X" line has been resolved to a concrete class name or "none, create it".

---

## UI-1 Shared dates widgets and formatting

Create `lib/features/dates/presentation/widgets/` with the small pieces every later screen needs. No screens in this ticket.

- `DateStepper`: vertical, six rows, built from `List<TimelineStepDto>`. Left rail of circular icon chips connected by a thin line (screenshot 1 shows the shape). Icon per `TimelineStep`: date type = glass, availability = calendar, deposit = card/coin, venue = map pin, confirmation = tick, date = heart or clink. Status styling: `COMPLETE` filled brand colour with tick overlay, `CURRENT` outlined brand colour with a subtle pulse or bolder label, `PENDING` muted, `SKIPPED` muted and struck through label. Row text is `label` from the DTO. Optional trailing detail slot per row (used by UI-4 for "you paid, waiting on {partnerName}"). Compact variant (icons only, horizontal) for the list card.
- `DateStatusPill`: takes the pill text and tone from the table in §2. Full-width rounded outline like screenshot 2's "Waiting for final confirmation", with a trailing info icon that opens a one-paragraph explanation sheet (copy per state, provided in UI-4).
- `DeadlineCountdown`: takes a `DateTime?` deadline. Shows "2d 3h left", "5h 12m left", "Under an hour" and, once passed, "Expired, refreshing" while triggering the parent's refetch callback. Ticks once a minute, not every second.
- `PartnerHeader`: partner photo as a hero (square with large radius, like screenshot 2), name, and a slot for badges. Falls back to an initial-letter avatar when `partnerThumbnailUrl` is null.
- `DateFacts`: the icon + text rows from screenshot 2: calendar row (time range), pin row (venue name, address on second line), glass row (`activityName`). Each row accepts null and hides itself. Time and venue rows are tappable when a handler is passed (UI-8 uses this for maps).
- `TokenAmount`: formats a decimal string per §2.
- `DateFormats`: the `EEE d MMM, HH:mm` formatter and a range formatter, local timezone, wrapping whichever intl setup the app uses.
- `DatesCopy`: a single Dart class holding every user-visible string in this file, keyed by state where relevant. No string literals in widgets.

Acceptance: widgetbook/story or a `dev_dates_gallery` debug route rendering the stepper in the four status combinations, the pill in all four tones, the countdown at three distances, and `PartnerHeader` with and without a photo. Unit test that `DateFormats` output for `2026-09-20T19:00:00Z` in `Europe/London` is "Sun 20 Sep, 20:00" and the range adds " - 22:00".

---

## UI-2 Dates tab: empty state ("What happens after you match?")

The Dates tab (heart icon in the bottom bar, matching the app's existing tab if one exists) with no active date shows a single card in the style of screenshot 1: illustration area on top, then heading, then a five-row explainer stepper, then a primary button.

Copy:

- Heading: **What happens after you match?**
- Rows (use `DateStepper` in explainer mode with all rows neutral, no statuses):
  1. Pick the times you're both free
  2. You both commit with a small token deposit
  3. Rank three venues, we book the spot
  4. Confirm you're coming the day before
  5. Meet up and enjoy your date
- Button: **How Muse works** with trailing arrow. Opens an existing "how it works" screen if there is one; otherwise a simple scrollable sheet with one paragraph per row above, plus a paragraph on cancellations (refund rules from §4.8 of the integration doc, phrased for users).

The `DATE_TYPE` step is deliberately omitted from the explainer: it is not something the user does. It reappears in the live stepper (UI-4) because the timeline DTO includes it.

Illustration: use the app's existing brand illustration assets if any; otherwise a flat brand-colour panel. Do not copy Breeze's artwork.

Acceptance: renders when `GET /dates?filter=active` returns `[]`; hidden when it does not. Loading skeleton while the first fetch is in flight. Error state with a retry button.

---

## UI-3 Dates tab: active date card(s) and history

When there is at least one active date, the tab shows one card per active date, sorted by `scheduledStart ?? createdAt` ascending, in the style of screenshot 2.

Card layout (top to bottom): `PartnerHeader` hero with a chat bubble in the top-right corner if the app has messaging (otherwise omit), `partnerName` with any verification badges the app already has, `DateFacts` (time range if `scheduledStart`, venue if `venueName`, always `activityName`), then `DateStatusPill`. Whole card taps through to the detail screen (UI-4). No edit pencil; editing happens on the detail screen.

Because `DateSummary` lacks deposit status, per-round info and `myRankings`, the pill on the list card uses the **state-only** fallback text (the "action" row for each acting state). The detail screen refines it. If the list is short (typically one or two cards) it is acceptable to fetch `GET /dates/{id}` per card to show the refined pill; guard with a max of 3 detail fetches.

App bar: wordmark left; right side has a **history** icon (clock arrow, as in screenshot 2) that pushes a `DateHistoryScreen` with two segments, **Past** (`?filter=past`) and **Cancelled** (`?filter=cancelled`). This replaces the three-tab layout suggested in FE-3; active dates are the whole tab, history is one tap away. History rows are compact: small avatar, name, `activityName`, `scheduledStart` if set, state pill (Completed / Cancelled / Expired). Each has its own empty state: "No past dates yet" and "Nothing here. That's a good sign."

Below the card(s) a text link **How Muse works** with arrow, as in screenshot 2.

Pull to refresh on both the tab and history.

Acceptance: fixture with two active dates renders two cards in the right order; history segments show the right subsets; card tap opens detail with the correct `dateId`; pull to refresh refetches.

---

## UI-4 Date detail screen: stepper and CTA panel

Route: `/dates/:dateId`. Backed by FE-4's fetch-on-focus and fetch-after-action behaviour.

Layout:

1. `PartnerHeader` (photo, name) with a back button overlaid. Overflow menu (three dots) holding **Cancel date** when `cancellable && (scheduledEnd == null || scheduledEnd.isAfter(now))`, and **Report a problem** if the app has a support route.
2. `DateFacts` as on the card.
3. `DateStatusPill` with the refined text from §2. Info icon opens the explanation sheet. Explanation copy per state:
   - `AWAITING_AVAILABILITY`: "Both of you pick times you're free over the next three weeks. We find the earliest one that works for you both. If nothing overlaps you each get one more go."
   - `AWAITING_DEPOSIT`: "A small token deposit from each of you keeps the date real. If either of you cancels after both have paid, the person cancelling loses their deposit and the other gets theirs back. Miss the deadline and everything is refunded."
   - `AWAITING_VENUE_RANKING`: "We've shortlisted venues near you both. Rank them and we'll book whichever you agree on most."
   - `VENUE_ASSIGNED` / `VENUE_CONFIRMATION_PENDING`: "Our team is confirming your table. Nothing to do yet."
   - `BOOKED`: "You're booked. The day before, we'll ask you both to confirm you're still coming."
   - `AWAITING_PRESENCE_CONFIRMATION`: "Final check. Once you've both confirmed, you're all set."
   - `READY`: "All set. Enjoy it."
4. `DateStepper` (full variant) from `timeline`. On the `DEPOSIT` row, when `you`/`partner` are non-null, show a trailing detail: "You: paid" / "{partnerName}: pending" using `ParticipantDepositStatus`.
5. CTA panel, switched on `DateState`, pinned to the bottom of the scroll view as a primary button (dark full-width pill like screenshot 1's button) plus optional caption:

| `DateState` | Primary button | Caption above button | Opens |
|---|---|---|---|
| `AWAITING_AVAILABILITY` | Pick your times | "Round {availabilityRound} of 2" (only show when round is 2: "No overlap last time. Round 2 of 2.") | UI-5 |
| `AWAITING_DEPOSIT`, unpaid | Commit {tokenCost} | `DeadlineCountdown(depositDeadline)` | UI-6 |
| `AWAITING_DEPOSIT`, paid | none | "You've committed. Waiting for {partnerName}." + countdown | |
| `AWAITING_VENUE_RANKING`, not ranked | Rank venues | `DeadlineCountdown(rankingDeadline)` | UI-7 |
| `AWAITING_VENUE_RANKING`, ranked | View your ranking | "Waiting for {partnerName}'s picks" | UI-7 read-only |
| `VENUE_ASSIGNED`, `VENUE_CONFIRMATION_PENDING`, `BOOKED` | none | booking card (UI-8) | |
| `AWAITING_PRESENCE_CONFIRMATION`, unconfirmed | I'm coming | "Confirm you'll be there" | UI-8 confirm |
| `AWAITING_PRESENCE_CONFIRMATION`, confirmed | none | "Waiting for {partnerName} to confirm" | |
| `READY` | none | "You're both confirmed. See you there." | |
| terminal | none | terminal panel (UI-10) | |

Refresh behaviour: refetch on focus and after every action (FE-4), plus while the pill tone is `waiting`, poll every 45 seconds while the screen is visible. Stop polling when the screen is not visible or the state becomes terminal. Show a thin linear progress bar at the very top during background refetches; never block the UI.

Acceptance: a fixture per `DateState` (11 states, plus the paid/ranked/confirmed variants) drives a widget test asserting button text (or absence) and pill text; exactly one `CURRENT` step for non-terminal fixtures; overflow menu shows Cancel only when allowed; a 409 from any action triggers a refetch and a short toast "Something changed. Updated." with no error dialog.

---

## UI-5 Availability picker

Full-screen route pushed from UI-4. Backed by FE-5.

Layout:

- App bar title **When are you free?**, subtitle "Round {n} of 2. Pick at least 3 times." Close (X) with "Discard changes?" if dirty.
- Horizontal day strip across the top covering `[now+48h, now+21d]` in local time (about 19 days). Each chip: weekday initial and day number; a small dot if the day has any marks. Days outside the window are not rendered.
- Below, a vertical list of 30-minute slots for the selected day, from 08:00 to 22:00 local by default with an "Earlier / Later" expander to reveal 00:00 to 08:00 and 22:00 to 23:30. Each slot is one row: time label ("19:00 - 21:00" since a date is two hours), tap target the full row.
- Tap cycle per row: unmarked → **Free** (brand fill, tick) → **Busy** (muted fill, cross) → unmarked. Long-press a row to apply the same mark to every remaining slot that day ("Free all afternoon" behaviour), with an undo snackbar.
- Partner overlay: when `partnerSlots` is non-empty, show a thin secondary indicator on the right edge of each row where the partner marked Free (small heart outline) or Busy (small dash), and a legend line under the app bar: "{partnerName} has already picked. Their free times are marked." Slots the partner marked Busy are still tappable but show a hint "{partnerName} is busy then" on tap.
- Footer, pinned: counter "{k} of 3 free times picked" turning positive at 3, a secondary line "{m} marked (max 200)" only once m > 150, and the primary button **Send my times**, disabled until k >= 3.

Data rules the UI must own (mirroring the backend): every slot is `snapToGrid`ed UTC; slots before now+48h or after now+21d are not shown at all; the payload contains `AVAILABLE`/`UNAVAILABLE` for current marks and `NO_PREFERENCE` only for slots that were in `mySlots` on load and have since been cleared.

After submit: refetch detail. Branch per FE-5: `AWAITING_DEPOSIT` → pop and immediately open UI-6 with a celebratory header "You've found a time" showing the chosen range; `availabilityRound` incremented → stay, clear the grid, show a dialog "No overlap yet. Round 2 of 2." with body "Neither of you picked the same time. Have one more go, and try marking more slots as free."; `EXPIRED` → pop to detail, which shows UI-10; still `AWAITING_AVAILABILITY` → pop to detail (pill reads waiting).

Acceptance: with 2 Free marks the button is disabled and the counter reads "2 of 3"; a test that every `slotStart` in an emitted payload has `minute % 30 == 0`, `second == 0`, `isUtc`; a slot at exactly now+47h59m is not rendered; a backend 400 `bad_request` shows its `message` verbatim in a snackbar; the day strip's first day is the local date of now+48h.

---

## UI-6 Deposit sheet

Modal bottom sheet from UI-4. Backed by FE-6.

Contents:

- Header: "Commit to your date" and the agreed time range in a highlighted row.
- Amount block: large `TokenAmount(tokenCost)` with caption "Refunded in full if the date falls through before you both commit."
- Balance row: "Your balance: {balance}". If balance < tokenCost, the row is red and the primary button becomes **Top up tokens** which deep-links to the wallet top-up route with a return path back to this date.
- Partner row: "{partnerName}: {paid ? 'committed' : 'not yet'}" using `partnerDeposit(uid)`.
- `DeadlineCountdown(depositDeadline)` with caption "If either of you hasn't committed by then, the date expires and any deposit is refunded."
- Primary button **Commit {tokenCost}**. Disabled with spinner while in flight. Second tap after a success is impossible (sheet closes on success).

Result handling:
- Success, `transitionedToRanking == true`: close sheet, show a full-screen brief success ("You're both in") for ~1.2s, then push UI-7.
- Success, `bothPaid == false`: close sheet, toast "Committed. Waiting for {partnerName}.", detail refetches.
- 409 `insufficient_balance`: switch the primary button to **Top up tokens** in place, keep sheet open.
- 409 `conflict`: close sheet, toast "Something changed. Updated.", detail refetches (covers already-paid and deadline passed).

Acceptance: both success branches and both 409 branches covered by widget tests with a mocked `DatesApi`; balance updates from `newBalance` are pushed into whatever wallet state the app has, not just the local sheet.

---

## UI-7 Venue ranking

Full-screen route. Backed by FE-7. Fetch options only when state is `AWAITING_VENUE_RANKING` or later.

Layout:

- Title **Rank your venues**, subtitle "Drag to order. We'll book the one you both like most." plus `DeadlineCountdown(rankingDeadline)`.
- `ReorderableListView` of N cards (N = `options.length`, 1 to 3). Each card: rank badge on the left (1, 2, 3 in a filled circle), venue `name`, `address`, drag handle on the right. No thumbnail (backend returns null); use a neutral map-pin placeholder tile so cards keep a consistent height. Tap a card to expand a one-line "Open in Maps" link using the address.
- If N == 1: replace the list with a single card and caption "Only one venue is available right now. Confirm to continue." Button reads **Confirm venue**.
- Read-only mode when `myRankings.isNotEmpty` on load: cards locked in the user's submitted order, drag handles hidden, banner "Your ranking is in. Waiting for {partnerName}." and no button.
- Primary button **Send my ranking**. Sends exactly N entries with ranks `1..N` from list position.

Result handling:
- `venueAssigned == true`: push a lightweight result screen "It's {venueName}" with the address and the button **Back to your date**; detail refetches and now shows the booking card (UI-8).
- `venueAssigned == false`: pop to detail, toast "Ranking sent. Waiting for {partnerName}."
- 409 or 400 `invalid_input` on submit: pop and refetch (partner may have ranked first and triggered assignment).

Known backend gap: if N is 1 or 2 the backend currently rejects the submission (quirk 8). Do not pad the payload. On a 400 here, show "We're still sorting venues for this date. Try again shortly." and pop. Leave a `// TODO(backend L3)` comment.

Acceptance: reorder updates rank badges live; payload test asserts ranks are a permutation of `1..N`; read-only mode has no drag handles and no submit button; N == 1 layout renders.

---

## UI-8 Booking card and presence confirmation

Sits inside UI-4's CTA area. Backed by FE-8.

Booking card (`VENUE_ASSIGNED`, `VENUE_CONFIRMATION_PENDING`, `BOOKED`, `AWAITING_PRESENCE_CONFIRMATION`, `READY`):

- Venue name as a title, address, time range, and `bookingReference` in a muted monospace row labelled "Booking ref" when non-null.
- Row of actions: **Directions** (opens the platform maps app with the address), **Add to calendar** (uses the app's existing calendar helper if one exists, otherwise `add_2_calendar` or equivalent; 120-minute event, title "Date with {partnerName} at {venueName}").
- For `VENUE_ASSIGNED` / `VENUE_CONFIRMATION_PENDING` prepend a muted line "We're confirming your table. You'll see the booking here once it's done." and hide the booking ref row.

Presence (`AWAITING_PRESENCE_CONFIRMATION`):

- Two status rows under the card: "You" and "{partnerName}", each with a tick when confirmed. Values from `PresenceConfirmationStatus` after the user acts; before that, show "You: not yet" and leave the partner row as "not yet" unless a response is cached.
- Primary button **I'm coming** when you have not confirmed. On success, replace the button with the two-row status and toast "Confirmed. Waiting for {partnerName}." If the response shows both confirmed, refetch detail and render the `READY` panel.
- Never compute the 24h window locally; the button exists solely because `state == AWAITING_PRESENCE_CONFIRMATION`.

`READY`: card plus a full-width success pill "You're both confirmed" and a caption with the venue and time.

Acceptance: button rendered only for `AWAITING_PRESENCE_CONFIRMATION`; after a mocked confirm the partner-pending row is visible; Directions launches a maps URL containing the encoded address; calendar event duration is 120 minutes.

---

## UI-9 Cancel flow

Entry: overflow menu on UI-4 (and a text button at the bottom of the availability, deposit and ranking screens: "Cancel this date"). Backed by FE-9.

Confirmation dialog copy, chosen client-side from `state` and `scheduledStart` for the copy only:

- Pre-commitment (`AWAITING_AVAILABILITY`, `AWAITING_DEPOSIT`): title "Cancel this date?", body "Anything you've paid comes straight back to you. {partnerName} will be told the date is off."
- Post-commitment, more than 24h before `scheduledStart`: title "Cancel and lose your deposit?", body "You've both committed, so cancelling now means your {tokenCost} deposit goes to {partnerName} and yours is not refunded."
- Post-commitment, within 24h: same as above with an extra line "This is a late cancellation."
- Optional single-line reason field, placeholder "Add a note (optional)". Sent as `reason`; when blank send `{}` per quirk 3.
- Buttons: **Keep the date** (default, primary style) and **Cancel date** (destructive text style).

After the call: replace the detail screen content with the terminal panel (UI-10) using the `CancellationResult`: if `result.mine(uid)?.amount` is non-null and greater than zero, show "{amount} tokens refunded to your wallet." Also refresh wallet balance.

409 on cancel (date already moved on): dismiss dialog, refetch, toast "Something changed. Updated."

Acceptance: three copy variants verified by widget test using fixtures; blank reason produces `{}` body; refund line shows the exact string from the response.

---

## UI-10 Terminal panels

Rendered in UI-4's CTA area when `state.isTerminal`. Stepper above still renders from `timeline` (all complete for `COMPLETED`; `SKIPPED` rows greyed and struck for `CANCELLED`/`EXPIRED`).

- `COMPLETED`: heading "You met!", body "Hope it went well.", button **Back to dates**. Leave a `// TODO(feedback)` placeholder for the post-date feedback flow (out of MVP scope).
- `CANCELLED`: heading "This date was cancelled", body "If you had a deposit in play, check your wallet for any refund." (reason is not exposed by the backend, quirk 9; do not guess who cancelled).
- `EXPIRED`: heading "This date ran out of time", body "It can happen when times don't overlap, a deadline passes, or no venue was free. Any deposit has been refunded." Button **Back to dates**.

Generic error UX shared by all dates screens (FE-10 mapping): 401 → hand to the app's re-auth flow; 403/404 → pop to the dates tab with toast "That date isn't available."; 409 and the quirk 1/2 400s → silent refetch plus "Something changed. Updated." toast; network failure → inline retry banner, never a dialog; unknown → snackbar with `message` if present, otherwise "Something went wrong. Try again."

Acceptance: three terminal fixtures render the right heading; a fixture where `timeline` has `SKIPPED` rows shows them struck through; each error code path has a widget test and none surfaces as an uncaught exception.

---

## UI-11 Match to date handoff

Backed by FE-2. In the existing likes/matches flow, when `matchAction` returns a `MutualMatchResponse`:

- Show the app's existing "It's a match" moment if one exists, adding a single line "Your date with {partnerName} is ready to plan" and a primary button **Plan the date** that pushes `/dates/{dateId}`.
- If no match moment exists, push `/dates/{dateId}` directly with a top banner on arrival "You matched with {partnerName}. First, pick your times."
- Also bump the Dates tab badge (a dot on the heart icon, as in the screenshots) whenever there is at least one active date whose pill tone is `action` for this user. Clear it when none remain.

Acceptance: a mocked 200 lands on the detail screen in `AWAITING_AVAILABILITY`; a 204 changes nothing; tab dot shows/hides with the active list.

---

## UI-12 Polish pass

After UI-1 to UI-11 are merged:

- Motion: card press scale, stepper `CURRENT` transition when a step completes after a refetch (animate the fill), success screens fade.
- Accessibility: every icon-only control has a semantic label; stepper rows announce "step 3 of 6, deposit, current"; pills are read as status; colour is never the only status signal (icons plus text).
- Dark mode parity using theme tokens only.
- Text scaling to 130% without clipping on the card and the availability rows.
- Copy review: grep `lib/features/dates` for `—` and fail CI if found.

Acceptance: `flutter analyze` clean, goldens updated for light and dark, the em-dash check is wired into the existing lint step.

---

## Open product decisions (defaults chosen, flag if you disagree)

1. **History via icon, not tabs.** UI-3 puts Past/Cancelled behind the clock icon rather than FE-3's three tabs, matching screenshot 2. Change to tabs if the design team prefers.
2. **No edit pencil.** Screenshot 2 has a pencil on the card. Muse has nothing user-editable on a booked date (times and venue are agreed jointly), so it is omitted. If it should open the availability picker during `AWAITING_AVAILABILITY`, add it only in that state.
3. **Polling at 45s** while waiting on the partner. The integration doc allows 30 to 60s. Adjust if battery or load becomes a concern.
4. **Chat bubble on the card** is only shown if the app already has messaging. Muse's positioning is "slow, intentional" and there is no chat endpoint in the dates module, so do not build one here.
