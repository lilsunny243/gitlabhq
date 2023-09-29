import { GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { STATUS_CLOSED, STATUS_OPEN } from '~/issues/constants';
import IssueHeader from '~/issues/show/components/issue_header.vue';
import { __, s__ } from '~/locale';
import IssuableHeader from '~/vue_shared/issuable/show/components/issuable_header.vue';

describe('IssueHeader component', () => {
  let wrapper;

  const findGlLink = () => wrapper.findComponent(GlLink);
  const findIssuableHeader = () => wrapper.findComponent(IssuableHeader);

  const mountComponent = (props = {}) => {
    wrapper = shallowMount(IssueHeader, {
      propsData: {
        author: { id: 48 },
        confidential: false,
        createdAt: '2020-01-23T12:34:56.789Z',
        duplicatedToIssueUrl: '',
        isFirstContribution: false,
        isHidden: false,
        isLocked: false,
        issuableState: 'opened',
        issuableType: 'issue',
        movedToIssueUrl: '',
        promotedToEpicUrl: '',
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  it('renders IssuableHeader component', () => {
    mountComponent();

    expect(findIssuableHeader().props()).toMatchObject({
      author: { id: 48 },
      blocked: false,
      confidential: false,
      createdAt: '2020-01-23T12:34:56.789Z',
      isFirstContribution: false,
      isHidden: false,
      issuableState: 'opened',
      issuableType: 'issue',
      serviceDeskReplyTo: '',
      showWorkItemTypeIcon: true,
      statusIcon: 'issues',
      workspaceType: 'project',
    });
  });

  describe('status badge slot', () => {
    describe('when status is open', () => {
      beforeEach(() => {
        mountComponent({ issuableState: STATUS_OPEN });
      });

      it('renders Open text', () => {
        expect(findIssuableHeader().text()).toBe(__('Open'));
      });

      it('renders correct icon', () => {
        expect(findIssuableHeader().props('statusIcon')).toBe('issues');
      });
    });

    describe('when status is closed', () => {
      beforeEach(() => {
        mountComponent({ issuableState: STATUS_CLOSED });
      });

      it('renders Closed text', () => {
        expect(findIssuableHeader().text()).toBe(s__('IssuableStatus|Closed'));
      });

      it('renders correct icon', () => {
        expect(findIssuableHeader().props('statusIcon')).toBe('issue-closed');
      });

      describe('when issue is marked as duplicate', () => {
        beforeEach(() => {
          mountComponent({
            issuableState: STATUS_CLOSED,
            duplicatedToIssueUrl: 'project/-/issue/5',
          });
        });

        it('renders `Closed (duplicated)`', () => {
          expect(findIssuableHeader().text()).toMatchInterpolatedText('Closed (duplicated)');
        });

        it('links to the duplicated issue', () => {
          expect(findGlLink().attributes('href')).toBe('project/-/issue/5');
        });
      });

      describe('when issue is marked as moved', () => {
        beforeEach(() => {
          mountComponent({ issuableState: STATUS_CLOSED, movedToIssueUrl: 'project/-/issue/6' });
        });

        it('renders `Closed (moved)`', () => {
          expect(findIssuableHeader().text()).toMatchInterpolatedText('Closed (moved)');
        });

        it('links to the moved issue', () => {
          expect(findGlLink().attributes('href')).toBe('project/-/issue/6');
        });
      });

      describe('when issue is marked as promoted', () => {
        beforeEach(() => {
          mountComponent({ issuableState: STATUS_CLOSED, promotedToEpicUrl: 'group/-/epic/7' });
        });

        it('renders `Closed (promoted)`', () => {
          expect(findIssuableHeader().text()).toMatchInterpolatedText('Closed (promoted)');
        });

        it('links to the promoted epic', () => {
          expect(findGlLink().attributes('href')).toBe('group/-/epic/7');
        });
      });
    });
  });
});
