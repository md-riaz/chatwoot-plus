# Chatwoot Plus fork differences

This repository is a fork of upstream Chatwoot with a small set of product extensions and self-hosting changes. The goal is to keep the fork close to upstream while preserving the features listed here.

Last summarized after syncing with upstream `develop` on 2026-06-14.

At the time of this document, this fork is:

```text
upstream/develop...origin/develop: 0 behind, 13 ahead
```

## Maintenance rules for future work

- Keep upstream sync PRs separate from feature PRs.
- Prefer small extension files under `app/services/plus`, route extension files, provider-specific services, or isolated frontend helpers.
- Avoid broad edits to upstream-hot files unless behavior requires it.
- Do not reintroduce Kanban unless explicitly requested; it was intentionally removed.
- New frontend text must include pt-BR translations.
- If changing backend behavior, check frontend impact. If changing frontend behavior, check backend/API impact.

## Major fork additions

### 1. Custom SIP/WebRTC voice channel

Adds a custom SIP voice provider alongside existing voice infrastructure.

Main capabilities:

- Custom SIP/WebRTC browser calling.
- SIP over WSS with username/password credentials.
- Inbound and outbound custom SIP calls.
- Browser-side custom SIP recording using `MediaRecorder`.
- Uploads custom SIP recordings as audio attachments on the existing voice-call message.
- Persistent SIP registration between calls.
- Floating incoming-call UI for custom voice calls.
- Conversation reuse support for locked voice inboxes.

Representative files:

```text
enterprise/app/models/channel/voice.rb
enterprise/app/services/voice/provider/custom/adapter.rb
enterprise/app/services/voice/provider/custom/session_service.rb
enterprise/app/services/voice/provider/custom/token_service.rb
enterprise/app/services/voice/provider/custom/transfer_service.rb
enterprise/app/services/voice/outbound_call_builder.rb
enterprise/app/services/voice/inbound_call_builder.rb
enterprise/app/controllers/api/v1/accounts/conference_controller.rb
app/javascript/dashboard/api/channel/voice/customVoiceClient.js
app/javascript/dashboard/api/channel/voice/voiceAPIClient.js
app/javascript/dashboard/composables/useCallSession.js
app/javascript/dashboard/components/widgets/VoiceAutoRegister.vue
app/javascript/dashboard/components/widgets/VoiceDialerFab.vue
app/javascript/dashboard/components-next/call/FloatingCallWidget.vue
app/javascript/dashboard/components-next/message/bubbles/VoiceCall.vue
```

Important design decision:

- Custom SIP recordings do not use `Call#recording`.
- They follow the WhatsApp-style browser upload pattern and attach audio to the voice-call message.

### 2. WhatsApp provider extensions: UnoAPI, Baileys, Z-API, NotificaMe

Adds non-upstream WhatsApp provider integrations and settings screens.

Main capabilities:

- UnoAPI provider support.
- Baileys provider support.
- Z-API provider support.
- NotificaMe channel UI/API additions.
- Provider-specific webhook handling.
- Provider connection status and QR helpers.
- UnoAPI production compose/service support.

Representative files:

```text
app/services/whatsapp/providers/unoapi_service.rb
app/services/whatsapp/providers/whatsapp_baileys_service.rb
app/services/whatsapp/providers/whatsapp_zapi_service.rb
app/services/whatsapp/incoming_message_unoapi_service.rb
app/services/whatsapp/incoming_message_baileys_service.rb
app/services/whatsapp/incoming_message_zapi_service.rb
app/jobs/channels/whatsapp/baileys_connection_check_job.rb
app/jobs/channels/whatsapp/zapi_qr_code_job.rb
app/javascript/dashboard/routes/dashboard/settings/inbox/channels/Unoapi.vue
app/javascript/dashboard/routes/dashboard/settings/inbox/channels/BaileysWhatsapp.vue
app/javascript/dashboard/routes/dashboard/settings/inbox/channels/ZapiWhatsapp.vue
app/javascript/dashboard/routes/dashboard/settings/inbox/channels/NotificaMe.vue
deployment/unoapi.service
docker-compose.production.yaml
docker-compose.yaml
```

