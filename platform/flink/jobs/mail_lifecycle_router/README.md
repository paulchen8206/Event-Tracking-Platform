# Mail Lifecycle Router

## Purpose

This starter job consumes raw mail lifecycle events, validates the canonical envelope, enriches records with routing metadata, and emits consumer-specific streams.

## Responsibilities

- Validate event contracts and required identifiers
- Normalize event types and timestamps
- Route customer-safe records to analytics topics
- Preserve operational detail for internal tracking streams
- Emit platform health signals when validation or processing fails

## Inputs

- `evt.mail.lifecycle.raw`

## Outputs

- `evt.mail.lifecycle.normalized`
- `evt.mail.customer.analytics`
- `evt.mail.internal.tracking`
- `evt.platform.health`

## Next Implementation Step

Choose the production runtime for this job, then add the corresponding build and deployment assets under this directory.
