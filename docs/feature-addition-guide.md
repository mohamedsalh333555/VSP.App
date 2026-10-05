# VSP Feature Addition Guide

## Before coding
Identify:
- business owner
- source of truth
- mutation command
- read model/projection
- permissions
- localization keys
- Design System component
- tests

## Implementation order

1. Schema/migration, only when required.
2. Server-side rule/RPC for sensitive mutations.
3. Repository.
4. Coordinator/use case.
5. Provider/presentation state.
6. Screen/components.
7. ARB translations.
8. Tests.

## Verification

Run the repository CI pipeline. A feature is not complete when it merely compiles; its business rule, authorization, failure path, localization, and regression behavior must be verified.
