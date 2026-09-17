# API Optimization Request: ETag Caching for Match Batch Endpoint

## Context

**Current Behavior:**
- Flutter app calls `GET /match/` every time the match screen mounts
- This happens on navigation back, app resume, hot reload, and initial load
- Backend already caches presigned URLs for profile photos, making responses fast
- However, we're still fetching full response bodies even when nothing has changed

**Problem:**
Redundant API calls that return identical data waste:
- User bandwidth (especially on mobile data)
- Server resources (JSON serialization, database queries for non-cached data)
- Battery life (network radio stays active longer)

**Example Redundant Call Pattern:**
1. User views match batch (7 profiles fetched)
2. User navigates away (to profile, settings, etc.)
3. User returns to match screen (same 7 profiles fetched again)
4. User navigates away again
5. User returns → another identical fetch

If user hasn't performed any actions (like/pass) and the batch hasn't changed, steps 3 and 5 are wasteful.

---

## Requested Backend Changes

### Implement HTTP ETag Caching for `GET /match/` Endpoint

**What to Add:**

1. **Generate ETag for each match batch response**
   - ETag should uniquely identify the current state of the user's match batch
   - Formula: `hash(batchID + lastUpdatedAt + userActionCount + batchVersion)`
   - Example: `"2f7b4c8a9e1d3f5b"` (short hash/fingerprint)

2. **Return Cache-Control and ETag headers**
   ```http
   HTTP/1.1 200 OK
   ETag: "2f7b4c8a9e1d3f5b"
   Cache-Control: private, max-age=300
   Content-Type: application/json

   { "profiles": [...], "batchId": "..." }
   ```

3. **Handle `If-None-Match` conditional requests**
   - When client sends `If-None-Match: "2f7b4c8a9e1d3f5b"` header
   - Compare with current batch ETag
   - If match → return `304 Not Modified` (no body, just headers)
   - If different → return `200 OK` with full fresh data

**Why ETag Over Other Approaches:**
- ✅ Industry standard (HTTP/1.1 RFC 7232)
- ✅ Works with existing HTTP infrastructure (CDNs, proxies)
- ✅ Client-agnostic (works for web, iOS, Android, future platforms)
- ✅ Minimal backend complexity (just header logic)
- ✅ No frontend state management complexity (Dio handles it)

---

## How It Currently Works

### Frontend (Flutter + Dio)
```dart
// match_screen.dart:32-34
WidgetsBinding.instance.addPostFrameCallback((_) {
  ref.read(matchBatchProvider.notifier).fetchDailyBatch();
});
```

**Current Flow:**
1. Screen mounts → calls `fetchDailyBatch()`
2. Sends `GET /match/` via Dio ApiClient
3. Receives full JSON response (~50KB with 7 profiles + photos)
4. Parses JSON → builds profile list
5. Updates UI

**Every. Single. Time.**

### Backend (Go + Gin)
```go
// Current implementation (simplified)
func (h *MatchHandler) GetDailyBatch(c *gin.Context) {
    userID := c.GetString("userID")

    // Fetch from cache or database
    batch := h.matchService.GetBatch(userID)

    // Generate presigned URLs (cached)
    enrichedBatch := h.enrichWithPhotos(batch)

    c.JSON(http.StatusOK, enrichedBatch)
}
```

**Response Time:** Fast (~200-400ms) thanks to presigned URL caching, but still sends full body.

---

## Expected New Behavior

### Backend (With ETag Support)
```go
func (h *MatchHandler) GetDailyBatch(c *gin.Context) {
    userID := c.GetString("userID")

    // Fetch batch metadata
    batch := h.matchService.GetBatch(userID)

    // Generate ETag from batch state
    etag := h.generateBatchETag(batch)

    // Check If-None-Match header
    clientETag := c.GetHeader("If-None-Match")
    if clientETag != "" && clientETag == etag {
        // Nothing changed - return 304
        c.Status(http.StatusNotModified)
        return
    }

    // Data changed - return full response with new ETag
    enrichedBatch := h.enrichWithPhotos(batch)
    c.Header("ETag", etag)
    c.Header("Cache-Control", "private, max-age=300")
    c.JSON(http.StatusOK, enrichedBatch)
}

// Helper to generate consistent ETag
func (h *MatchHandler) generateBatchETag(batch *MatchBatch) string {
    data := fmt.Sprintf("%s:%d:%d",
        batch.ID,
        batch.UpdatedAt.Unix(),
        batch.ActionCount,
    )
    hash := sha256.Sum256([]byte(data))
    return fmt.Sprintf(`"%x"`, hash[:8]) // Use first 8 bytes
}
```

### Frontend (With ETag Interceptor)
```dart
// Dio interceptor automatically adds If-None-Match header
// and handles 304 responses

// match_screen.dart - NO CHANGES NEEDED
WidgetsBinding.instance.addPostFrameCallback((_) {
  ref.read(matchBatchProvider.notifier).fetchDailyBatch();
});
```

