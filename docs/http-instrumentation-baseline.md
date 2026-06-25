# HTTP instrumentation baseline

Status: pending manual execution.

This repository now includes safe HTTP instrumentation for local measurement, but
this baseline requires a functional backend environment and a technical account
without personal or emotional data. No production-like measurements were
invented in this change.

## Scope

- Frontend clients instrumented:
  - `authenticatedDioProvider`
  - `authRepositoryProvider`
  - `appVersionDioProvider`
  - `CareClaimController`
- Backend metrics added:
  - `evolua.timeline.assembly`
  - `evolua.monetization.access`
  - `evolua.reward.session`
  - `evolua.reward.confirmation`
  - `evolua.ai.insight`
  - `evolua.ai.provider.call`

## Required scenario

Run three times under the same conditions:

1. Start with an already-authenticated technical session.
2. Open Home.
3. Consider Home stable after the first Home render and two consecutive seconds
   with no in-flight requests.
4. Stop after 30 seconds if stability is not reached.

## Environment record

Fill once per run:

| Field | Run 1 | Run 2 | Run 3 |
| --- | --- | --- | --- |
| Date/time |  |  |  |
| Branch |  |  |  |
| Commit SHA |  |  |  |
| Platform |  |  |  |
| Build type |  |  |  |
| Backend configuration |  |  |  |
| Database state (warm/fresh) |  |  |  |

## Measurement record

| Metric | Run 1 | Run 2 | Run 3 |
| --- | --- | --- | --- |
| Total logical requests |  |  |  |
| Total HTTP attempts |  |  |  |
| Refresh requests |  |  |  |
| Retries |  |  |  |
| Errors |  |  |  |
| Cancellations |  |  |  |
| Timeouts |  |  |  |
| Total duration |  |  |  |
| Average attempt duration |  |  |  |
| Known response bytes |  |  |  |
| Time until Home stable |  |  |  |

## Calls by normalized route

| Method route | Run 1 attempts | Run 2 attempts | Run 3 attempts | Notes |
| --- | ---: | ---: | ---: | --- |
| `GET /v1/...` |  |  |  |  |

## Backend metrics to compare

Use the environment's authorized Actuator access. Do not change Actuator
security for this baseline.

Suggested checks:

```bash
curl -s "$BACKEND_BASE_URL/actuator/metrics/evolua.timeline.assembly"
curl -s "$BACKEND_BASE_URL/actuator/metrics/evolua.monetization.access"
curl -s "$BACKEND_BASE_URL/actuator/metrics/evolua.reward.session"
curl -s "$BACKEND_BASE_URL/actuator/metrics/evolua.reward.confirmation"
curl -s "$BACKEND_BASE_URL/actuator/metrics/evolua.ai.insight"
curl -s "$BACKEND_BASE_URL/actuator/metrics/evolua.ai.provider.call"
```

## Privacy rules

Do not paste or store:

- Authorization headers or tokens.
- Request/response bodies.
- User IDs, e-mail addresses, checkout IDs, reward session IDs.
- Emotional text, mood, reflections, care report content, or AI prompts.
