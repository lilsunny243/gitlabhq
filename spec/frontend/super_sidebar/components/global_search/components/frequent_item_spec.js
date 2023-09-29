import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import FrequentItem from '~/super_sidebar/components/global_search/components/frequent_item.vue';
import ProjectAvatar from '~/vue_shared/components/project_avatar.vue';
import { stubComponent } from 'helpers/stub_component';

describe('FrequentlyVisitedItem', () => {
  let wrapper;

  const mockItem = {
    id: 123,
    title: 'mockTitle',
    subtitle: 'mockSubtitle',
    avatar: '/mock/avatar.png',
  };

  const createComponent = () => {
    wrapper = shallowMountExtended(FrequentItem, {
      propsData: {
        item: mockItem,
      },
      stubs: {
        GlButton: stubComponent(GlButton, {
          template: '<button type="button" v-on="$listeners"></button>',
        }),
      },
    });
  };

  const findProjectAvatar = () => wrapper.findComponent(ProjectAvatar);
  const findRemoveButton = () => wrapper.findByRole('button');
  const findSubtitle = () => wrapper.findByTestId('subtitle');

  beforeEach(() => {
    createComponent();
  });

  it('renders the project avatar with the expected props', () => {
    expect(findProjectAvatar().props()).toMatchObject({
      projectId: mockItem.id,
      projectName: mockItem.title,
      projectAvatarUrl: mockItem.avatar,
      size: 24,
    });
  });

  it('renders the title and subtitle', () => {
    expect(wrapper.text()).toContain(mockItem.title);
    expect(findSubtitle().text()).toContain(mockItem.subtitle);
  });

  it('does not render the subtitle if not given', async () => {
    await wrapper.setProps({ item: { ...mockItem, subtitle: null } });
    expect(findSubtitle().exists()).toBe(false);
  });

  describe('clicking the remove button', () => {
    const bubbledClickSpy = jest.fn();
    const clickSpy = jest.fn();

    beforeEach(() => {
      wrapper.element.addEventListener('click', bubbledClickSpy);
      const button = findRemoveButton();
      button.element.addEventListener('click', clickSpy);
      button.trigger('click');
    });

    it('emits a remove event on clicking the remove button', () => {
      expect(wrapper.emitted('remove')).toEqual([[mockItem]]);
    });

    it('stops the native event from bubbling and prevents its default behavior', () => {
      expect(bubbledClickSpy).not.toHaveBeenCalled();
      expect(clickSpy.mock.calls[0][0].defaultPrevented).toBe(true);
    });
  });

  describe('pressing enter on the remove button', () => {
    const bubbledKeydownSpy = jest.fn();
    const keydownSpy = jest.fn();

    beforeEach(() => {
      wrapper.element.addEventListener('keydown', bubbledKeydownSpy);
      const button = findRemoveButton();
      button.element.addEventListener('keydown', keydownSpy);
      button.trigger('keydown.enter');
    });

    it('emits a remove event on clicking the remove button', () => {
      expect(wrapper.emitted('remove')).toEqual([[mockItem]]);
    });

    it('stops the native event from bubbling and prevents its default behavior', () => {
      expect(bubbledKeydownSpy).not.toHaveBeenCalled();
      expect(keydownSpy.mock.calls[0][0].defaultPrevented).toBe(true);
    });
  });
});
