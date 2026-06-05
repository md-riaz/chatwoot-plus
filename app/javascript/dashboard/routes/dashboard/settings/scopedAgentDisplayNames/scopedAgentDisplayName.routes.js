import { FEATURE_FLAGS } from '../../../../featureFlags';
import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import ScopedAgentDisplayNames from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL(
        'accounts/:accountId/settings/scoped-agent-display-names'
      ),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'scoped_agent_display_names',
          component: ScopedAgentDisplayNames,
          meta: {
            featureFlag: FEATURE_FLAGS.SCOPED_AGENT_DISPLAY_NAME,
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
