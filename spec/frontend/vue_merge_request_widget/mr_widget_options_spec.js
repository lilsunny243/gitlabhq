import { GlBadge, GlLink, GlIcon, GlButton, GlDropdown } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createMockSubscription as createMockApolloSubscription } from 'mock-apollo-client';
import * as Sentry from '@sentry/browser';
import approvedByCurrentUser from 'test_fixtures/graphql/merge_requests/approvals/approvals.query.graphql.json';
import getStateQueryResponse from 'test_fixtures/graphql/merge_requests/get_state.query.graphql.json';
import readyToMergeResponse from 'test_fixtures/graphql/merge_requests/states/ready_to_merge.query.graphql.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import api from '~/api';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_OK, HTTP_STATUS_NO_CONTENT } from '~/lib/utils/http_status';
import Poll from '~/lib/utils/poll';
import { setFaviconOverlay } from '~/lib/utils/favicon';
import notify from '~/lib/utils/notify';
import SmartInterval from '~/smart_interval';
import {
  registerExtension,
  registeredExtensions,
} from '~/vue_merge_request_widget/components/extensions';
import { STATUS_CLOSED, STATUS_OPEN, STATUS_MERGED } from '~/issues/constants';
import { STATE_QUERY_POLLING_INTERVAL_BACKOFF } from '~/vue_merge_request_widget/constants';
import { SUCCESS } from '~/vue_merge_request_widget/components/deployment/constants';
import eventHub from '~/vue_merge_request_widget/event_hub';
import MrWidgetOptions from '~/vue_merge_request_widget/mr_widget_options.vue';
import Approvals from '~/vue_merge_request_widget/components/approvals/approvals.vue';
import ConflictsState from '~/vue_merge_request_widget/components/states/mr_widget_conflicts.vue';
import Preparing from '~/vue_merge_request_widget/components/states/mr_widget_preparing.vue';
import ShaMismatch from '~/vue_merge_request_widget/components/states/sha_mismatch.vue';
import MergedState from '~/vue_merge_request_widget/components/states/mr_widget_merged.vue';
import WidgetContainer from '~/vue_merge_request_widget/components/widget/app.vue';
import WidgetSuggestPipeline from '~/vue_merge_request_widget/components/mr_widget_suggest_pipeline.vue';
import MrWidgetAlertMessage from '~/vue_merge_request_widget/components/mr_widget_alert_message.vue';
import StatusIcon from '~/vue_merge_request_widget/components/extensions/status_icon.vue';
import getStateQuery from '~/vue_merge_request_widget/queries/get_state.query.graphql';
import getStateSubscription from '~/vue_merge_request_widget/queries/get_state.subscription.graphql';
import readyToMergeSubscription from '~/vue_merge_request_widget/queries/states/ready_to_merge.subscription.graphql';
import readyToMergeQuery from 'ee_else_ce/vue_merge_request_widget/queries/states/ready_to_merge.query.graphql';
import approvalsQuery from 'ee_else_ce/vue_merge_request_widget/components/approvals/queries/approvals.query.graphql';
import approvedBySubscription from 'ee_else_ce/vue_merge_request_widget/components/approvals/queries/approvals.subscription.graphql';
import userPermissionsQuery from '~/vue_merge_request_widget/queries/permissions.query.graphql';
import conflictsStateQuery from '~/vue_merge_request_widget/queries/states/conflicts.query.graphql';
import { faviconDataUrl, overlayDataUrl } from '../lib/utils/mock_data';
import mockData, { mockDeployment, mockMergePipeline, mockPostMergeDeployments } from './mock_data';
import {
  workingExtension,
  collapsedDataErrorExtension,
  fullDataErrorExtension,
  fullReportExtension,
  noTelemetryExtension,
  pollingExtension,
  pollingFullDataExtension,
  pollingErrorExtension,
  multiPollingExtension,
} from './test_extensions';

jest.mock('~/api.js');

jest.mock('~/smart_interval');

jest.mock('~/lib/utils/favicon');

jest.mock('@sentry/browser', () => ({
  ...jest.requireActual('@sentry/browser'),
  captureException: jest.fn(),
}));

Vue.use(VueApollo);

