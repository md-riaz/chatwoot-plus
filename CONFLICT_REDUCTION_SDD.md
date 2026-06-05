# Conflict Reduction SDD

## Goal
Reduce future upstream Chatwoot merge conflicts while preserving Plus functionality already integrated in this branch.

## Evidence
Current branch compared with `origin/develop` after conflict-reduction commits:

- 523 changed files
- 95 modified existing files
- 427 added files
- Highest risk areas remaining: dependency locks, schema, `ConfigurationPage.vue`, `ReplyBox.vue`, `MessagesView.vue`, conversation store mutations, core models, Docker/build files.
Reduced high-risk files:
- `app/services/whatsapp/providers/whatsapp_cloud_service.rb`: +1/-0
- `app/services/whatsapp/incoming_message_base_service.rb`: +2/-0
- `config/routes.rb`: +7/-0
- `app/javascript/dashboard/store/modules/conversations/actions.js`: +36/-41

Fork pattern comparison checked against freshly fetched probe branches:

- `probe/omnisett-develop`: 46 changed files, 28 modified, 18 added. Best pattern: additive `omni_ai` namespace, initializers, small route/controller hooks.
- `probe/clairton-uno`: 180 changed files, 121 modified, 58 added. Mixed pattern: good additive provider files, but high-risk shared UI/store/provider changes.
- `probe/vipertec-4.13.0`: 4241 changed files, 3463 modified, 687 added. Worst pattern: product fork with broad upstream overwrites.
- Current branch moved toward the Omnisett pattern for the highest-risk hotspots by using Plus-owned services, child components, action modules, and route draw files.

## Design Principles
1. Preserve all current Plus features.
2. Do not remove product behavior to reduce diffs.
3. Prefer new Plus-owned files over editing upstream files.
4. Leave only small stable hook points in upstream files.
5. Do not rewrite large dense flows without targeted verification.
6. Split work into safe phases.

## Phase A: Low-risk conflict reduction now

### A1. Inbox configuration page extraction
Problem: `ConfigurationPage.vue` has large fork-owned settings logic mixed into upstream page.

Plan:
- Extract inbox signature settings into a child component.
- Extract web widget extra settings into a child component.
- Keep parent as routing/orchestration shell.

Expected result:
- Less Plus-specific script/template code in `ConfigurationPage.vue`.
- Same UI and store payload behavior.

Files:
- `app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/ConfigurationPage.vue`
- new `app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/components/InboxSignatureSettings.vue`
- new `app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/components/WebWidgetConfigurationExtras.vue`

### A2. Plus route modularization
Problem: `config/routes.rb` has many Plus route additions.

Plan:
- Move Plus route groups into route draw files where feasible.
- Keep only stable draw hooks in `config/routes.rb`.

Expected result:
- Future upstream changes to main route file conflict less.

Files:
- `config/routes.rb`
- new `config/routes/plus_*.rb`

### A3. Keep Meta referral extension pattern
Already good: `Plus::MetaAdReferralExtensions` uses initializer/prepend. Keep as model pattern.

## Phase B: Higher-risk extraction later

### B1. WhatsApp Cloud provider extraction
Problem: `app/services/whatsapp/providers/whatsapp_cloud_service.rb` is high-risk and user-sensitive.

Plan:
- Extract provider additions into `app/services/plus/whatsapp/*` extension modules.
- Keep only existing module prepend/hook where possible.
- Do not change until method-by-method behavior is test-covered.

### B2. Incoming message base extraction
Problem: `app/services/whatsapp/incoming_message_base_service.rb` is a major upstream hotspot.

Plan:
- Extract edit handling, contact identity helpers, contact sync command, deleted-content policy into Plus modules.
- Keep processing-order hooks only.

### B3. ReplyBox extraction
Problem: `ReplyBox.vue` carries group mentions, scheduled messages, contacts, signatures, audio changes in one upstream component.

Plan:
- Extract group mentions composable first.
- Extract scheduled-message modal state second.
- Extract payload construction only after tests pass.

## Completed extended refactors

After Phase A, the high-risk Phase B items were reduced using the same small-hook pattern:

- `app/services/whatsapp/providers/whatsapp_cloud_service.rb` now keeps only a one-line `Plus::WhatsappCloudProviderExtension` prepend hook versus `origin/develop`; custom provider behavior lives in `app/services/plus/whatsapp_cloud_provider_extension.rb`.
- `app/services/whatsapp/incoming_message_base_service.rb` now keeps only a one-line `Plus::WhatsappIncomingMessageExtension` prepend hook plus load line versus `origin/develop`; custom incoming behavior lives in `app/services/plus/whatsapp_incoming_message_extension.rb`.
- `ReplyBox.vue` moved group mentions and Plus actions into `replyBoxGroupMentions.js` and `replyBoxPlusActions.js`.
- `MessagesView.vue` moved forward-selection behavior into `messagesForwarding.js` and `ForwardSelectionToolbar.vue`.
- Conversation attachment actions moved into `actions/attachmentActions.js`.

Remaining larger hotspots are broader branch features not safely removable without changing product behavior or running unavailable full CI/provider tests: conversation store mutations, core model changes, dependency locks, Docker/build files, and shared conversation UI shell hooks. Further reduction should be done feature-by-feature only when tests or live credentials prove behavior preservation.

## Acceptance
Phase A is complete when:

- UI behavior preserved for inbox settings.
- JSON/i18n parse unaffected.
- Targeted ESLint has no errors for touched Vue files.
- `git diff --check` clean except known CRLF warnings.
- Commit pushed.

Final audit reports:

- Remaining modified existing file count.
- Remaining highest-risk conflict files.
- Whether PR merge posture changed.
