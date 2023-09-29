import { shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import BoardNewIssue from '~/boards/components/board_new_issue.vue';
import BoardNewItem from '~/boards/components/board_new_item.vue';
import ProjectSelect from '~/boards/components/project_select.vue';
import eventHub from '~/boards/eventhub';
import groupBoardQuery from '~/boards/graphql/group_board.query.graphql';
import projectBoardQuery from '~/boards/graphql/project_board.query.graphql';
import { WORKSPACE_GROUP, WORKSPACE_PROJECT } from '~/issues/constants';

import {
  mockList,
  mockGroupProjects,
  mockIssue,
  mockIssue2,
  mockProjectBoardResponse,
  mockGroupBoardResponse,
} from '../mock_data';

Vue.use(Vuex);
Vue.use(VueApollo);

const addListNewIssuesSpy = jest.fn().mockResolvedValue();
const mockActions = { addListNewIssue: addListNewIssuesSpy };

const projectBoardQueryHandlerSuccess = jest.fn().mockResolvedValue(mockProjectBoardResponse);
const groupBoardQueryHandlerSuccess = jest.fn().mockResolvedValue(mockGroupBoardResponse);

const mockApollo = createMockApollo([
  [projectBoardQuery, projectBoardQueryHandlerSuccess],
  [groupBoardQuery, groupBoardQueryHandlerSuccess],
]);

const createComponent = ({
  state = {},
  actions = mockActions,
  getters = { getBoardItemsByList: () => () => [] },
  isGroupBoard = true,
  data = { selectedProject: mockGroupProjects[0] },
  provide = {},
} = {}) =>
  shallowMount(BoardNewIssue, {
    apolloProvider: mockApollo,
    store: new Vuex.Store({
      state,
      actions,
      getters,
    }),
    propsData: {
      list: mockList,
      boardId: 'gid://gitlab/Board/1',
    },
    data: () => data,
    provide: {
      groupId: 1,
      fullPath: mockGroupProjects[0].fullPath,
      weightFeatureAvailable: false,
      boardWeight: null,
      isGroupBoard,
      boardType: 'group',
      isEpicBoard: false,
      isApolloBoard: false,
      ...provide,
    },
    stubs: {
      BoardNewItem,
    },
  });

describe('Issue boards new issue form', () => {
  let wrapper;

  const findBoardNewItem = () => wrapper.findComponent(BoardNewItem);

  beforeEach(async () => {
    wrapper = createComponent();

    await nextTick();
  });

  it('renders board-new-item component', () => {
    const boardNewItem = findBoardNewItem();
    expect(boardNewItem.exists()).toBe(true);
    expect(boardNewItem.props()).toEqual({
      list: mockList,
      formEventPrefix: 'toggle-issue-form-',
      submitButtonTitle: 'Create issue',
      disableSubmit: false,
    });
  });

  it('calls addListNewIssue action when `board-new-item` emits form-submit event', async () => {
    findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

    await nextTick();
    expect(addListNewIssuesSpy).toHaveBeenCalledWith(expect.any(Object), {
      list: mockList,
      issueInput: {
        title: 'Foo',
        labelIds: [],
        assigneeIds: [],
        milestoneId: undefined,
        projectPath: mockGroupProjects[0].fullPath,
        moveAfterId: undefined,
      },
    });
  });

  describe('when list has an existing issues', () => {
    beforeEach(() => {
      wrapper = createComponent({
        getters: {
          getBoardItemsByList: () => () => [mockIssue, mockIssue2],
        },
        isGroupBoard: true,
      });
    });

    it('uses the first issue ID as moveAfterId', async () => {
      findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

      await nextTick();
      expect(addListNewIssuesSpy).toHaveBeenCalledWith(expect.any(Object), {
        list: mockList,
        issueInput: {
          title: 'Foo',
          labelIds: [],
          assigneeIds: [],
          milestoneId: undefined,
          projectPath: mockGroupProjects[0].fullPath,
          moveAfterId: mockIssue.id,
        },
      });
    });
  });

  it('emits event `toggle-issue-form` with current list Id suffix on eventHub when `board-new-item` emits form-cancel event', async () => {
    jest.spyOn(eventHub, '$emit').mockImplementation();
    findBoardNewItem().vm.$emit('form-cancel');

    await nextTick();
    expect(eventHub.$emit).toHaveBeenCalledWith(`toggle-issue-form-${mockList.id}`);
  });

  describe('when in group issue board', () => {
    it('renders project-select component within board-new-item component', () => {
      const projectSelect = findBoardNewItem().findComponent(ProjectSelect);

      expect(projectSelect.exists()).toBe(true);
      expect(projectSelect.props('list')).toEqual(mockList);
    });
  });

  describe('when in project issue board', () => {
    beforeEach(() => {
      wrapper = createComponent({
        isGroupBoard: false,
      });
    });

    it('does not render project-select component within board-new-item component', () => {
      const projectSelect = findBoardNewItem().findComponent(ProjectSelect);

      expect(projectSelect.exists()).toBe(false);
    });
  });

  describe('Apollo boards', () => {
    it.each`
      boardType            | queryHandler                       | notCalledHandler
      ${WORKSPACE_GROUP}   | ${groupBoardQueryHandlerSuccess}   | ${projectBoardQueryHandlerSuccess}
      ${WORKSPACE_PROJECT} | ${projectBoardQueryHandlerSuccess} | ${groupBoardQueryHandlerSuccess}
    `(
      'fetches $boardType board and emits addNewIssue event',
      async ({ boardType, queryHandler, notCalledHandler }) => {
        wrapper = createComponent({
          provide: {
            boardType,
            isProjectBoard: boardType === WORKSPACE_PROJECT,
            isGroupBoard: boardType === WORKSPACE_GROUP,
            isApolloBoard: true,
          },
        });

        await nextTick();
        findBoardNewItem().vm.$emit('form-submit', { title: 'Foo' });

        await nextTick();

        expect(queryHandler).toHaveBeenCalled();
        expect(notCalledHandler).not.toHaveBeenCalled();
        expect(wrapper.emitted('addNewIssue')[0][0]).toMatchObject({ title: 'Foo' });
      },
    );
  });
});