describe('MrWidgetOptions', () => {
  let stateQueryHandler;
  let queryResponse;
  let wrapper;
  let mock;
  let stateSubscription;

  const COLLABORATION_MESSAGE = 'Members who can merge are allowed to add commits';

  const createComponent = ({
    updatedMrData = {},
    options = {},
    data = {},
    mountFn = shallowMountExtended,
  } = {}) => {
    gl.mrWidgetData = { ...mockData, ...updatedMrData };
    const mrData = { ...mockData, ...updatedMrData };
    const mockedApprovalsSubscription = createMockApolloSubscription();
    queryResponse = {
      data: {
        project: {
          ...getStateQueryResponse.data.project,
          mergeRequest: {
            ...getStateQueryResponse.data.project.mergeRequest,
            mergeError: mrData.mergeError || null,
            detailedMergeStatus:
              mrData.detailedMergeStatus ||
              getStateQueryResponse.data.project.mergeRequest.detailedMergeStatus,
          },
        },
      },
    };
    stateQueryHandler = jest.fn().mockResolvedValue(queryResponse);
    stateSubscription = createMockApolloSubscription();

    const queryHandlers = [
      [approvalsQuery, jest.fn().mockResolvedValue(approvedByCurrentUser)],
      [getStateQuery, stateQueryHandler],
      [readyToMergeQuery, jest.fn().mockResolvedValue(readyToMergeResponse)],
      [
        userPermissionsQuery,
        jest.fn().mockResolvedValue({
          data: { project: { mergeRequest: { userPermissions: {} } } },
        }),
      ],
      [
        conflictsStateQuery,
        jest.fn().mockResolvedValue({ data: { project: { mergeRequest: {} } } }),
      ],
      ...(options.apolloMock || []),
    ];
    const subscriptionHandlers = [
      [approvedBySubscription, () => mockedApprovalsSubscription],
      [getStateSubscription, () => stateSubscription],
      [readyToMergeSubscription, () => createMockApolloSubscription()],
      ...(options.apolloSubscriptions || []),
    ];
    const apolloProvider = createMockApollo(queryHandlers);

    subscriptionHandlers.forEach(([query, stream]) => {
      apolloProvider.defaultClient.setRequestHandler(query, stream);
    });

    wrapper = mountFn(MrWidgetOptions, {
      propsData: { mrData },
      data() {
        return {
          loading: false,
          ...data,
        };
      },

      ...options,
      apolloProvider,
    });

    return axios.waitForAll();
  };

  const findApprovalsWidget = () => wrapper.findComponent(Approvals);
  const findPreparingWidget = () => wrapper.findComponent(Preparing);
  const findMergedPipelineContainer = () => wrapper.findByTestId('merged-pipeline-container');
  const findPipelineContainer = () => wrapper.findByTestId('pipeline-container');
  const findAlertMessage = () => wrapper.findComponent(MrWidgetAlertMessage);
  const findMergePipelineForkAlert = () => wrapper.findByTestId('merge-pipeline-fork-warning');
  const findExtensionToggleButton = () =>
    wrapper.find('[data-testid="widget-extension"] [data-testid="toggle-button"]');
  const findExtensionLink = (linkHref) =>
    wrapper.find(`[data-testid="widget-extension"] [href="${linkHref}"]`);
  const findSuggestPipeline = () => wrapper.findComponent(WidgetSuggestPipeline);
  const findWidgetContainer = () => wrapper.findComponent(WidgetContainer);

  beforeEach(() => {
    gon.features = {};
    mock = new MockAdapter(axios);
    mock.onGet(mockData.merge_request_widget_path).reply(HTTP_STATUS_OK, {});
    mock.onGet(mockData.merge_request_cached_widget_path).reply(HTTP_STATUS_OK, {});
  });

  afterEach(() => {
    mock.restore();
    // eslint-disable-next-line @gitlab/vtu-no-explicit-wrapper-destroy
    wrapper.destroy();
    gl.mrWidgetData = {};
  });

  describe('default', () => {
    describe('computed', () => {
      describe('componentName', () => {
        it.each`
          state            | componentName       | component
          ${STATUS_MERGED} | ${'MergedState'}    | ${MergedState}
          ${'conflicts'}   | ${'ConflictsState'} | ${ConflictsState}
          ${'shaMismatch'} | ${'ShaMismatch'}    | ${ShaMismatch}
        `('should translate $state into $componentName component', async ({ state, component }) => {
          await createComponent();
          Vue.set(wrapper.vm.mr, 'state', state);
          await nextTick();
          expect(wrapper.findComponent(component).exists()).toBe(true);
        });
      });

      describe('MrWidgetPipelineContainer', () => {
        it('renders the pipeline container when it has CI', () => {
          createComponent({ updatedMrData: { has_ci: true } });
          expect(findPipelineContainer().exists()).toBe(true);
        });

        it('does not render the pipeline container when it does not have CI', () => {
          createComponent({ updatedMrData: { has_ci: false } });
          expect(findPipelineContainer().exists()).toBe(false);
        });
      });

      describe('shouldRenderCollaborationStatus', () => {
        it('renders collaboration message when collaboration is allowed and the MR is open', () => {
          createComponent({
            updatedMrData: { allow_collaboration: true, state: STATUS_OPEN, not: false },
          });
          expect(findPipelineContainer().props('mr')).toMatchObject({
            allowCollaboration: true,
            isOpen: true,
          });
          expect(wrapper.text()).toContain(COLLABORATION_MESSAGE);
        });

        it('does not render collaboration message when collaboration is allowed and the MR is closed', () => {
          createComponent({
            updatedMrData: { allow_collaboration: true, state: STATUS_CLOSED, not: true },
          });
          expect(findPipelineContainer().props('mr')).toMatchObject({
            allowCollaboration: true,
            isOpen: false,
          });
          expect(wrapper.text()).not.toContain(COLLABORATION_MESSAGE);
        });

        it('does not render collaboration message when collaboration is not allowed and the MR is closed', () => {
          createComponent({
            updatedMrData: { allow_collaboration: undefined, state: STATUS_CLOSED, not: true },
          });
          expect(findPipelineContainer().props('mr')).toMatchObject({
            allowCollaboration: undefined,
            isOpen: false,
          });
          expect(wrapper.text()).not.toContain(COLLABORATION_MESSAGE);
        });

        it('does not render collaboration message when collaboration is not allowed and the MR is open', () => {
          createComponent({
            updatedMrData: { allow_collaboration: undefined, state: STATUS_OPEN, not: true },
          });
          expect(findPipelineContainer().props('mr')).toMatchObject({
            allowCollaboration: undefined,
            isOpen: true,
          });
          expect(wrapper.text()).not.toContain(COLLABORATION_MESSAGE);
        });
      });

      describe('showMergePipelineForkWarning', () => {
        it('hides the alert when the source project and target project are the same', async () => {
          createComponent({
            updatedMrData: {
              source_project_id: 1,
              target_project_id: 1,
            },
          });
          await nextTick();
          Vue.set(wrapper.vm.mr, 'mergePipelinesEnabled', true);
          await nextTick();
          expect(findMergePipelineForkAlert().exists()).toBe(false);
        });

        it('hides the alert when merge pipelines are not enabled', async () => {
          createComponent({
            updatedMrData: {
              source_project_id: 1,
              target_project_id: 2,
            },
          });
          await nextTick();
          expect(findMergePipelineForkAlert().exists()).toBe(false);
        });

        it('shows the alert when merge pipelines are enabled and the source project and target project are different', async () => {
          createComponent({
            updatedMrData: {
              source_project_id: 1,
              target_project_id: 2,
            },
          });
          await nextTick();
          Vue.set(wrapper.vm.mr, 'mergePipelinesEnabled', true);
          await nextTick();
          expect(findMergePipelineForkAlert().exists()).toBe(true);
        });
      });

      describe('formattedHumanAccess', () => {
        it('renders empty string when user is a tool admin but not a member of project', () => {
          createComponent({
            updatedMrData: {
              human_access: null,
              merge_request_add_ci_config_path: 'test',
              has_ci: false,
              is_dismissed_suggest_pipeline: false,
            },
          });
          expect(findSuggestPipeline().props('humanAccess')).toBe('');
        });
        it('renders human access when user is a member of the project', () => {
          createComponent({
            updatedMrData: {
              human_access: 'Owner',
              merge_request_add_ci_config_path: 'test',
              has_ci: false,
              is_dismissed_suggest_pipeline: false,
            },
          });
          expect(findSuggestPipeline().props('humanAccess')).toBe('owner');
        });
      });
    });

    describe('methods', () => {
      describe('checkStatus', () => {
        const updatedMrData = { foo: 1 };
        beforeEach(() => {
          mock
            .onGet(mockData.merge_request_widget_path)
            .reply(HTTP_STATUS_OK, { ...mockData, ...updatedMrData });
          mock
            .onGet(mockData.merge_request_cached_widget_path)
            .reply(HTTP_STATUS_OK, { ...mockData, ...updatedMrData });
        });

        it('checks the status of the pipelines', async () => {
          const callback = jest.fn();
          await createComponent({ updatedMrData });
          await waitForPromises();
          eventHub.$emit('MRWidgetUpdateRequested', callback);
          await waitForPromises();
          expect(callback).toHaveBeenCalledWith(expect.objectContaining(updatedMrData));
        });

        it('notifies the user of the pipeline status', async () => {
          jest.spyOn(notify, 'notifyMe').mockImplementation(() => {});
          const logoFilename = 'logo.png';
          await createComponent({
            updatedMrData: { gitlabLogo: logoFilename },
          });
          eventHub.$emit('MRWidgetUpdateRequested');
          await waitForPromises();
          expect(notify.notifyMe).toHaveBeenCalledWith(
            `Pipeline passed`,
            `Pipeline passed for "${mockData.title}"`,
            logoFilename,
          );
        });

        it('updates the stores data', async () => {
          const mockSetData = jest.fn();
          await createComponent({
            data: {
              mr: {
                setData: mockSetData,
                setGraphqlData: jest.fn(),
              },
            },
          });
          eventHub.$emit('MRWidgetUpdateRequested');
          expect(mockSetData).toHaveBeenCalled();
        });
      });

      describe('initDeploymentsPolling', () => {
        beforeEach(async () => {
          await createComponent();
        });

        it('should call SmartInterval', () => {
          wrapper.vm.initDeploymentsPolling();

          expect(SmartInterval).toHaveBeenCalledWith(
            expect.objectContaining({
              callback: wrapper.vm.fetchPreMergeDeployments,
            }),
          );
        });
      });

      describe('fetchDeployments', () => {
        beforeEach(async () => {
          mock
            .onGet(mockData.ci_environments_status_path)
            .reply(() => [HTTP_STATUS_OK, [{ id: 1, status: SUCCESS }]]);
          await createComponent();
        });

        it('should fetch deployments', async () => {
          eventHub.$emit('FetchDeployments', {});
          await waitForPromises();
          expect(wrapper.vm.mr.deployments.length).toEqual(1);
          expect(wrapper.vm.mr.deployments[0].id).toBe(1);
        });
      });

      describe('fetchActionsContent', () => {
        const innerHTML = 'hello world';
        beforeEach(async () => {
          jest.spyOn(document, 'dispatchEvent');
          mock.onGet(mockData.commit_change_content_path).reply(() => [HTTP_STATUS_OK, innerHTML]);
          await createComponent();
        });

        it('should fetch content of Cherry Pick and Revert modals', async () => {
          eventHub.$emit('FetchActionsContent');
          await waitForPromises();
          expect(document.body.textContent).toContain(innerHTML);
          expect(document.dispatchEvent).toHaveBeenCalledWith(
            new CustomEvent('merged:UpdateActions'),
          );
        });
      });

      describe('bindEventHubListeners', () => {
        const mockSetData = jest.fn();
        beforeEach(async () => {
          await createComponent({
            data: {
              mr: {
                setData: mockSetData,
                setGraphqlData: jest.fn(),
              },
            },
          });
        });

        it('refetches when "MRWidgetUpdateRequested" event is emitted', async () => {
          expect(stateQueryHandler).toHaveBeenCalledTimes(1);
          eventHub.$emit('MRWidgetUpdateRequested', () => {});
          await waitForPromises();
          expect(stateQueryHandler).toHaveBeenCalledTimes(2);
        });

        it('refetches when "MRWidgetRebaseSuccess" event is emitted', async () => {
          expect(stateQueryHandler).toHaveBeenCalledTimes(1);
          eventHub.$emit('MRWidgetRebaseSuccess', () => {});
          await waitForPromises();
          expect(stateQueryHandler).toHaveBeenCalledTimes(2);
        });

        it('should bind to SetBranchRemoveFlag', () => {
          expect(findPipelineContainer().props('mr')).toMatchObject({
            isRemovingSourceBranch: false,
          });
          eventHub.$emit('SetBranchRemoveFlag', [true]);
          expect(findPipelineContainer().props('mr')).toMatchObject({
            isRemovingSourceBranch: true,
          });
        });

        it('should bind to FailedToMerge', async () => {
          expect(findAlertMessage().exists()).toBe(false);
          expect(findPipelineContainer().props('mr')).toMatchObject({
            mergeError: undefined,
            state: 'merged',
          });
          const mergeError = 'Something bad happened!';
          await eventHub.$emit('FailedToMerge', mergeError);

          expect(findAlertMessage().exists()).toBe(true);
          expect(findAlertMessage().text()).toBe(`${mergeError}. Try again.`);
          expect(findPipelineContainer().props('mr')).toMatchObject({
            mergeError,
            state: 'failedToMerge',
          });
        });

        it('should bind to UpdateWidgetData', () => {
          const data = { ...mockData };
          eventHub.$emit('UpdateWidgetData', data);

          expect(mockSetData).toHaveBeenCalledWith(data);
        });
      });

      describe('setFavicon', () => {
        let faviconElement;

        beforeEach(() => {
          const favicon = document.createElement('link');
          favicon.setAttribute('id', 'favicon');
          favicon.dataset.originalHref = faviconDataUrl;
          document.body.appendChild(favicon);

          faviconElement = document.getElementById('favicon');
        });

        afterEach(() => {
          document.body.removeChild(document.getElementById('favicon'));
        });

        it('should call setFavicon method', async () => {
          await createComponent({ updatedMrData: { favicon_overlay_path: overlayDataUrl } });
          expect(setFaviconOverlay).toHaveBeenCalledWith(overlayDataUrl);
        });

        it('should not call setFavicon when there is no faviconOverlayPath', async () => {
          await createComponent({ updatedMrData: { favicon_overlay_path: null } });
          expect(faviconElement.getAttribute('href')).toEqual(null);
        });
      });

      describe('handleNotification', () => {
        const updatedMrData = { gitlabLogo: 'logo.png' };
        beforeEach(() => {
          jest.spyOn(notify, 'notifyMe').mockImplementation(() => {});
        });

        describe('when pipeline has passed', () => {
          beforeEach(() => {
            mock
              .onGet(mockData.merge_request_widget_path)
              .reply(HTTP_STATUS_OK, { ...mockData, ...updatedMrData });
            mock
              .onGet(mockData.merge_request_cached_widget_path)
              .reply(HTTP_STATUS_OK, { ...mockData, ...updatedMrData });
          });

          it('should call notifyMe', async () => {
            await createComponent({ updatedMrData });
            expect(notify.notifyMe).toHaveBeenCalledWith(
              `Pipeline passed`,
              `Pipeline passed for "${mockData.title}"`,
              updatedMrData.gitlabLogo,
            );
          });
        });

        describe('when pipeline has not passed', () => {
          it('should not call notifyMe if the status has not changed', async () => {
            await createComponent({ updatedMrData: { ci_status: undefined } });
            await eventHub.$emit('MRWidgetUpdateRequested');
            expect(notify.notifyMe).not.toHaveBeenCalled();
          });

          it('should not notify if no pipeline provided', async () => {
            await createComponent({ updatedMrData: { pipeline: undefined } });
            expect(notify.notifyMe).not.toHaveBeenCalled();
          });
        });
      });

      describe('Apollo query', () => {
        const interval = 5;
        const data = 'foo';
        const mockCheckStatus = jest.fn().mockResolvedValue({ data });
        const mockSetGraphqlData = jest.fn();
        const mockSetData = jest.fn();

        beforeEach(() => {
          wrapper.destroy();

          return createComponent({
            options: {},
            data: {
              pollInterval: interval,
              startingPollInterval: interval,
              mr: {
                setData: mockSetData,
                setGraphqlData: mockSetGraphqlData,
              },
              service: {
                checkStatus: mockCheckStatus,
              },
            },
          });
        });

        describe('normal polling behavior', () => {
          it('responds to the GraphQL query finishing', () => {
            expect(mockSetGraphqlData).toHaveBeenCalledWith(queryResponse.data.project);
            expect(mockCheckStatus).toHaveBeenCalled();
            expect(mockSetData).toHaveBeenCalledWith(data, undefined);
            expect(stateQueryHandler).toHaveBeenCalledTimes(1);
          });
        });

        describe('external event control', () => {
          describe('enablePolling', () => {
            it('enables the Apollo query polling using the event hub', () => {
              eventHub.$emit('EnablePolling');

              expect(stateQueryHandler).toHaveBeenCalled();
              jest.advanceTimersByTime(interval * STATE_QUERY_POLLING_INTERVAL_BACKOFF);
              expect(stateQueryHandler).toHaveBeenCalledTimes(2);
            });
          });

          describe('disablePolling', () => {
            it('disables the Apollo query polling using the event hub', () => {
              expect(stateQueryHandler).toHaveBeenCalledTimes(1);

              eventHub.$emit('DisablePolling');
              jest.advanceTimersByTime(interval * STATE_QUERY_POLLING_INTERVAL_BACKOFF);

              expect(stateQueryHandler).toHaveBeenCalledTimes(1); // no additional polling after a real interval timeout
            });
          });
        });
      });
    });

    describe('rendering deployments', () => {
      it('renders multiple deployments', async () => {
        await createComponent({
          updatedMrData: {
            deployments: [
              mockDeployment,
              {
                ...mockDeployment,
                id: mockDeployment.id + 1,
              },
            ],
          },
        });
        expect(findPipelineContainer().props('isPostMerge')).toBe(false);
        expect(findPipelineContainer().props('mr').deployments).toHaveLength(2);
        expect(findPipelineContainer().props('mr').postMergeDeployments).toHaveLength(0);
      });
    });

    describe('pipeline for target branch after merge', () => {
      describe('with information for target branch pipeline', () => {
        const state = 'merged';

        it('renders pipeline block', async () => {
          await createComponent({ updatedMrData: { state, merge_pipeline: mockMergePipeline } });
          expect(findMergedPipelineContainer().exists()).toBe(true);
        });

        describe('with post merge deployments', () => {
          it('renders post deployment information', async () => {
            await createComponent({
              updatedMrData: {
                state,
                merge_pipeline: mockMergePipeline,
                post_merge_deployments: mockPostMergeDeployments,
              },
            });
            expect(findMergedPipelineContainer().exists()).toBe(true);
          });
        });
      });

      describe('without information for target branch pipeline', () => {
        it('does not render pipeline block', async () => {
          await createComponent({ updatedMrData: { merge_pipeline: undefined } });
          expect(findMergedPipelineContainer().exists()).toBe(false);
        });
      });

      describe('when state is not merged', () => {
        it('does not render pipeline block', async () => {
          await createComponent({ updatedMrData: { state: 'archived' } });
          expect(findMergedPipelineContainer().exists()).toBe(false);
        });
      });
    });

    it('should not suggest pipelines when feature flag is not present', () => {
      createComponent();
      expect(findSuggestPipeline().exists()).toBe(false);
    });
  });

  describe('suggestPipeline', () => {
    beforeEach(() => {
      mock.onAny().reply(HTTP_STATUS_OK);
    });

    describe('given feature flag is enabled', () => {
      it('should suggest pipelines when none exist', async () => {
        await createComponent({ updatedMrData: { has_ci: false } });
        expect(findSuggestPipeline().exists()).toBe(true);
      });

      it.each([
        { is_dismissed_suggest_pipeline: true },
        { merge_request_add_ci_config_path: null },
        { has_ci: true },
      ])('with %s, should not suggest pipeline', async (obj) => {
        await createComponent({ updatedMrData: { has_ci: false, ...obj } });

        expect(findSuggestPipeline().exists()).toBe(false);
      });

      it('should allow dismiss of the suggest pipeline message', async () => {
        await createComponent({ updatedMrData: { has_ci: false } });
        await findSuggestPipeline().vm.$emit('dismiss');

        expect(findSuggestPipeline().exists()).toBe(false);
      });
    });
  });

  describe('merge error', () => {
    it.each`
      state       | show     | showText
      ${'closed'} | ${false} | ${'hides'}
      ${'merged'} | ${true}  | ${'shows'}
      ${'open'}   | ${true}  | ${'shows'}
    `('$showText merge error when state is $state', async ({ state, show }) => {
      createComponent({ updatedMrData: { state, mergeError: 'Error!' } });

      await waitForPromises();

      expect(wrapper.findByTestId('merge-error').exists()).toBe(show);
    });
  });

  describe('mock extension', () => {
    beforeEach(() => {
      registerExtension(workingExtension());

      createComponent({ mountFn: mountExtended });
    });

    afterEach(() => {
      registeredExtensions.extensions = [];
    });

    it('renders collapsed data', async () => {
      await waitForPromises();

      expect(wrapper.text()).toContain('Test extension summary count: 1');
    });

    it('renders full data', async () => {
      await waitForPromises();

      findExtensionToggleButton().trigger('click');

      await nextTick();

      expect(
        wrapper
          .find('[data-testid="widget-extension-top-level"]')
          .findComponent(GlDropdown)
          .exists(),
      ).toBe(false);

      await nextTick();

      const collapsedSection = wrapper.find('[data-testid="widget-extension-collapsed-section"]');
      expect(collapsedSection.exists()).toBe(true);
      expect(collapsedSection.text()).toContain('Hello world');

      // Renders icon in the row
      expect(collapsedSection.findComponent(GlIcon).exists()).toBe(true);
      expect(collapsedSection.findComponent(GlIcon).props('name')).toBe('status-failed');

      // Renders badge in the row
      expect(collapsedSection.findComponent(GlBadge).exists()).toBe(true);
      expect(collapsedSection.findComponent(GlBadge).text()).toBe('Closed');

      // Renders a link in the row
      expect(collapsedSection.findComponent(GlLink).exists()).toBe(true);
      expect(collapsedSection.findComponent(GlLink).text()).toBe('GitLab.com');

      expect(collapsedSection.findComponent(GlButton).exists()).toBe(true);
      expect(collapsedSection.findComponent(GlButton).text()).toBe('Full report');
    });
  });

  describe('expansion', () => {
    it('hides collapse button', async () => {
      registerExtension(workingExtension(false));
      await createComponent();

      expect(findExtensionToggleButton().exists()).toBe(false);
    });

    it('shows collapse button', async () => {
      registerExtension(workingExtension(true));
      await createComponent({ mountFn: mountExtended });

      expect(findExtensionToggleButton().exists()).toBe(true);
    });
  });

  describe('mock polling extension', () => {
    let pollRequest;

    const findWidgetTestExtension = () => wrapper.find('[data-testid="widget-extension"]');

    beforeEach(() => {
      pollRequest = jest.spyOn(Poll.prototype, 'makeRequest');

      registeredExtensions.extensions = [];
    });

    afterEach(() => {
      registeredExtensions.extensions = [];
    });

    describe('success - multi polling', () => {
      it('sets data when polling is complete', async () => {
        registerExtension(
          multiPollingExtension([
            () =>
              Promise.resolve({
                headers: { 'poll-interval': 0 },
                status: HTTP_STATUS_OK,
                data: { reports: 'parsed' },
              }),
            () =>
              Promise.resolve({
                status: HTTP_STATUS_OK,
                data: { reports: 'parsed' },
              }),
          ]),
        );

        await createComponent({ mountFn: mountExtended });
        expect(findWidgetTestExtension().html()).toContain(
          'Multi polling test extension reports: parsed, count: 2',
        );
      });

      it('shows loading state until polling is complete', async () => {
        registerExtension(
          multiPollingExtension([
            () =>
              Promise.resolve({
                headers: { 'poll-interval': 1 },
                status: HTTP_STATUS_NO_CONTENT,
              }),
            () =>
              Promise.resolve({
                status: HTTP_STATUS_OK,
                data: { reports: 'parsed' },
              }),
          ]),
        );

        await createComponent({ mountFn: mountExtended });
        expect(findWidgetTestExtension().html()).toContain('Test extension loading...');
      });
    });

    describe('success', () => {
      it('does not make additional requests after poll is successful', async () => {
        registerExtension(pollingExtension);

        await createComponent({ mountFn: mountExtended });

        expect(pollRequest).toHaveBeenCalledTimes(1);
      });
    });

    describe('success - full data polling', () => {
      it('sets data when polling is complete', async () => {
        registerExtension(pollingFullDataExtension);

        await createComponent({ mountFn: mountExtended });

        api.trackRedisHllUserEvent.mockClear();
        api.trackRedisCounterEvent.mockClear();

        findExtensionToggleButton().trigger('click');

        // The default working extension is a "warning" type, which generates a second - more specific - telemetry event for expansions
        expect(api.trackRedisHllUserEvent).toHaveBeenCalledTimes(2);
        expect(api.trackRedisHllUserEvent).toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_expand',
        );
        expect(api.trackRedisHllUserEvent).toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_expand_warning',
        );
        expect(api.trackRedisCounterEvent).toHaveBeenCalledTimes(2);
        expect(api.trackRedisCounterEvent).toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_count_expand',
        );
        expect(api.trackRedisCounterEvent).toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_count_expand_warning',
        );
      });
    });

    describe('error', () => {
      it('does not make additional requests after poll has failed', async () => {
        registerExtension(pollingErrorExtension);
        await createComponent({ mountFn: mountExtended });

        expect(pollRequest).toHaveBeenCalledTimes(1);
      });

      it('captures sentry error and displays error when poll has failed', async () => {
        registerExtension(pollingErrorExtension);
        await createComponent({ mountFn: mountExtended });

        expect(Sentry.captureException).toHaveBeenCalled();
        expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Fetch error'));
        expect(wrapper.findComponent(StatusIcon).props('iconName')).toBe('failed');
      });
    });
  });

  describe('mock extension errors', () => {
    afterEach(() => {
      registeredExtensions.extensions = [];
    });

    it('handles collapsed data fetch errors', async () => {
      registerExtension(collapsedDataErrorExtension);
      await createComponent({ mountFn: mountExtended });

      expect(
        wrapper.find('[data-testid="widget-extension"] [data-testid="toggle-button"]').exists(),
      ).toBe(false);
      expect(Sentry.captureException).toHaveBeenCalled();
      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Fetch error'));
      expect(wrapper.findComponent(StatusIcon).props('iconName')).toBe('failed');
    });

    it('handles full data fetch errors', async () => {
      registerExtension(fullDataErrorExtension);
      await createComponent({ mountFn: mountExtended });

      expect(wrapper.findComponent(StatusIcon).props('iconName')).not.toBe('error');
      wrapper
        .find('[data-testid="widget-extension"] [data-testid="toggle-button"]')
        .trigger('click');

      await nextTick();
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledTimes(1);
      expect(Sentry.captureException).toHaveBeenCalledWith(new Error('Fetch error'));
      expect(wrapper.findComponent(StatusIcon).props('iconName')).toBe('failed');
    });
  });

  describe('telemetry', () => {
    afterEach(() => {
      registeredExtensions.extensions = [];
    });

    describe('component name tier suffixes', () => {
      let extension;

      beforeEach(() => {
        extension = workingExtension();
      });

      it('reports events without a CE suffix', () => {
        extension.name = `${extension.name}CE`;

        registerExtension(extension);
        createComponent({ mountFn: mountExtended });

        expect(api.trackRedisHllUserEvent).toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_view',
        );
        expect(api.trackRedisHllUserEvent).not.toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_c_e_view',
        );
      });

      it('reports events without a EE suffix', () => {
        extension.name = `${extension.name}EE`;

        registerExtension(extension);
        createComponent({ mountFn: mountExtended });

        expect(api.trackRedisHllUserEvent).toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_view',
        );
        expect(api.trackRedisHllUserEvent).not.toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_e_e_view',
        );
      });

      it('leaves non-CE & non-EE all caps suffixes intact', () => {
        extension.name = `${extension.name}HI`;

        registerExtension(extension);
        createComponent({ mountFn: mountExtended });

        expect(api.trackRedisHllUserEvent).not.toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_view',
        );
        expect(api.trackRedisHllUserEvent).toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_h_i_view',
        );
      });

      it("doesn't remove CE or EE from the middle of a widget name", () => {
        extension.name = 'TestCEExtensionEETest';

        registerExtension(extension);
        createComponent({ mountFn: mountExtended });

        expect(api.trackRedisHllUserEvent).toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_c_e_extension_e_e_test_view',
        );
      });
    });

    it('triggers view events when mounted', () => {
      registerExtension(workingExtension());
      createComponent({ mountFn: mountExtended });

      expect(api.trackRedisHllUserEvent).toHaveBeenCalledTimes(1);
      expect(api.trackRedisHllUserEvent).toHaveBeenCalledWith(
        'i_code_review_merge_request_widget_test_extension_view',
      );
      expect(api.trackRedisCounterEvent).toHaveBeenCalledTimes(1);
      expect(api.trackRedisCounterEvent).toHaveBeenCalledWith(
        'i_code_review_merge_request_widget_test_extension_count_view',
      );
    });

    describe('expand button', () => {
      it('triggers expand events when clicked', async () => {
        registerExtension(workingExtension());
        createComponent({ mountFn: mountExtended });

        await waitForPromises();

        api.trackRedisHllUserEvent.mockClear();
        api.trackRedisCounterEvent.mockClear();

        findExtensionToggleButton().trigger('click');

        // The default working extension is a "warning" type, which generates a second - more specific - telemetry event for expansions
        expect(api.trackRedisHllUserEvent).toHaveBeenCalledTimes(2);
        expect(api.trackRedisHllUserEvent).toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_expand',
        );
        expect(api.trackRedisHllUserEvent).toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_expand_warning',
        );
        expect(api.trackRedisCounterEvent).toHaveBeenCalledTimes(2);
        expect(api.trackRedisCounterEvent).toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_count_expand',
        );
        expect(api.trackRedisCounterEvent).toHaveBeenCalledWith(
          'i_code_review_merge_request_widget_test_extension_count_expand_warning',
        );
      });
    });

    it('triggers the "full report clicked" events when the appropriate button is clicked', () => {
      registerExtension(fullReportExtension);
      createComponent({ mountFn: mountExtended });

      api.trackRedisHllUserEvent.mockClear();
      api.trackRedisCounterEvent.mockClear();

      findExtensionLink('testref').trigger('click');

      expect(api.trackRedisHllUserEvent).toHaveBeenCalledTimes(1);
      expect(api.trackRedisHllUserEvent).toHaveBeenCalledWith(
        'i_code_review_merge_request_widget_test_extension_click_full_report',
      );
      expect(api.trackRedisCounterEvent).toHaveBeenCalledTimes(1);
      expect(api.trackRedisCounterEvent).toHaveBeenCalledWith(
        'i_code_review_merge_request_widget_test_extension_count_click_full_report',
      );
    });

    describe('when disabled', () => {
      afterEach(() => {
        registeredExtensions.extensions = [];
      });

      it("doesn't emit any telemetry events", async () => {
        registerExtension(noTelemetryExtension);
        createComponent({ mountFn: mountExtended });

        await waitForPromises();

        findExtensionToggleButton().trigger('click');
        findExtensionLink('testref').trigger('click'); // The "full report" link

        expect(api.trackRedisHllUserEvent).not.toHaveBeenCalled();
        expect(api.trackRedisCounterEvent).not.toHaveBeenCalled();
      });
    });
  });

  describe('widget container', () => {
    it('renders the widget container when there is MR data', async () => {
      await createComponent(mockData);
      expect(findWidgetContainer().props('mr')).not.toBeUndefined();
    });
  });

  describe('async preparation for a newly opened MR', () => {
    beforeEach(() => {
      mock
        .onGet(mockData.merge_request_widget_path)
        .reply(() => [HTTP_STATUS_OK, { ...mockData, state: 'opened' }]);
    });

    it('does not render the Preparing state component by default', async () => {
      await createComponent({ mountFn: mountExtended });

      expect(findApprovalsWidget().exists()).toBe(true);
      expect(findPreparingWidget().exists()).toBe(false);
    });

    it('renders the Preparing state component when the MR state is initially "preparing"', async () => {
      await createComponent({
        updatedMrData: { state: 'opened', detailedMergeStatus: 'PREPARING' },
      });

      expect(findApprovalsWidget().exists()).toBe(false);
      expect(findPreparingWidget().exists()).toBe(true);
    });

    describe('when the MR is updated by observing its status', () => {
      beforeEach(() => {
        window.gon.features.realtimeMrStatusChange = true;
      });

      it("shows the Preparing widget when the MR reports it's not ready yet", async () => {
        await createComponent({
          updatedMrData: { state: 'opened', detailedMergeStatus: 'PREPARING' },
          options: {},
          data: {},
        });

        expect(wrapper.html()).toContain('mr-widget-preparing-stub');
      });

      it('removes the Preparing widget when the MR indicates it has been prepared', async () => {
        await createComponent({
          updatedMrData: { state: 'opened', detailedMergeStatus: 'PREPARING' },
          options: {},
          data: {},
        });

        expect(wrapper.html()).toContain('mr-widget-preparing-stub');

        stateSubscription.next({
          data: {
            mergeRequestMergeStatusUpdated: {
              preparedAt: 'non-null value',
            },
          },
        });

        // Wait for batched DOM updates
        await nextTick();

        expect(wrapper.html()).not.toContain('mr-widget-preparing-stub');
      });
    });
  });
});