### 3. WhatsApp group conversation support

Adds group conversation handling for WhatsApp-style providers.

Main capabilities:

- Group-aware conversation creation.
- Group members and group contacts.
- Group metadata, invite links, join requests, admin/member actions.
- Group participant sync jobs and services.
- Group UI elements in conversation view and contact panel.
- Groups tab/filter in chat list.

Representative files:

```text
app/models/group_member.rb
app/models/group_contact.rb
app/models/concerns/group_conversation_handler.rb
app/services/whatsapp/group_payload_normalizer.rb
app/services/whatsapp/group_conversation_backfill_service.rb
app/services/whatsapp/group_conversation_schema_migration_service.rb
app/services/whatsapp/unoapi/group_participants_sync_service.rb
app/controllers/api/v1/accounts/conversations/groups_controller.rb
app/controllers/api/v1/accounts/conversations/group_contacts_controller.rb
app/controllers/api/v1/accounts/conversations/group_invite_link_controller.rb
app/controllers/api/v1/accounts/conversations/group_join_requests_controller.rb
app/javascript/dashboard/store/modules/groupMembers.js
app/javascript/dashboard/components/widgets/conversation/TagGroupContacts.vue
app/javascript/dashboard/components/widgets/conversation/TagGroupMembers.vue
app/javascript/dashboard/routes/dashboard/conversation/GroupMembersModal.vue
app/javascript/dashboard/routes/dashboard/conversation/GroupContacts.vue
app/javascript/dashboard/i18n/locale/en/groups.json
app/javascript/dashboard/i18n/locale/pt_BR/groups.json
```

### 4. Scheduled and recurring messages

Adds message scheduling and recurrence support.

Main capabilities:

- Schedule a conversation message for later.
- Recurring scheduled messages.
- Background jobs to trigger and send scheduled messages.
- Frontend modal/list/sidebar display.
- API docs/spec coverage.

Representative files:

```text
app/models/scheduled_message.rb
app/models/recurring_scheduled_message.rb
app/models/concerns/scheduled_message_handler.rb
app/controllers/api/v1/accounts/conversations/scheduled_messages_controller.rb
app/controllers/api/v1/accounts/conversations/recurring_scheduled_messages_controller.rb
app/jobs/scheduled_messages/trigger_scheduled_messages_job.rb
app/jobs/scheduled_messages/send_scheduled_message_job.rb
app/services/recurring_scheduled_messages/recurrence_calculator_service.rb
app/javascript/dashboard/api/scheduledMessages.js
app/javascript/dashboard/api/recurringScheduledMessages.js
app/javascript/dashboard/store/modules/scheduledMessages.js
app/javascript/dashboard/store/modules/recurringScheduledMessages.js
app/javascript/dashboard/routes/dashboard/conversation/scheduledMessages/ScheduledMessages.vue
app/javascript/dashboard/routes/dashboard/conversation/scheduledMessages/ScheduledMessageModal.vue
```

### 5. Internal chat via normal Chatwoot conversations

Adds a lightweight internal chat inbox/channel type using existing Chatwoot conversations, not the large Slack-style `InternalChat::*` system from another fork.

Main capabilities:

- `Channel::Internal` inbox type.
- Internal conversations between agents.
- Internal conversation creation API.
- Sidebar compose button for internal chats when an internal inbox exists.
- Internal chat filter support in conversations.

Representative files:

```text
app/models/channel/internal.rb
app/controllers/api/v1/accounts/internal_conversations_controller.rb
app/views/api/v1/accounts/internal_conversations/create.json.jbuilder
app/views/api/v1/accounts/internal_conversations/index.json.jbuilder
app/javascript/dashboard/api/internalConversations.js
app/javascript/dashboard/components-next/InternalChat/ComposeInternalChat.vue
app/javascript/dashboard/components-next/sidebar/Sidebar.vue
app/javascript/dashboard/routes/dashboard/settings/inbox/channels/Internal.vue
app/javascript/dashboard/store/modules/conversations/helpers.js
```

