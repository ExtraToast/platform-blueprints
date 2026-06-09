# DNS Zone Policy

Design-first documentation only. Do not copy consumer zone files into this
repository.

## Cloudflare Imports

Use Cloudflare imports for reviewable zone changes, but keep the zone file in
the consumer repository or DNS operations repository. This shared repository
only documents policy.

## Proxy Policy

Default browser-facing HTTP services may be proxied when the ingress controller
and certificate policy support it. Direct-origin records should be explicit and
reviewed because they expose the origin address.

## Mail Records

Mail transport records must remain direct-origin. MX, SPF, DKIM, DMARC, MTA-STS,
TLS reporting, and mail host A/AAAA records should not be proxied.

## External DNS Ownership

Each cluster should use a unique TXT owner ID and domain filter. Shared packs
must parameterize both values. Multiple clusters managing the same zone need
separate ownership markers and explicit record boundaries.

## Exceptions

Document every direct-origin exception with:

- record name
- reason it cannot be proxied
- expected source of truth
- owner ID when managed by external-dns
- rollback plan
