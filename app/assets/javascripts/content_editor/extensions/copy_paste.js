import OrderedMap from 'orderedmap';
import { Extension } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import { Schema, DOMParser as ProseMirrorDOMParser, DOMSerializer } from '@tiptap/pm/model';
import { uniqueId } from 'lodash';
import { __ } from '~/locale';
import { VARIANT_DANGER } from '~/alert';
import createMarkdownDeserializer from '../services/gl_api_markdown_deserializer';
import { ALERT_EVENT, EXTENSION_PRIORITY_HIGHEST } from '../constants';
import CodeBlockHighlight from './code_block_highlight';
import CodeSuggestion from './code_suggestion';
import Diagram from './diagram';
import Frontmatter from './frontmatter';

const TEXT_FORMAT = 'text/plain';
const GFM_FORMAT = 'text/x-gfm';
const HTML_FORMAT = 'text/html';
const VS_CODE_FORMAT = 'vscode-editor-data';
const CODE_BLOCK_NODE_TYPES = [
  CodeBlockHighlight.name,
  CodeSuggestion.name,
  Diagram.name,
  Frontmatter.name,
];

function parseHTML(schema, html) {
  const parser = new DOMParser();
  const startTag = '<body>';
  const endTag = '</body>';
  const { body } = parser.parseFromString(startTag + html + endTag, 'text/html');
  return { document: ProseMirrorDOMParser.fromSchema(schema).parse(body) };
}

const findLoader = (editor, loaderId) => {
  let position;

  editor.view.state.doc.descendants((descendant, pos) => {
    if (descendant.type.name === 'loading' && descendant.attrs.id === loaderId) {
      position = pos;
      return false;
    }

    return true;
  });

  return position;
};

export default Extension.create({
  name: 'copyPaste',
  priority: EXTENSION_PRIORITY_HIGHEST,
  addOptions() {
    return {
      renderMarkdown: null,
      serializer: null,
    };
  },
  addCommands() {
    return {
      pasteContent: (content = '', processMarkdown = true) => () => {
        const { editor, options } = this;
        const { renderMarkdown, eventHub } = options;
        const deserializer = createMarkdownDeserializer({ render: renderMarkdown });

        const pasteSchemaSpec = { ...editor.schema.spec };
        pasteSchemaSpec.marks = OrderedMap.from(pasteSchemaSpec.marks).remove('span');
        pasteSchemaSpec.nodes = OrderedMap.from(pasteSchemaSpec.nodes).remove('div').remove('pre');
        const pasteSchema = new Schema(pasteSchemaSpec);

        const promise = processMarkdown
          ? deserializer.deserialize({ schema: pasteSchema, markdown: content })
          : Promise.resolve(parseHTML(pasteSchema, content));
        const loaderId = uniqueId('loading');

        Promise.resolve()
          .then(() => {
            editor.commands.insertContent({ type: 'loading', attrs: { id: loaderId } });
            return promise;
          })
          .then(async ({ document }) => {
            if (!document) return;

            const pos = findLoader(editor, loaderId);
            if (!pos) return;

            const { firstChild, childCount } = document.content;
            const toPaste =
              childCount === 1 && firstChild.type.name === 'paragraph'
                ? firstChild.content
                : document.content;

            editor
              .chain()
              .deleteRange({ from: pos, to: pos + 1 })
              .insertContentAt(pos, toPaste.toJSON(), {
                updateSelection: false,
              })
              .run();
          })
          .catch(() => {
            eventHub.$emit(ALERT_EVENT, {
              message: __('An error occurred while pasting text in the editor. Please try again.'),
              variant: VARIANT_DANGER,
            });
          });

        return true;
      },
    };
  },
  addProseMirrorPlugins() {
    let pasteRaw = false;

    const handleCutAndCopy = (view, event) => {
      const slice = view.state.selection.content();
      const gfmContent = this.options.serializer.serialize({ doc: slice.content });
      const documentFragment = DOMSerializer.fromSchema(view.state.schema).serializeFragment(
        slice.content,
      );
      const div = document.createElement('div');
      div.appendChild(documentFragment);

      event.clipboardData.setData(TEXT_FORMAT, div.innerText);
      event.clipboardData.setData(HTML_FORMAT, div.innerHTML);
      event.clipboardData.setData(GFM_FORMAT, gfmContent);

      event.preventDefault();
      event.stopPropagation();
    };

    return [
      new Plugin({
        key: new PluginKey('copyPaste'),
        props: {
          handleDOMEvents: {
            copy: handleCutAndCopy,
            cut: (view, event) => {
              handleCutAndCopy(view, event);
              this.editor.commands.deleteSelection();
            },
          },
          handleKeyDown: (_, event) => {
            pasteRaw = event.key === 'v' && (event.metaKey || event.ctrlKey) && event.shiftKey;
          },

          handlePaste: (view, event) => {
            const { clipboardData } = event;

            const gfmContent = clipboardData.getData(GFM_FORMAT);

            if (gfmContent) {
              return this.editor.commands.pasteContent(gfmContent, true);
            }

            const textContent = clipboardData.getData(TEXT_FORMAT);
            const htmlContent = clipboardData.getData(HTML_FORMAT);

            const { from, to } = view.state.selection;

            if (pasteRaw) {
              this.editor.commands.insertContentAt(
                { from, to },
                textContent.replace(/^\s+|\s+$/gm, ''),
              );
              return true;
            }

            const hasHTML = clipboardData.types.some((type) => type === HTML_FORMAT);
            const hasVsCode = clipboardData.types.some((type) => type === VS_CODE_FORMAT);
            const vsCodeMeta = hasVsCode ? JSON.parse(clipboardData.getData(VS_CODE_FORMAT)) : {};
            const language = vsCodeMeta.mode;

            // if a code block is active, paste as plain text
            if (!textContent || CODE_BLOCK_NODE_TYPES.some((type) => this.editor.isActive(type))) {
              return false;
            }

            if (hasVsCode) {
              return this.editor.commands.pasteContent(
                language === 'markdown' ? textContent : `\`\`\`${language}\n${textContent}\n\`\`\``,
                true,
              );
            }

            const preStartRegex = /^<pre[^>]*lang="markdown"[^>]*>/;
            const preEndRegex = /<\/pre>$/;
            const htmlContentWithoutMeta = htmlContent?.replace(/^<meta[^>]*>/, '');
            const pastingMarkdownBlock =
              hasHTML &&
              preStartRegex.test(htmlContentWithoutMeta) &&
              preEndRegex.test(htmlContentWithoutMeta);

            if (pastingMarkdownBlock) return this.editor.commands.pasteContent(textContent, true);

            return this.editor.commands.pasteContent(hasHTML ? htmlContent : textContent, !hasHTML);
          },
        },
      }),
    ];
  },
});
