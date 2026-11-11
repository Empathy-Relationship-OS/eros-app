Responses from RFC-008 §6 "User" (eros-backend `docs/RFC-008-selfie-verification.md`). The app's
tests stub HTTP with these until the backend has VF-B3 and VF-B5. The pose wording, ids and links
are made up.

`selfie_unusable.json` is the 422 body. RFC-008 §6 gives it as `{ problem }` and VF-B3 adds "a
fresh upload link" without naming the field: the app reads it from `upload` (and `expiresAt`), the
same shape as the start response, and copes if it's missing.
