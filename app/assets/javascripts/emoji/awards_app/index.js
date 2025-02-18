import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState } from 'vuex';
import { parseBoolean } from '~/lib/utils/common_utils';
import AwardsList from '~/vue_shared/components/awards_list.vue';
import createstore from './store';

export default (el) => {
  if (!el) return null;

  const {
    dataset: { path, newCustomEmojiPath },
  } = el;
  const canAwardEmoji = parseBoolean(el.dataset.canAwardEmoji);

  return new Vue({
    el,
    name: 'AwardsListRoot',
    store: createstore(),
    provide: {
      newCustomEmojiPath,
    },
    computed: {
      ...mapState(['currentUserId', 'canAwardEmoji', 'awards']),
    },
    created() {
      this.setInitialData({ path, currentUserId: window.gon.current_user_id, canAwardEmoji });
    },
    mounted() {
      this.fetchAwards();
    },
    methods: {
      ...mapActions(['setInitialData', 'fetchAwards', 'toggleAward']),
    },
    render(createElement) {
      return createElement(AwardsList, {
        props: {
          awards: this.awards,
          canAwardEmoji: this.canAwardEmoji,
          currentUserId: this.currentUserId,
          defaultAwards: ['thumbsup', 'thumbsdown'],
          selectedClass: 'selected',
        },
        on: {
          award: this.toggleAward,
        },
      });
    },
  });
};