Source lineage note:

- The lightweight flow traces to Viper/Uno fork commits such as `b30fed1147 feat: add internal chat inbox and UI flow`.
- This fork does not use the full Fazer-AI Slack/Discord-style internal chat implementation with separate `InternalChat::*` models, channels, reactions, polls, and drafts.

### 6. OmniAI / comment management integrations

Adds comment forwarding and dashboard UI for social comments.

Main capabilities:

- Facebook/Instagram comment webhook forwarding.
- OmniAI comment dashboard route.
- Comment reply and private reply proxy controllers.
- Middleware for Facebook comment webhook interception.

Representative files:

```text
app/middleware/omni_ai/facebook_comment_middleware.rb
app/controllers/omni_ai/comments_proxy_controller.rb
app/controllers/omni_ai/comment_replies_controller.rb
app/controllers/omni_ai/private_replies_controller.rb
app/controllers/api/v1/accounts/comment_posts_controller.rb
app/jobs/omni_ai/comment_forward_job.rb
app/javascript/dashboard/routes/dashboard/omniComments/pages/OmniCommentsIndex.vue
app/javascript/dashboard/routes/dashboard/omniComments/routes.js
config/initializers/omni_ai_middleware.rb
config/routes/plus_omni_ai_routes.rb
config/routes/plus_omni_ai_webhook_routes.rb
```

### 7. Meta ad referral capture and display

Adds capture and UI rendering for Click-to-WhatsApp ad referral data.

Representative files:

```text
app/services/plus/meta_ad_referral_attributes.rb
app/services/plus/meta_ad_referral_extensions.rb
app/javascript/dashboard/components-next/message/AdReferralCard.vue
app/javascript/dashboard/components-next/message/bubbles/Base.vue
config/initializers/plus_meta_ad_referrals.rb
```

### 8. Scoped agent display names

Adds per-inbox/account scoped display names for agents.

Representative files:

```text
app/controllers/api/v1/accounts/plus/scoped_agent_display_names_controller.rb
app/services/plus/scoped_agent_display_name_resolver.rb
app/services/plus/scoped_agent_display_name_extensions.rb
app/javascript/dashboard/api/scopedAgentDisplayNames.js
app/javascript/dashboard/routes/dashboard/settings/scopedAgentDisplayNames/Index.vue
app/javascript/dashboard/routes/dashboard/settings/scopedAgentDisplayNames/scopedAgentDisplayName.routes.js
app/javascript/dashboard/i18n/locale/en/scopedAgentDisplayNames.json
app/javascript/dashboard/i18n/locale/pt_BR/scopedAgentDisplayNames.json
config/initializers/plus_scoped_agent_display_names.rb
```

### 9. Inbox signatures

Adds per-inbox signature support for outgoing messages.

Representative files:

```text
app/models/inbox_signature.rb
app/controllers/api/v1/profile/inbox_signatures_controller.rb
app/services/plus/message_signature_appender.rb
app/javascript/dashboard/api/inboxSignatures.js
app/javascript/dashboard/composables/useInboxSignatures.js
app/javascript/dashboard/routes/dashboard/settings/inbox/settingsPage/components/InboxSignatureSettings.vue
```

### 10. Deleted-message preservation setting

Adds account setting and UI for preserving deleted message content.

Representative files:

```text
app/models/concerns/account_settings_schema.rb
app/javascript/dashboard/routes/dashboard/settings/account/components/DeletedMessageContent.vue
app/javascript/dashboard/components-next/message/bubbles/Text/Index.vue
```

### 11. Conversation and message utility additions

Adds UI/API helpers for message forwarding, contact attachment, media library, message attachment updates, link previews, templates, stickers, and plus-specific reply-box actions.

Representative files:

