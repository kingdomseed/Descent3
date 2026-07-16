---
name: revival-transport-security-operations
description: Build and verify Revival's evidence-selected native multiplayer transport, record protection, discovery, Internet reachability, administration, privacy, abuse controls, deployment, operating cost, monitoring, and outage behavior.
---

# Revival transport, security, and operations

Keep hostile network handling at explicit boundaries and keep the simulation independent of transport and service machinery.

## Authority and activation

Read [`AGENTS.md`](../../../AGENTS.md), [`architecture.md`](../../../docs/revival/architecture.md), [`internet-multiplayer-study.md`](../../../docs/revival/internet-multiplayer-study.md), [`roadmap.md`](../../../docs/revival/roadmap.md), [`current-plan.md`](../../../docs/revival/current-plan.md), [`verification.md`](../../../docs/revival/verification.md), [`engineering-principles.md`](../../../docs/revival/engineering-principles.md), and the network/service rows in [`functional-completeness-ledger.md`](../../../docs/revival/functional-completeness-ledger.md).

This skill is installed now. Phase 0 first records current direct, player-hosted, community-operated, platform-provided, and third-party-supported Internet options without adding production transport types. Review and amend the detailed contracts against the accepted topology, final simulation, current platform and selected-provider APIs, and the actual operational owner immediately before Phase 9 transport work. Network and CryptoKit are evaluated only where applicable. Exact algorithms, records, tokens, leases, bounds, costs, and outage policy are fixed then through an accepted decision and focused tests.

## Native boundaries

- Use Network and Bonjour directly in RevivalMac and RevivalMobile for the LAN contract and the native boundaries selected for Internet play; do not create a cross-platform transport abstraction.
- RevivalMobile owns its local-network usage description, Bonjour service declarations, permission-denial recovery, and explicit suspension/background session outcome. Dedicated no-window hosting remains Mac-only.
- Use CryptoKit directly when the accepted topology has an authority, peer, rendezvous, or service trust boundary that needs project-owned record protection.
- Do not assume a relay, always-on service, direct-IP route, or third-party provider before the accepted 2026 evidence selects one. If a relay or service exists, keep it bounded and outside simulation authority.
- Validate, authenticate, rate-limit, bound, and canonicalize hostile input once at intake. Trusted typed commands enter the simulation without repeated wire checks.
- Keep discovery, reachability, join authorization, any selected service data, local administration, encrypted remote administration, monitoring, deployment, and recurring-cost responsibilities explicit and small.
- Preserve clear control-plane and data-plane outage behavior. A service failure never silently changes authority or opens an insecure fallback.

## Implement one reachable flow

1. Threat-model the concrete registration, browse, join, session-record, reachability, selected-service, media, or administration flow.
2. Name trust boundaries, identities, data visibility, replay and sequencing rules, storage, rates, lifetimes, and failure outcomes.
3. Write the focused failing boundary or lifecycle test.
4. Implement the smallest direct flow at the selected topology's actual transport and trust boundaries, using Network or CryptoKit only where applicable.
5. Exercise malformed, unauthenticated, replayed, reordered, expired, oversized, rate-limited, reconnect, and outage cases that are actually reachable.
6. Prove the resulting canonical command or payload enters the existing simulation path.
7. Add deployment, privacy, monitoring, and operator evidence before calling a public-service capability complete.

## Prohibited complexity and insecurity

Do not add original-server interoperability, original reliability or packet layers, Telnet, shell commands, plaintext admin, shared service/session keys, unnecessary active payload inspection by a selected service, insecure fallback, generic service mesh, custom cryptography, transport abstraction for hypothetical platforms, or defensive branches throughout the simulation. Do not claim production readiness from localhost success or select an architecture that lacks a viable operator and recurring-cost record.

## Verification

Use focused red/green evidence plus declared LAN, representative Internet-reachability, reconnect, outage, key, replay-rejection, hostile-input, media, authorization, audit, capacity, privacy, deployment, recurring-cost, continuity, and monitoring matrices applicable to the accepted topology. Run mobile LAN discovery, local-network permission denial/recovery, listen hosting and lifecycle outcomes on applicable physical iPhone and iPad hardware; a simulator does not close those claims. Representative support-floor certification is required before claiming that floor for public beta or release, not before independent Mac/shared transport work. Record skipped cases as non-passes. Verify exact public configuration and deployed revision when deployment is requested.

Architecture, evidence, simplicity, and fidelity-to-capability review remain independent under [`revival-review`](../revival-review/SKILL.md). Security findings are concrete reachable boundary failures, not requests for defensive code everywhere.

## Primary Apple references

- [Network framework](https://developer.apple.com/documentation/network)
- [CryptoKit](https://developer.apple.com/documentation/cryptokit)
- [Bonjour](https://developer.apple.com/bonjour/)
- [TN3179: Understanding local network privacy](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)
