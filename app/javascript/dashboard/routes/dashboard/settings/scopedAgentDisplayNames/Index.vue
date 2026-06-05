<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import ScopedAgentDisplayNamesAPI from 'dashboard/api/scopedAgentDisplayNames';

const { t } = useI18n();
const store = useStore();
const getters = useStoreGetters();

const selectedInboxId = ref('');
const accountDisplayNames = reactive({});
const inboxDisplayNames = reactive({});
const savingAccountAliases = reactive({});
const savingInboxAliases = reactive({});
const isFetching = ref(false);

const agents = computed(() => getters['agents/getAgents'].value || []);
const inboxes = computed(() => getters['inboxes/getInboxes'].value || []);
const selectedInboxName = computed(() => {
  const inbox = inboxes.value.find(
    item => item.id === Number(selectedInboxId.value)
  );
  return inbox?.name || '';
});

const resetRecord = (target, values = {}) => {
  Object.keys(target).forEach(key => delete target[key]);
  Object.entries(values).forEach(([key, value]) => {
    target[key] = value || '';
  });
};

const fetchScopedDisplayNames = async () => {
  isFetching.value = true;
  try {
    const response = await ScopedAgentDisplayNamesAPI.list({
      inboxId: selectedInboxId.value || undefined,
    });
    resetRecord(accountDisplayNames, response.data.account_display_names);
    resetRecord(inboxDisplayNames, response.data.inbox_display_names);
  } catch (error) {
    useAlert(t('SCOPED_AGENT_DISPLAY_NAMES.API.ERROR_MESSAGE'));
  } finally {
    isFetching.value = false;
  }
};

const saveAccountDisplayName = async agent => {
  savingAccountAliases[agent.id] = true;
  try {
    const response = await ScopedAgentDisplayNamesAPI.updateAccount({
      userId: agent.id,
      displayName: accountDisplayNames[agent.id] || '',
      inboxId: selectedInboxId.value || undefined,
    });
    resetRecord(accountDisplayNames, response.data.account_display_names);
    resetRecord(inboxDisplayNames, response.data.inbox_display_names);
    useAlert(t('SCOPED_AGENT_DISPLAY_NAMES.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('SCOPED_AGENT_DISPLAY_NAMES.API.ERROR_MESSAGE'));
  } finally {
    savingAccountAliases[agent.id] = false;
  }
};

const saveInboxDisplayName = async agent => {
  if (!selectedInboxId.value) return;

  savingInboxAliases[agent.id] = true;
  try {
    const response = await ScopedAgentDisplayNamesAPI.updateInbox({
      inboxId: selectedInboxId.value,
      userId: agent.id,
      displayName: inboxDisplayNames[agent.id] || '',
    });
    resetRecord(accountDisplayNames, response.data.account_display_names);
    resetRecord(inboxDisplayNames, response.data.inbox_display_names);
    useAlert(t('SCOPED_AGENT_DISPLAY_NAMES.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(t('SCOPED_AGENT_DISPLAY_NAMES.API.ERROR_MESSAGE'));
  } finally {
    savingInboxAliases[agent.id] = false;
  }
};

onMounted(async () => {
  await Promise.all([
    store.dispatch('agents/get'),
    store.dispatch('inboxes/get'),
  ]);
  await fetchScopedDisplayNames();
});
</script>

<template>
  <SettingsLayout
    :is-loading="isFetching"
    :loading-message="t('SCOPED_AGENT_DISPLAY_NAMES.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('SCOPED_AGENT_DISPLAY_NAMES.HEADER')"
        :description="t('SCOPED_AGENT_DISPLAY_NAMES.DESCRIPTION')"
      />
    </template>

    <template #body>
      <div class="flex flex-col gap-6 w-full">
        <section
          class="flex flex-col gap-3 rounded-xl border border-n-weak p-4"
        >
          <div>
            <h2 class="text-heading-3 text-n-slate-12">
              {{ t('SCOPED_AGENT_DISPLAY_NAMES.ACCOUNT_SECTION.TITLE') }}
            </h2>
            <p class="text-body-main text-n-slate-11">
              {{ t('SCOPED_AGENT_DISPLAY_NAMES.ACCOUNT_SECTION.DESCRIPTION') }}
            </p>
          </div>

          <div
            v-for="agent in agents"
            :key="agent.id"
            class="grid gap-3 md:grid-cols-[1fr_1fr_auto] md:items-end"
          >
            <div class="min-w-0">
              <p class="mb-0 text-heading-3 text-n-slate-12 truncate">
                {{ agent.name }}
              </p>
              <p class="mb-0 text-body-main text-n-slate-11 truncate">
                {{ agent.email }}
              </p>
            </div>
            <Input
              v-model="accountDisplayNames[agent.id]"
              :label="
                t('SCOPED_AGENT_DISPLAY_NAMES.ACCOUNT_SECTION.FIELD_LABEL')
              "
              :placeholder="agent.available_name || agent.name"
            />
            <Button
              :label="t('SCOPED_AGENT_DISPLAY_NAMES.SAVE')"
              size="sm"
              :is-loading="savingAccountAliases[agent.id]"
              @click="saveAccountDisplayName(agent)"
            />
          </div>
        </section>

        <section
          class="flex flex-col gap-3 rounded-xl border border-n-weak p-4"
        >
          <div>
            <h2 class="text-heading-3 text-n-slate-12">
              {{ t('SCOPED_AGENT_DISPLAY_NAMES.INBOX_SECTION.TITLE') }}
            </h2>
            <p class="text-body-main text-n-slate-11">
              {{ t('SCOPED_AGENT_DISPLAY_NAMES.INBOX_SECTION.DESCRIPTION') }}
            </p>
          </div>

          <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
            {{ t('SCOPED_AGENT_DISPLAY_NAMES.INBOX_SECTION.SELECT_LABEL') }}
            <select
              v-model="selectedInboxId"
              class="!mb-0"
              @change="fetchScopedDisplayNames"
            >
              <option value="">
                {{
                  t(
                    'SCOPED_AGENT_DISPLAY_NAMES.INBOX_SECTION.SELECT_PLACEHOLDER'
                  )
                }}
              </option>
              <option
                v-for="inbox in inboxes"
                :key="inbox.id"
                :value="inbox.id"
              >
                {{ inbox.name }}
              </option>
            </select>
          </label>

          <div v-if="selectedInboxId" class="flex flex-col gap-3">
            <div
              v-for="agent in agents"
              :key="agent.id"
              class="grid gap-3 md:grid-cols-[1fr_1fr_auto] md:items-end"
            >
              <div class="min-w-0">
                <p class="mb-0 text-heading-3 text-n-slate-12 truncate">
                  {{ agent.name }}
                </p>
                <p class="mb-0 text-body-main text-n-slate-11 truncate">
                  {{ selectedInboxName }}
                </p>
              </div>
              <Input
                v-model="inboxDisplayNames[agent.id]"
                :label="
                  t('SCOPED_AGENT_DISPLAY_NAMES.INBOX_SECTION.FIELD_LABEL')
                "
                :placeholder="
                  accountDisplayNames[agent.id] ||
                  agent.available_name ||
                  agent.name
                "
              />
              <Button
                :label="t('SCOPED_AGENT_DISPLAY_NAMES.SAVE')"
                size="sm"
                :is-loading="savingInboxAliases[agent.id]"
                @click="saveInboxDisplayName(agent)"
              />
            </div>
          </div>
        </section>
      </div>
    </template>
  </SettingsLayout>
</template>
