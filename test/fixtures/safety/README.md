Responses from RFC-006 §5 "Safety" (eros-backend `docs/RFC-006-date-chat.md`). The app's tests
stub HTTP with these until the backend has CH-B7 and CH-B8. The reason labels are made up: the
real ones come from `GET /safety/reasons`.

`content_report_created.json`, `block_created.json` and `block_active_date.json` are the
`POST /safety/content-reports` and `POST /safety/blocks` answers from RFC-009 §5.5 and §5.8, as
eros-backend's develop serves them (CF-B4, CF-B7): `ContentReportResultDTO`, `BlockResultDTO`,
and the 409 `ApiError`.
