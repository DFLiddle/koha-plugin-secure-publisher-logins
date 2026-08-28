# OPAC access states (Phases 0–4)

Design for patron-facing login-info links on `opac-detail.pl`. Staff toolbar behaviour is **unchanged** (view button only when scope matches).

**Status:** Phase 4 signed off in v1.4.4. Phase 5 i18n prep shipped in v1.4.15 (runtime PO catalogs; de/fr hand-maintained).

## State machine (`interface=opac`)

| `state` | When | OPAC link label (Phase 2+) | `show` (compat) | Secrets |
|---------|------|----------------------------|-----------------|---------|
| `hidden` | No domain match, inactive only, health fail, plugin off | (none) | `0` | — |
| `login_required` | Anonymous; active credential matches bib `856$u` domain | Log in to check access | `0` | — |
| `view_allowed` | Logged in; scope OK; account OK | View login info | `1` | via `/view` only |
| `scope_denied` | Logged in; domain match; scope fails | Library not subscribed | `0` | — |
| `account_blocked` | Logged in; scope OK; debarred/expired/etc. | Login info not available | `0` | — |

Evaluation order:

1. Plugin enabled + `system_healthy_for_opac`
2. At least one **active** credential matches record domains (scope ignored)
3. If no patron session → `login_required`
4. If patron blocked (`patron_may_access_opac` false) and scope matches → `account_blocked`
5. If patron blocked and scope does not match → `scope_denied`
6. If `matching_credentials_for_biblio` (domain + scope) → `view_allowed`
7. Else → `scope_denied`

## Modal copy (Phases 3–4)

| State | Modal |
|-------|--------|
| `scope_denied` | “Your library is not subscribed to this online resource. Click the link below to suggest it for purchase.” Link: `{OPACBaseURL}/cgi-bin/koha/opac-suggestions.pl?op=add_form&biblionumber={bib}` |
| `account_blocked` | “Your account requires attention before the login info can be shown. Please write to {email} for help.” |

## `availability` response (OPAC)

| Field | Purpose |
|-------|---------|
| `show` | `1` only for `view_allowed` (backward compatible) |
| `label` | Translated action label for current state |
| `state` | One of the states above |
| `suggestion_url` | Set for `scope_denied` when `OPACBaseURL` configured |
| `modal_message` | Set for `scope_denied` and `account_blocked` |
| `suggestion_link_label` | Set for `scope_denied` (e.g. “Suggest for purchase”) |
| `help_email` | Set for `account_blocked` (branch replyto → branch email → sysprefs) |
| `manage`, `manage_label`, `manage_url`, `credential_id` | Unchanged; staff-only manage fields stay `0` on OPAC |

Staff (`interface=staff`): existing behaviour; `state` is `view_allowed` or `hidden`.

## Help email resolution (`account_blocked`)

First non-empty valid address:

1. Patron home library `branches.branchreplyto`
2. Patron home library `branches.branchemail`
3. System preference `ReplytoDefault`
4. System preference `KohaAdminEmailAddress`

## Disclosure

Subscribing libraries accept that a visible action link (when domain matches) indicates stored publisher credentials may exist. `856$u` on the record already signals subscription interest.

## Implementation phases

| Phase | Deliverable |
|-------|-------------|
| **0** | This document |
| **1** | `Matcher` domain match; `availability` states; OpenAPI; **no OPAC JS change** |
| **2** | “Log in to check access” + Koha login `return` + auto-open view modal (**v1.4.1**) |
| **3** | `scope_denied` label + suggestion modal (**v1.4.3**) |
| **4** | `account_blocked` label + help email modal (**v1.4.4**) |
| **5** | i18n catalogs, manual test plan, release |

## Phase 1 API verification

Replace `BIB`, `BASE`, and cookie as needed.

```bash
# Anonymous (expect state=login_required when domain matches)
curl -sS "$BASE/api/v1/contrib/secure_publisher_credentials/biblios/BIB/availability?interface=opac" | jq .

# Logged-in patron cookie (expect view_allowed | scope_denied | account_blocked)
curl -sS -b cookies.txt "$BASE/api/v1/contrib/secure_publisher_credentials/biblios/BIB/availability?interface=opac" | jq .

# Staff unchanged
curl -sS -b staff.txt "$BASE/api/v1/contrib/secure_publisher_credentials/biblios/BIB/availability?interface=staff" | jq .
```

Regression: `show` must be `1` only when the patron previously saw **View login info** (`view_allowed`).

## Reversion

No database migrations. Abort = revert git commits or re-upload v1.3.1 `.kpz` from GitHub Releases; restart Plack. See project chat / release notes for phased rollback.
