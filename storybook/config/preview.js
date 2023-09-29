// Some modules read window.gon on initialization thus we need to define this object before anything else
import './gon';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import translateMixin from '~/vue_shared/translate';
import { initializeGitLabAPIAccess } from './addons/gitlab_api_access/preview';

const stylesheetsRequireCtx = require.context(
  '../../app/assets/stylesheets',
  true,
  /(application|application_utilities|highlight\/themes\/white)\.scss$/,
);

initializeGitLabAPIAccess();

translateMixin(Vue);
Vue.use(VueApollo);

stylesheetsRequireCtx('./application.scss');
stylesheetsRequireCtx('./application_utilities.scss');
stylesheetsRequireCtx('./highlight/themes/white.scss');
