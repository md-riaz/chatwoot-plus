# Plus Integration User Journeys

This file lists the user-test journeys for features added in the Chatwoot Plus integration. Use it to verify the fork without relying on hidden implementation notes.

## Test environment

- Production URL: `https://cwt.opc.mdriaz.com.bd/`
- Admin user used during deployment verification: `admin@mdriaz.com.bd`
- Browser: Chromium/Playwright or any modern browser
- Required role: account administrator unless noted otherwise

Some journeys require live provider credentials or external webhook payloads. When credentials are missing, verify only the UI surface and configuration flow.

---

## 1. UnoAPI WhatsApp inbox

### Purpose
Create a WhatsApp inbox through UnoAPI instead of the upstream WhatsApp Cloud or Twilio providers.

### Prerequisites
- `UNOAPI_URL` configured.
- One of these configured:
  - `UNOAPI_AUTH_TOKEN`
  - `UNOAPI_API_KEY`
  - inbox-level provider API key
- UnoAPI container/service reachable from Rails.

### Steps
1. Log in as admin.
2. Go to **Settings → Inboxes → Add Inbox**.
3. Select **WhatsApp**.
4. Confirm provider list shows:
   - WhatsApp Cloud
   - Twilio
   - UnoAPI
5. Select **UnoAPI**.
6. Fill UnoAPI credentials/instance fields.
7. Create inbox.
8. Add agents.
9. Finish setup.

### Expected result
- UnoAPI appears as WhatsApp provider option.
- Inbox is created without frontend crash.
- Inbox settings page opens after creation.
- Webhook setup completes if UnoAPI service and credentials are valid.

### Verified in deployment
- Provider list renders.
- UnoAPI option visible.
- Full live UnoAPI account connection not verified because live credentials are required.

---

## 2. WhatsApp group conversations

### Purpose
Handle WhatsApp group messages and expose them in a dedicated **Groups** conversation tab.

### Prerequisites
- A WhatsApp provider that supports group events, normally UnoAPI-compatible provider support.
- A real WhatsApp group message webhook payload.
- Existing inbox connected to the provider.

### Steps
1. Create/connect a WhatsApp/UnoAPI inbox.
2. Send a message from a WhatsApp group to the connected number.
3. Open **Conversations**.
4. Click **Groups** tab.
5. Open the group conversation.
6. Check participants/sender names in messages.
7. Use group controls if available:
   - create group
   - update group
   - add participants
   - remove participants
   - get invite link
   - review join requests

### Expected result
- Group conversation appears under **Groups**.
- Group count updates.
- Sender identity is the real participant, not only the group/inbox number.
- Group participant actions only run when provider supports them.
- Unsupported provider paths fail gracefully.

### Verified in deployment
- **Groups** tab visible in dashboard.
- Group count visible.
- Live group event flow not verified because provider webhook is required.

---

## 3. Preserved deleted messages and outbound delete sync

### Purpose
Preserve deleted inbound message content when configured, and sync agent-side deletes back to WhatsApp/UnoAPI.

### Prerequisites
- WhatsApp/UnoAPI inbox.
- Conversation with provider `source_id` on messages.
- Account setting for preserving deleted content enabled if testing inbound preservation.

### Inbound deleted-message steps
1. Receive a WhatsApp message.
2. Delete the message from WhatsApp sender side.
3. Let deletion webhook reach Chatwoot.
4. Open conversation in Chatwoot.

### Expected inbound result
- Message content is preserved if setting is enabled.
- UI marks message as deleted by sender/preserved.

### Outbound delete sync steps
1. Open a WhatsApp/UnoAPI conversation.
2. Delete an outbound dashboard message.
3. Check provider/device side.

### Expected outbound result
- Message is soft-deleted locally.
- Provider delete call is attempted for WhatsApp/UnoAPI.
- Customer-side message is deleted if provider supports deletion.

### Verified in deployment
- Code path exists and was patched without editing `app/services/whatsapp/providers/whatsapp_cloud_service.rb`.
- Full live delete sync needs real provider conversation.

---

## 4. Facebook/Instagram comments via Omni AI

### Purpose
Forward Facebook/Instagram comments to an Omni AI backend and expose comment management routes/UI.

### Prerequisites
- Facebook/Instagram webhooks configured.
- Omni AI backend URL configured:
  - `OMNI_AI_COMMENTS_URL`
  - fallback: `OMNI_AI_WEBHOOK_URL`