**New Flow:**
1. Screen mounts → calls `fetchDailyBatch()`
2. Dio sends `GET /match/` with `If-None-Match: "cached-etag"` header
3. **Backend checks ETag:**
   - **If unchanged:** Returns `304 Not Modified` (~500 bytes, ~50ms)
     - Dio uses cached response from previous request
     - No JSON parsing needed
   - **If changed:** Returns `200 OK` with full data (~50KB, ~200-400ms)
     - Dio stores new ETag for next request
     - Frontend gets fresh data
4. Updates UI (from cache or fresh data)

---

## When ETag Changes (Cache Invalidation Triggers)

The backend should generate a **new ETag** when:

1. **User performs match action** (like/pass)
   - `batch.ActionCount` increments → new ETag
   - Next fetch gets fresh data with updated profiles list

2. **New batch becomes available**
   - `batch.ID` changes (daily batch rotation)
   - `batch.UpdatedAt` updates
   - Forces fresh fetch

3. **Mutual match occurs**
   - Batch state changes (matched profile removed)
   - `batch.UpdatedAt` updates

4. **Admin/system changes**
   - Profile moderation removes a user
   - Batch needs to be refreshed

**Frontend Cache Invalidation:**
After user actions, frontend can optionally clear its ETag cache to force fresh fetch:

```dart
Future<void> performMatchAction(String matchId, MatchAction action) async {
  await _matchRepository.submitAction(matchId, action);

  // Optional: Clear cache to force fresh fetch
  _apiClient.clearETagCache('/match/');

  await fetchDailyBatch(); // Will get 200 OK with fresh data
}
```

---

## Expected Performance Improvements

**Scenario: User navigates back to match screen 3 times without actions**

### Current (No Caching)
- Request 1: 200ms, 50KB downloaded
- Request 2: 200ms, 50KB downloaded
- Request 3: 200ms, 50KB downloaded
- **Total: 600ms, 150KB**

### With ETag Caching
- Request 1: 200ms, 50KB downloaded (initial fetch)
- Request 2: 50ms, 500 bytes (304 response)
- Request 3: 50ms, 500 bytes (304 response)
- **Total: 300ms, 51KB (66% reduction in data, 50% faster)**

**Metrics to Track:**
- `304 Not Modified` response rate (expect 40-60% for match endpoint)
- Average response size reduction
- P95 latency improvements

---

## Implementation Checklist

### Backend (Go)
- [ ] Add ETag generation function (using batch state hash)
- [ ] Update `GET /match/` handler to:
  - [ ] Set `ETag` header on all 200 responses
  - [ ] Set `Cache-Control: private, max-age=300` header
  - [ ] Check `If-None-Match` header
  - [ ] Return `304 Not Modified` when ETag matches
- [ ] Add unit tests for ETag generation consistency
- [ ] Add integration tests for 304 responses

### Frontend (Flutter)
- [ ] Add `ETagCacheInterceptor` to Dio client
- [ ] Handle `304 Not Modified` responses (use cached data)
- [ ] Store ETags in memory (per-session cache)
- [ ] Add cache invalidation after match actions
- [ ] Test cache behavior (mount/unmount screen multiple times)

### Testing
- [ ] Verify 304 responses return no body
- [ ] Verify ETag changes after user action
- [ ] Verify cache works across navigation
- [ ] Test cache expiry after `max-age` (5 minutes)
- [ ] Test multi-device scenario (different ETags per user session)

---

## Questions for Backend Team

1. **Where is batch state currently stored?**
   - Do you have a `UpdatedAt` timestamp on batch records?
   - Is there an `ActionCount` or similar field to track user actions?

2. **What should trigger ETag changes?**
   - Just user actions + new batches?
   - Or also time-based (e.g., mutual matches that happen server-side)?

3. **Caching infrastructure:**
   - Are you using Redis for batch caching?
   - Can we cache the ETag itself to avoid recalculating?

4. **Rollout strategy:**
   - Should we implement for `/match/` first, then extend to other endpoints?
   - Any concerns about cache headers with existing CDN/proxy setup?

---

## References

- **HTTP ETag Specification:** [RFC 7232](https://datatracker.ietf.org/doc/html/rfc7232#section-2.3)
- **Dio Caching:** Dio supports cache interceptors and `If-None-Match` out of the box
- **Flutter HTTP Caching:** Use `dio_cache_interceptor` package for persistent caching (optional upgrade)

---

## Summary

**What:** Add HTTP ETag caching to `GET /match/` endpoint
**Why:** Reduce redundant data transfer and improve app responsiveness
**How:** Backend returns ETag header, checks If-None-Match, returns 304 when unchanged
**Impact:** 50-70% reduction in bandwidth and latency for repeated screen visits

This is a standard web optimization that aligns with your existing backend caching strategy (presigned URLs) and provides automatic benefits to all clients (mobile, web, future platforms).
