---
name: revival-transport-security-operations
description: Build and verify Revival's native multiplayer transport, record protection, discovery, relay, administration, privacy, abuse controls, deployment, monitoring, and outage behavior.
---

# Revival transport, security, and operations

Keep hostile network handling at explicit boundaries and keep the simulation independent of transport and service machinery.

## Authority and activation

Read [`AGENTS.md`](../../../AGENTS.md), [`architecture.md`](../../../docs/revival/architecture.md), [`roadmap.md`](../../../docs/revival/roadmap.md), [`verification.md`](../../../docs/revival/verification.md), [`engineering-principles.md`](../../../docs/revival/engineering-principles.md), and the network/service rows in [`functional-completeness-ledger.md`](../../../docs/revival/functional-completeness-ledger.md).

This skill is installed now. Review and amend its detailed contracts against the final simulation, current Apple Network and CryptoKit APIs, and the owned deployment environment immediately before Phase 9 transport work. Exact algorithms, records, tokens, leases, bounds, and outage policy are fixed then through an accepted decision and focused tests.

## Native boundaries

- Use Network framework QUIC directly for Bonjour LAN and outbound relay connections.
- Use CryptoKit directly for authenticated authority/client records across relay legs.
- Keep the public relay bounded and opaque to session content and session keys; it is not simulation authority.
- Validate, authenticate, rate-limit, bound, and canonicalize hostile input once at intake. Trusted typed commands enter the simulation without repeated wire checks.
- Keep discovery, join authorization, relay data, local administration, encrypted remote administration, monitoring, and deployment responsibilities explicit and small.
- Preserve clear control-plane and data-plane outage behavior. A service failure never silently changes authority or opens an insecure fallback.

## Implement one reachable flow

1. Threat-model the concrete registration, browse, join, session-record, relay, media, or administration flow.
2. Name trust boundaries, identities, data visibility, replay and sequencing rules, storage, rates, lifetimes, and failure outcomes.
3. Write the focused failing boundary or lifecycle test.
4. Implement the smallest direct Network/CryptoKit flow.
5. Exercise malformed, unauthenticated, replayed, reordered, expired, oversized, rate-limited, reconnect, and outage cases that are actually reachable.
6. Prove the resulting canonical command or payload enters the existing simulation path.
7. Add deployment, privacy, monitoring, and operator evidence before calling a public-service capability complete.

## Prohibited complexity and insecurity

Do not add original-server interoperability, original reliability or packet layers, Telnet, shell commands, plaintext admin, shared relay/session keys, active payload inspection by the relay, insecure fallback, generic service mesh, custom cryptography, transport abstraction for hypothetical platforms, or defensive branches throughout the simulation. Do not claim production readiness from localhost success.

## Verification

Use focused red/green evidence plus declared LAN, representative-NAT relay, reconnect, outage, key, replay-rejection, hostile-input, media, authorization, audit, capacity, privacy, deployment, and monitoring matrices. Record skipped cases as non-passes. Verify exact public configuration and deployed revision when deployment is requested.

Architecture, evidence, simplicity, and fidelity-to-capability review remain independent under [`revival-review`](../revival-review/SKILL.md). Security findings are concrete reachable boundary failures, not requests for defensive code everywhere.

## Primary Apple references

- [Network framework](https://developer.apple.com/documentation/network)
- [CryptoKit](https://developer.apple.com/documentation/cryptokit)
- [Bonjour](https://developer.apple.com/bonjour/)