- Auth token/secret configured:
  - `OMNI_AI_COMMENTS_SECRET`
  - fallback: `OMNI_AI_WEBHOOK_TOKEN`
- Meta page/account tokens configured.

### Steps
1. Configure environment variables.
2. Trigger a Facebook or Instagram comment webhook.
3. Confirm comment is forwarded to Omni AI.
4. Open dashboard comments page/sidebar entry if enabled.
5. Load comments by post.
6. Reply publicly from UI.
7. Send private reply/DM where supported.

### Expected result
- Comment webhooks are forwarded with signature/token protection.
- Comments panel loads through proxy controller.
- Manual replies reach Meta Graph API.
- Private replies create/show corresponding Chatwoot data where supported.

### Verified in deployment
- Routes/controllers patched.
- Auth gap fixed for upsert endpoint.
- Full Meta webhook flow needs live Meta app/page credentials.

---

## 5. Meta ad referral cards

### Purpose
Show ad referral data inline in message bubbles for supported Meta channels:

- WhatsApp Click-to-WhatsApp ads
- Facebook Messenger ads
- Instagram ads

### Prerequisites
- WhatsApp payload contains message-level `referral`, or Messenger/Instagram payload contains event-level `referral`.
- Facebook app is subscribed to Messenger webhook fields:
  - `messaging_referrals` for existing threads
  - `messaging_postbacks` for new threads/Get Started flows
- Conversation opened from a WhatsApp, Messenger, or Instagram ad.

### Steps
1. Trigger a WhatsApp CTWA, Messenger ad, or Instagram ad click.
2. Send the first inbound message from the customer, or complete Messenger Get Started if this is a new thread.
3. Open the conversation in Chatwoot.
4. Inspect the first inbound message bubble.

### Expected result
- Inline ad referral card appears when `message.content_attributes.referral` exists.
- Card shows verified Meta keys such as headline/ad title, body/ref, ad id, post id, product id, flow id, and image/video preview when supplied.
- Standard 1-to-1 messages without referral do not show the card.

### Verified in deployment
- Component and i18n present.
- WhatsApp CTWA persistence exists.
- Messenger/Instagram referral persistence added through Plus-owned extension modules.
- Live Meta ad payloads are not Playwright-verified because Meta ad events and provider credentials are required.

---

## 6. Scheduled messages

### Purpose
Let agents schedule outgoing messages through decoupled Plus scheduled-message storage and runner job.

### Prerequisites
- Conversation exists.
- Agent has permission to send messages.
- Sidekiq/cron schedule is running.
- `plus_scheduled_messages` table migrated.

### Steps
1. Open a conversation.
2. Draft outgoing message.
3. Select schedule/date-time option if UI is mounted.
4. Choose future send time.
5. Confirm schedule.
6. Wait for scheduled runner.
7. Re-open conversation after send time.

### Expected result
- Scheduled message row is created with `pending` status.
- Runner sends due message through Chatwoot message builder.
- Status becomes `sent` or `failed`.
- Sent message appears in conversation.

### Verified in deployment
- Table exists.
- Model/job exist.
- Full timed send needs live Sidekiq schedule observation.

---

## 7. Per-inbox message signatures

### Purpose
Append configured inbox signature to outgoing public messages.

### Prerequisites
- Inbox exists.
- Signature configured in inbox settings.

### Steps
1. Go to **Settings → Inboxes**.
2. Open an inbox settings page.
3. Add/edit message signature.
4. Save settings.
5. Open a conversation in that inbox.
6. Send a public outgoing message.

### Expected result
- Outgoing public message includes signature once.
- Private notes are not signed.
- Signature is not appended twice.

### Verified in deployment
- Backend signature appender patched.
- Duplicate signature bug fixed.
- Full UI send needs test conversation/inbox.

---

## 8. Uno premium health check

### Purpose
Keep configured self-hosted premium-related installation configs from resetting.

### Prerequisites
- Sidekiq scheduler active.
- `config/schedule.yml` loaded.

### Steps
1. Check `config/schedule.yml` for premium health job entry.
2. Let scheduled job run or run job manually from Rails console.
3. Inspect installation config values.

### Expected result
- Premium plan config values stay enforced.
- Job runs on configured daily schedule.

