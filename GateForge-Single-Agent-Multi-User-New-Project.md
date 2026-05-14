# Project Intake — <Project Name>

> Fill this out **once** at project kickoff. The AI Agent uses this file to seed the GateForge blueprint repository and to configure the Telegram intake bot. After kickoff, all subsequent changes go through Telegram → GitHub Issues, not by editing this file directly.

## 1. Project Metadata

| Field | Value |
|---|---|
| Project Name | [e.g. Project A] |
| Project Code | [e.g. PRJ001] |
| Repository URL | [https://github.com/<org>/<repo>] |
| Blueprint Version Pinned | https://github.com/tonylnng/gateforge-blueprint-template |
| Key User (final decision maker on conflicts) | Vincent LAM · [telegram ID] |


## 2. Business Context

- **Problem statement:** [2–4 sentences]
- **Primary outcome / success metric:** [e.g. reduce ticket triage time by 50%]
- **In-scope features (high level):** [bullet list]
- **Out of scope:** [bullet list]
- **Assumptions & constraints:** [bullet list]

## 3. End-User Roster (Telegram)

BotFather is Telegram's official bot for managing bots.

Open Telegram and search for @BotFather (verified blue check). Start a chat and tap Start.

Send /newbot.

Choose a display name (e.g. SiiA [Project] [User Name]). This is what users see. (e.g. SiiA ESG Vincent)
Choose a username ending in bot (e.g. siia_esg_vinent_bot). Must be globally unique on Telegram.

BotFather replies with your HTTP API token — a string like 7891234567:AAH...zXyZ. Treat this as a secret (anyone holding it controls the bot). Save it in your vault, never share it.

| Telegram Handle | Telegram User ID | Role | Notes |
|---|---|---|---|
| @siia_esg_vincent_bot | 123456789 | Key User | Final tiebreaker |
| @… | … | Requester | |
| @… | … | Requester | |


## 4. Conflict-Resolution Protocol

- When the AI Agent detects conflicting instructions across users or against an existing requirement, it MUST:
  1. Open a GitHub Issue with label `conflict` and template `.github/ISSUE_TEMPLATE/conflict.md`.
  2. Cross-link the originating Telegram messages and the affected blueprint document.
  3. Notify the Key User in Telegram and pause downstream work on the impacted item.
  4. Record the decision in `project/decision-log.md` once resolved, then resume.
- **Auto-escalation if no response:** [Telegram reminder cadence]

## 5. Required Credentials (references only — never paste secrets here)
| Secret | Storage Location 
|---|---|
| GitHub PAT (repo: read/write, issues: write, projects: write) |  |
| Application Server Info | IP, User Name, Password |


## 6. QA Strategy (seed for `qa/test-plan.md`)

- **Lane A (scripted Playwright + Gherkin):** [yes/no]
- **Lane B (AI-explorer via OpenClaw):** [yes/no]
- **Performance test required:** [yes/no]
- **QA runner host:** [headless Ubuntu VM details]

## 7. Versioning & Governance

- This project follows the blueprint's `VERSIONING.md`: MAJOR bumps require Key User approval; MINOR/PATCH are agent-driven.
- All PRs must include the **Pre-Flight Acknowledgement** from the relevant `AGENTS.md`.
- `project/decision-log.md` is the system of record for every non-trivial decision.
