import path from 'path';
import { defineConfig } from 'vite';
import svgLoader from 'vite-svg-loader';
import vue from '@vitejs/plugin-vue2';
import graphql from '@rollup/plugin-graphql';
import RubyPlugin from 'vite-plugin-ruby';
import { viteCommonjs } from '@originjs/vite-plugin-commonjs';
import webpackConfig from './config/webpack.config';
import {
  IS_EE,
  IS_JH,
  SOURCEGRAPH_PUBLIC_PATH,
  GITLAB_WEB_IDE_PUBLIC_PATH,
} from './config/webpack.constants';
import viteSharedConfig from './config/vite.json';

const aliasArr = Object.entries(webpackConfig.resolve.alias).map(([find, replacement]) => ({
  find: find.includes('$') ? new RegExp(find) : find,
  replacement,
}));

const assetsPath = path.resolve(__dirname, 'app/assets');
const javascriptsPath = path.resolve(assetsPath, 'javascripts');

const emptyComponent = path.resolve(javascriptsPath, 'vue_shared/components/empty_component.js');

const [rubyPlugin, ...rest] = RubyPlugin();

// We can't use regular 'resolve' which points to sourceCodeDir in vite.json
// Because we need for '~' alias to resolve to app/assets/javascripts
// We can't use javascripts folder in sourceCodeDir because we also need to resolve other assets
// With undefined 'resolve' an '~' alias from Webpack config is used instead
// See the issue for details: https://github.com/ElMassimo/vite_ruby/issues/237
const fixedRubyPlugin = [
  {
    ...rubyPlugin,
    config: (...args) => {
      const originalConfig = rubyPlugin.config(...args);
      return {
        ...originalConfig,
        resolve: undefined,
      };
    },
  },
  ...rest,
];

const EE_ALIAS_FALLBACK = [
  {
    find: /^ee_component\/(.*)\.vue/,
    replacement: emptyComponent,
  },
];

const JH_ALIAS_FALLBACK = [
  {
    find: /^jh_component\/(.*)\.vue/,
    replacement: emptyComponent,
  },
];

export default defineConfig({
  resolve: {
    alias: [
      ...aliasArr,
      ...(IS_EE ? [] : EE_ALIAS_FALLBACK),
      ...(IS_JH ? [] : JH_ALIAS_FALLBACK),
      {
        find: '~/',
        replacement: javascriptsPath,
      },
    ],
  },
  plugins: [
    fixedRubyPlugin,
    vue({
      template: {
        compilerOptions: {
          whitespace: 'preserve',
        },
      },
    }),
    graphql(),
    svgLoader({
      defaultImport: 'raw',
    }),
    viteCommonjs({
      include: [path.resolve(javascriptsPath, 'locale/ensure_single_line.cjs')],
    }),
  ],
  define: {
    IS_EE: IS_EE ? 'window.gon && window.gon.ee' : JSON.stringify(false),
    IS_JH: IS_JH ? 'window.gon && window.gon.jh' : JSON.stringify(false),
    'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV),
    'process.env.SOURCEGRAPH_PUBLIC_PATH': JSON.stringify(SOURCEGRAPH_PUBLIC_PATH),
    'process.env.GITLAB_WEB_IDE_PUBLIC_PATH': JSON.stringify(GITLAB_WEB_IDE_PUBLIC_PATH),
  },
  server: {
    hmr: {
      host: viteSharedConfig?.development?.host || 'localhost',
      // ensure we stay compatible with HTTPS enabled for GDK
      protocol: 'ws',
    },
    https: false,
  },
});
