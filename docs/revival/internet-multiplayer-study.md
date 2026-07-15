# Internet multiplayer study

- Status: accepted research plan, amended; evidence collection pending
- Date: July 15, 2026
- Authority: Phase 0 research and decision record; not a production-topology selection

## Question

Select one affordable, operable 2026 path for native Internet hosting, discovery, joining, security, and explicit failure behavior without assuming that this project can fund or operate an always-on public service.

LAN is already bounded: direct hosting and Bonjour discovery use Network framework in both player applications. RevivalMobile must declare the required Bonjour services and local-network purpose, handle authorization denial and recovery, and stop or suspend networking under its accepted UIKit lifecycle policy. This study selects the Internet boundary. It creates no production transport types, schemas, targets, provider integration, or deployment until its evidence and decision are accepted.

## Candidate classes

Compare at least:

- direct and player-hosted approaches, including their real router, NAT, address-discovery, IPv4, IPv6, and inbound-connectivity requirements;
- community-operated rendezvous, directory, relay, or server-list approaches;
- Apple platform-provided multiplayer services that are actually available across the macOS, iOS and iPadOS player targets and their required session shapes;
- third-party hosted or peer-connectivity products with acceptable native integration, terms, continuity, privacy, and recurring cost;
- a project-operated service only if a named operator, sustainable budget, abuse response, monitoring, deployment, and continuity plan make it genuinely viable.

An option may combine classes only when the combined boundary is still one understandable production topology with one ownership and failure model.

## Evidence record

For every serious candidate, record:

| Field | Required evidence |
| --- | --- |
| Product outcome | Host, advertise or locate, authorize, join, reconnect, leave, and report an actionable failure |
| Session fit | Source-supported mode counts, released 32 network/player-slot infrastructure, four-player campaign co-op, observers, interactive hosting on both player applications, Mac-only dedicated hosting, and explicit mobile background/suspension behavior |
| Reachability | Representative home, restricted, IPv4, IPv6, NAT, firewall, and no-inbound cases; unsupported cases named explicitly |
| Trust and privacy | Identities, visible metadata, content visibility, encryption ownership, retention, deletion, and provider access |
| Abuse and operations | Rate limits, blocking, moderation, incident handling, monitoring, outage behavior, and service continuity |
| Integration | Current APIs, SDK or service dependencies, macOS/iOS/iPadOS availability, signing, entitlements and privacy declarations, local-network authorization, deployment shape, background limits, and update burden |
| Cost and owner | Measured development cost, recurring cost at declared usage assumptions, named operator, funding boundary, and shutdown consequence |
| Longevity | Vendor or community dependency, portability of user content and identity, exit plan, and behavior when the dependency disappears |
| Historical services | Disposition of lobby chat, rankings, persistent pilot statistics, and join-time package acquisition |

Fresh claims about 2026 APIs, services, pricing, limits, terms, or availability require dated primary evidence. A localhost demonstration, marketing claim, free trial, or unowned community endpoint is not operational proof.

## Deliverable and decision gate

The study owner produces one comparison and decision record in this document or a directly linked accepted evidence appendix. It names:

1. evidence owner, investigation dates, sources, Mac/iPhone/iPad test environments, usage and cost assumptions;
2. candidates investigated and why each remains viable or is rejected;
3. the selected topology and its transport, trust, discovery, reachability, ownership, cost, continuity, and outage boundaries;
4. deliberate differences from historical direct-IP, tracker, lobby, ranking, statistics, and mission-download behavior;
5. the exact disposition of `N-014`, `N-016`, `N-018`, and `N-019`;
6. the production types, targets, integrations, security review, and verification matrices Phase 9 may now introduce;
7. a re-evaluation trigger if cost, ownership, API availability, terms, or reachability evidence changes before implementation.

For `N-018` and `N-019`, the decision must either give each selected version 1.0 outcome a native owner and completion proof or record an explicitly approved exclusion and add its preserved idea to [Future opportunities](future-opportunities.md). Neither row may remain `researched` through Phase 10.

The study runs in parallel with early source-translation work and does not block unrelated Phase 1 implementation. Its accepted decision record is nevertheless a hard prerequisite for Phase 9 production transport, service, provider, security, or deployment work.

## Acceptance

The decision is acceptable only when at least one topology satisfies the required Internet outcome on both player applications with a viable operator and cost boundary, every rejected candidate has evidence rather than preference, unsupported reachability and mobile background behavior are explicit, historical service ideas receive recorded dispositions, and the selected path leaves one production mechanism.

If no candidate is affordable and operable, the study reports that result instead of inventing a service commitment. Product scope then requires an explicit user-approved amendment; the research record alone cannot silently remove Internet multiplayer.
