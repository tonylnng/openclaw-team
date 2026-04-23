# Usage Guide

The stack provides six role-based Ubuntu containers for OpenClaw-style work coordination.

## Roles

| Container | Role |
|---|---|
| `openclaw-architect` | Architecture, requirements decomposition, technical governance |
| `openclaw-designer` | UX flows, UI specifications, product experience |
| `openclaw-developer` | Implementation, integration, build automation |
| `openclaw-qc` | Test planning, validation, release gates |
| `openclaw-operator` | Deployment, operations, monitoring, incident response |
| `openclaw-pa` | Personal assistant, coordination, summaries, task tracking |

## Workspace model

Each role has a private workspace:

```text
/workspace/role
```

All roles share a collaboration workspace:

```text
/workspace/shared
```

Use the private workspace for draft work and the shared workspace for handoff materials.

## Suggested shared folders

```text
/workspace/shared/
  inbox/
  decisions/
  specs/
  handoff/
  releases/
  incidents/
  experiments/
```

## Recommended workflow

1. Architect creates system direction in `/workspace/shared/specs`.
2. Designer adds user-facing flows and acceptance notes.
3. Developer implements and records build notes.
4. QC validates and writes test results.
5. Operator prepares deployment and operational runbooks.
6. PA summarizes decisions, tracks action items, and coordinates handoff.