### Verified in deployment
- Schedule file includes Plus scheduled jobs and prior health-check planning.
- Full scheduler run not manually verified during UI Playwright pass.

---

## 9. Voice/webphone / SIP calling

### Purpose
Provide browser-based voice calling using custom SIP/WebRTC support, plus upstream-style Twilio/WhatsApp call UI pieces.

### Source evidence
The full SIP/WebRTC implementation includes:

- `app/javascript/dashboard/api/channel/voice/customVoiceClient.js`
- `app/javascript/dashboard/components/widgets/VoiceAutoRegister.vue`
- `app/javascript/dashboard/components/widgets/VoiceAudioPlaybackModal.vue`
- `app/javascript/dashboard/components-next/InternalChat/InternalVoiceCallButton.vue`
- `sip.js` dependency

### How it works
1. Dashboard loads `VoiceAutoRegister`.
2. It finds a voice-capable inbox.
3. It calls voice token endpoint:
   - `GET /api/v1/accounts/:account_id/voice/inboxes/:inbox_id/conference/token`
4. Backend returns provider data and WebRTC config, such as:
   - provider `custom`
   - SIP/WebSocket URL
   - SIP domain
   - username
   - JWT or password credential
   - ICE servers
5. `CustomVoiceClient` creates a SIP.js `UserAgent`.
6. Browser registers to SIP/WebRTC server.
7. Incoming invites dispatch browser events.
8. Floating call widget shows incoming/outgoing/ongoing call controls.
9. Agent can answer, reject, mute, transfer, send DTMF, or end call depending on flow.

### Prerequisites
- Voice-capable inbox configured with provider `custom` or Twilio voice provider.
- SIP/WebRTC server reachable from browser.
- Valid WebSocket SIP URL.
- Valid SIP domain and credentials/token.
- Browser microphone permission granted.
- HTTPS enabled, required for microphone/WebRTC.
- Backend token endpoint returning valid config.

### Custom SIP inbound call steps
1. Configure a custom voice inbox.
2. Log in as assigned agent.
3. Confirm browser asks/has audio permission.
4. Place an inbound SIP call to the registered agent/user.
5. Watch floating call widget.
6. Click answer/join.
7. Speak both ways.
8. End call.

### Expected result
- Browser registers to SIP server.
- Incoming call widget appears.
- Audio connects both ways.
- Call status updates.
- End/reject clears active call state.

### Outbound/internal call steps
1. Open an internal conversation or contact with phone.
2. Click call button.
3. Pick voice inbox/agent if prompted.
4. Confirm call starts.
5. End call.

### Expected result
- Call request creates/joins conference where backend/provider supports it.
- Floating widget displays active call.
- Conversation call status updates.

### Verified in deployment
- Webphone code exists and review issues were cleaned.
- Live call not verified because SIP/Twilio credentials and configured voice inbox are required.

---

## 10. Docker production deployment

### Purpose
Run fork in production with local image, UnoAPI service, Nginx reverse proxy, and TLS.

### Steps
1. Build image from `docker/Dockerfile`.
2. Run migrations/prepare task.
3. Start Rails, Redis, Postgres, UnoAPI containers.
4. Start Nginx reverse proxy.
5. Visit public URL.

### Expected result
- App returns HTTP 200.
- Login page loads.
- Dashboard works after login.
- Inboxes page and WhatsApp/UnoAPI provider page render.

### Verified in deployment
- Live URL works: `https://cwt.opc.mdriaz.com.bd/`
- Rails container running: `cwplus-rails`
- Nginx + TLS active.
- Login verified.
- Key UI surfaces verified by Playwright.

---

## Quick smoke-test checklist

Use this for fast manual verification after deployment.

1. Log in.
2. Open dashboard.
3. Confirm **Groups** tab appears.
4. Open **Settings**.
5. Confirm **Inboxes**, **Audit Logs**, **Custom Roles**, **Conversation Workflow** visible.
6. Go to **Settings → Inboxes → Add Inbox → WhatsApp**.
7. Confirm **UnoAPI** provider appears.
8. Open a conversation if present.
9. Check message composer and call controls/signature/scheduler surfaces where available.
10. Watch browser console for fatal Vue errors.

Known non-blocking item in current self-host deployment:

- `/enterprise/api/v1/accounts/:id/limits` may return 404 in browser console. This is expected for this self-host/non-cloud setup and did not block verified UI surfaces.
