# INC-2024-018: Payment Processing Outage

## Detection Details

- Detected By: Automated alert from payment-gateway health check
- Timestamp: 2024-01-18T09:23:41Z
- Environment: Production
- Alert Source: PagerDuty — `payment-gateway /health` returning 503

## Timeline of Events

| Time (UTC) | Event |
| --- | --- |
| 09:23 | Health check alert fires; on-call engineer paged |
| 09:27 | Engineer accesses dashboard; confirms gateway is up but processing queue is stalled |
| 09:31 | Incident declared; severity set to SEV1 |
| 09:35 | Payment team lead joins war room |
| 09:42 | Root cause identified: message queue consumer stopped after unhandled exception in poison message processing |
| 09:58 | Hotfix deployed; queue processing resumed |
| 10:15 | Processing backlog cleared; all transactions completed or returned to sender |
| 10:30 | Incident declared resolved |

## Impact Summary

- Scope: New payment transactions failed during outage window
- User Impact: ~340 customers experienced failed checkout; ~12 support tickets opened
- Duration: 52 minutes (09:23 to 10:15)

## Root Cause Analysis

- Root Cause: Message consumer crashed when encountering a malformed message with an unexpected schema version. The error was not caught, causing the consumer thread to terminate. No restart mechanism existed for this isolated failure mode.
- Contributing Factors: Consumer deployed without dead-letter queue configured; monitoring did not alert on queue depth growth; no circuit breaker for poison message handling
- Misaligned Expectations: Expected all messages to conform to schema v2; a backend service was emitting v1 messages during a brief period during migration

## Resolution

- Immediate Fix: Restarted message consumer with dead-letter queue handler added; failed messages moved to retry queue with backoff
- Validated In: Staging environment with schema v1 and v2 messages interleaved; confirmed graceful handling
- Status: Resolved

## Action Items

- [ ] Configure dead-letter queue for payment-gateway consumer (Owner: Backend Platform, Due: 2024-01-25)
- [ ] Add queue depth alerting with 5-minute threshold (Owner: SRE, Due: 2024-01-22)
- [ ] Implement circuit breaker for poison message handling (Owner: Payment Team, Due: 2024-02-01)
- [ ] Update message schema validation to handle versioning gracefully (Owner: Backend Team, Due: 2024-01-30)

## Severity and Priority

- Severity: High
- Priority: P1

## Additional Information

- Assigned To: Priya Sharma
- Reported On: 2024-01-18
- Due Date for Follow-Up: 2024-02-15

## Review

- [ ] Destination confirmed.
- [ ] Human review required.
