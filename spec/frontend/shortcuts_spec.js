import $ from 'jquery';
import { flatten } from 'lodash';
import htmlSnippetsShow from 'test_fixtures/snippets/show.html';
import { Mousetrap } from '~/lib/mousetrap';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import Shortcuts, { LOCAL_MOUSETRAP_DATA_KEY } from '~/behaviors/shortcuts/shortcuts';
import MarkdownPreview from '~/behaviors/preview_markdown';

describe('Shortcuts', () => {
  const createEvent = (type, target) =>
    $.Event(type, {
      target,
    });
  let shortcuts;

  beforeAll(() => {
    shortcuts = new Shortcuts();
  });

  beforeEach(() => {
    setHTMLFixture(htmlSnippetsShow);

    new Shortcuts(); // eslint-disable-line no-new
    new MarkdownPreview(); // eslint-disable-line no-new

    jest.spyOn(document.querySelector('#search'), 'focus');

    jest.spyOn(Mousetrap.prototype, 'stopCallback');
    jest.spyOn(Mousetrap.prototype, 'bind').mockImplementation();
    jest.spyOn(Mousetrap.prototype, 'unbind').mockImplementation();
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  describe('markdown shortcuts', () => {
    let shortcutElements;

    beforeEach(() => {
      // Get all shortcuts specified with md-shortcuts attributes in the fixture.
      // `shortcuts` will look something like this:
      // [
      //   [ 'mod+b' ],
      //   [ 'mod+i' ],
      //   [ 'mod+k' ]
      // ]
      shortcutElements = $('.edit-note .js-md')
        .map(function getShortcutsFromToolbarBtn() {
          const mdShortcuts = $(this).data('md-shortcuts');

          // jQuery.map() automatically unwraps arrays, so we
          // have to double wrap the array to counteract this
          return mdShortcuts ? [mdShortcuts] : undefined;
        })
        .get();
    });

    describe('initMarkdownEditorShortcuts', () => {
      let $textarea;
      let localMousetrapInstance;

      beforeEach(() => {
        $textarea = $('.edit-note textarea');
        Shortcuts.initMarkdownEditorShortcuts($textarea);
        localMousetrapInstance = $textarea.data(LOCAL_MOUSETRAP_DATA_KEY);
      });

      it('attaches a Mousetrap handler for every markdown shortcut specified with md-shortcuts', () => {
        const expectedCalls = shortcutElements.map((s) => [s, expect.any(Function)]);

        expect(Mousetrap.prototype.bind.mock.calls).toEqual(expectedCalls);
      });

      it('attaches a stopCallback that allows each markdown shortcut specified with md-shortcuts', () => {
        flatten(shortcutElements).forEach((s) => {
          expect(
            localMousetrapInstance.stopCallback.call(localMousetrapInstance, null, null, s),
          ).toBe(false);
        });
      });
    });

    describe('removeMarkdownEditorShortcuts', () => {
      it('does nothing if initMarkdownEditorShortcuts was not previous called', () => {
        Shortcuts.removeMarkdownEditorShortcuts($('.edit-note textarea'));

        expect(Mousetrap.prototype.unbind.mock.calls).toEqual([]);
      });

      it('removes Mousetrap handlers for every markdown shortcut specified with md-shortcuts', () => {
        Shortcuts.initMarkdownEditorShortcuts($('.edit-note textarea'));
        Shortcuts.removeMarkdownEditorShortcuts($('.edit-note textarea'));

        const expectedCalls = shortcutElements.map((s) => [s]);

        expect(Mousetrap.prototype.unbind.mock.calls).toEqual(expectedCalls);
      });
    });
  });

  describe('focusSearch', () => {
    describe('when super sidebar is NOT enabled', () => {
      let originalGon;
      beforeEach(() => {
        originalGon = window.gon;
        window.gon = { use_new_navigation: false };
      });

      afterEach(() => {
        window.gon = originalGon;
      });

      it('focuses the search bar', () => {
        Shortcuts.focusSearch(createEvent('KeyboardEvent'));
        expect(document.querySelector('#search').focus).toHaveBeenCalled();
      });
    });
  });

  describe('bindCommand(s)', () => {
    it('bindCommand calls Mousetrap.bind correctly', () => {
      const mockCommand = { defaultKeys: ['m'] };
      const mockCallback = () => {};

      shortcuts.bindCommand(mockCommand, mockCallback);

      expect(Mousetrap.prototype.bind).toHaveBeenCalledTimes(1);
      const [callArguments] = Mousetrap.prototype.bind.mock.calls;
      expect(callArguments[0]).toEqual(mockCommand.defaultKeys);
      expect(callArguments[1]).toBe(mockCallback);
    });

    it('bindCommands calls Mousetrap.bind correctly', () => {
      const mockCommandsAndCallbacks = [
        [{ defaultKeys: ['1'] }, () => {}],
        [{ defaultKeys: ['2'] }, () => {}],
      ];

      shortcuts.bindCommands(mockCommandsAndCallbacks);

      expect(Mousetrap.prototype.bind).toHaveBeenCalledTimes(mockCommandsAndCallbacks.length);
      const { calls } = Mousetrap.prototype.bind.mock;

      mockCommandsAndCallbacks.forEach(([mockCommand, mockCallback], i) => {
        expect(calls[i][0]).toEqual(mockCommand.defaultKeys);
        expect(calls[i][1]).toBe(mockCallback);
      });
    });
  });
});