```text
app/controllers/api/v1/accounts/conversations/attachments_controller.rb
app/javascript/dashboard/components/widgets/conversation/ForwardMessagesModal.vue
app/javascript/dashboard/components/widgets/conversation/ForwardSelectionToolbar.vue
app/javascript/dashboard/components/widgets/conversation/MediaLibraryModal.vue
app/javascript/dashboard/components-next/Conversation/ContactAttachmentModal.vue
app/javascript/dashboard/components-next/Conversation/AttachedContactsPreview.vue
app/javascript/dashboard/components-next/message/bubbles/Text/LinkPreviewCard.vue
app/javascript/dashboard/components-next/whatsapp/StickerPickerDialog.vue
app/javascript/dashboard/components/widgets/conversation/mixins/replyBoxPlusActions.js
app/javascript/dashboard/components/widgets/conversation/mixins/messagesForwarding.js
```

### 12. Self-hosting, branding, and deployment helpers

Adds self-hosted deployment conveniences and generic branding helpers.

Representative files:

```text
CUSTOM_BRANDING.md
.github/copilot-instructions.md
.github/workflows/publish_github_docker.yml
.github/workflows/publish_ee_github_docker.yml
docker-compose.coolify.yaml
deployment/extract_brand_assets.sh
lib/tasks/branding.rake
lib/middleware/plus_platform_header.rb
```

### 13. Reporting/dashboard additions

Adds/overrides reporting builders and dashboard app support.

Representative files:

```text
app/builders/v2/reports/timeseries/average_report_builder.rb
app/builders/v2/reports/timeseries/count_report_builder.rb
app/javascript/dashboard/routes/dashboard/dashboardApps/DashboardAppView.vue
app/javascript/dashboard/routes/dashboard/dashboardApps/dashboardApps.routes.js
```

## Conflict-reduction refactors already applied

These refactors exist to reduce future upstream merge conflicts without changing behavior.

### ReplyBox audio format helper

Moved channel-specific audio recording format selection out of `ReplyBox.vue`.

```text
app/javascript/dashboard/helper/audioRecordFormat.js
app/javascript/dashboard/helper/specs/audioRecordFormat.spec.js
```

Current behavior:

```text
WhatsApp Cloud -> OGG
WhatsApp / Telegram / NotificaMe / API inbox -> MP3
Other channels -> WAV
```

### ConversationFinder Plus extension

Moved fork-specific group/internal conversation finder behavior into a small extension module.

```text
app/services/plus/conversation_finder_extension.rb
spec/services/plus/conversation_finder_extension_spec.rb
```

Preserves:

```text
group_count
groups assignee filter
internal conversation type filter
non-group unassigned counts
```

## Explicitly removed / not present

### Kanban

Kanban was intentionally removed as unusable/incomplete. Do not reintroduce it unless explicitly requested and implemented as a usable feature.

No references should remain under:

```text
app
enterprise
config
spec
db
```

### Full Fazer-AI InternalChat system

This fork does not include the full Fazer-AI `InternalChat::*` Slack-style application. It uses the lighter `Channel::Internal` normal-conversation approach instead.

## High-risk upstream-hot files

These files often conflict with upstream and should be edited carefully:

```text
app/finders/conversation_finder.rb
app/javascript/dashboard/components/widgets/conversation/ReplyBox.vue
app/javascript/dashboard/components-next/sidebar/Sidebar.vue
app/javascript/dashboard/store/index.js
app/models/user.rb
app/models/account.rb
app/models/channel/whatsapp.rb
app/services/whatsapp/*
config/routes.rb
db/schema.rb
package.json
pnpm-lock.yaml
```

Prefer adding small extension modules instead of expanding these files directly.

## Validation notes

GitHub Actions failures previously observed on this fork were account/actions plumbing failures, not proven code failures. Evidence included failed jobs with no runner, no steps, no logs, and `BlobNotFound` log retrieval errors.

Local backend RSpec may require installing missing bundle executables first. Previous local blocker:

```text
bundler: command not found: rspec
```

Known untracked local-only files that should not be committed:

```text
.lean-ctx/
inbound_dry_run.rb
```
