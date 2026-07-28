# Observability Ownership — Al Batal Elite

Status: DRAFT — placeholders only.

## Provider

Crash reporting provider: Sentry
Fallback: NoOpCrashReportingService when SENTRY_DSN is empty.

## Ownership

Product Owner: [PENDING]
Engineering Lead: [PENDING]
QA Lead: [PENDING]
Security Owner: [PENDING]
On-call Owner: [PENDING]

## Alert Thresholds

- Crash-free user rate: [PENDING]
- Checkout failure rate: [PENDING]
- Payment failure rate: [PENDING]
- Paymob callback failure rate: [PENDING]
- Edge Function 5xx rate: [PENDING]

## Incident Response

1. Verify alert in Sentry.
2. Check release SHA and deployment time.
3. Check Supabase Edge Function logs.
4. Check Paymob sandbox/provider status if payment-related.
5. Mitigate or roll back if regression is confirmed.
6. Record incident owner and timeline.

## PII Rules

- Attach user UUID only.
- Never attach email.
- Never attach phone.
- Never attach name.
- Never attach address.
- Never attach payment card data.
- Never attach tokens or secrets.