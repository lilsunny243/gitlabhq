import { GlToast } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import JobApp from './job_app.vue';
import createStore from './store';

Vue.use(VueApollo);
Vue.use(GlToast);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(),
});

const initializeJobPage = (element) => {
  const store = createStore();

  // Let's start initializing the store (i.e. fetching data) right away
  store.dispatch('init', element.dataset);

  const {
    artifactHelpUrl,
    deploymentHelpUrl,
    runnerSettingsUrl,
    subscriptionsMoreMinutesUrl,
    endpoint,
    pagePath,
    logState,
    buildStatus,
    projectPath,
    retryOutdatedJobDocsUrl,
    aiRootCauseAnalysisAvailable,
  } = element.dataset;

  return new Vue({
    el: element,
    apolloProvider,
    store,
    components: {
      JobApp,
    },
    provide: {
      projectPath,
      retryOutdatedJobDocsUrl,
      aiRootCauseAnalysisAvailable: parseBoolean(aiRootCauseAnalysisAvailable),
    },
    render(createElement) {
      return createElement('job-app', {
        props: {
          artifactHelpUrl,
          deploymentHelpUrl,
          runnerSettingsUrl,
          subscriptionsMoreMinutesUrl,
          endpoint,
          pagePath,
          logState,
          buildStatus,
          projectPath,
        },
      });
    },
  });
};

export default () => {
  const jobElement = document.getElementById('js-job-page');
  initializeJobPage(jobElement);
};
