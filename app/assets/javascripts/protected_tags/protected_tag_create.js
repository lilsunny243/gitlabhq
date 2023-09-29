import $ from 'jquery';
import CreateItemDropdown from '~/create_item_dropdown';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { s__, __ } from '~/locale';
import { initAccessDropdown } from '~/projects/settings/init_access_dropdown';
import { ACCESS_LEVELS } from './constants';

export default class ProtectedTagCreate {
  constructor({ hasLicense }) {
    this.hasLicense = hasLicense;
    this.$form = $('.js-new-protected-tag');
    this.buildDropdowns();
    this.bindEvents();
    this.selectedItems = [];
  }

  bindEvents() {
    this.$form.on('submit', this.onFormSubmit.bind(this));
  }

  buildDropdowns() {
    // Cache callback
    this.onSelectCallback = this.onSelect.bind(this);

    // Protected tag dropdown
    this.createItemDropdown = new CreateItemDropdown({
      $dropdown: this.$form.find('.js-protected-tag-select'),
      defaultToggleLabel: __('Protected Tag'),
      fieldName: 'protected_tag[name]',
      onSelect: this.onSelectCallback,
      getData: ProtectedTagCreate.getProtectedTags,
    });

    // Allowed to Create dropdown
    const createTagSelector = 'js-allowed-to-create';
    const [dropdownEl] = this.$form.find(`.${createTagSelector}`);
    this.protectedTagAccessDropdown = initAccessDropdown(dropdownEl, {
      toggleClass: createTagSelector,
      hasLicense: this.hasLicense,
      accessLevel: ACCESS_LEVELS.CREATE,
      accessLevelsData: gon.create_access_levels,
      searchEnabled: dropdownEl.dataset.filter !== undefined,
      testId: 'allowed_to_create_dropdown',
    });

    this.protectedTagAccessDropdown.$on('select', (selected) => {
      this.selectedItems = selected;
      this.onSelectCallback();
    });

    this.protectedTagAccessDropdown.$on('shown', () => {
      this.createItemDropdown.close();
    });
  }

  // This will run after clicked callback
  onSelect() {
    // Enable submit button
    const $tagInput = this.$form.find('input[name="protected_tag[name]"]');
    this.$form
      .find('button[type="submit"]')
      .prop('disabled', !($tagInput.val() && this.selectedItems.length));
  }

  static getProtectedTags(term, callback) {
    callback(gon.open_tags);
  }

  getFormData() {
    const formData = {
      authenticity_token: this.$form.find('input[name="authenticity_token"]').val(),
      protected_tag: {
        name: this.$form.find('input[name="protected_tag[name]"]').val(),
      },
    };
    formData.protected_tag[`${ACCESS_LEVELS.CREATE}_attributes`] = this.selectedItems;
    return formData;
  }

  onFormSubmit(e) {
    e.preventDefault();

    axios[this.$form.attr('method')](this.$form.attr('action'), this.getFormData())
      .then(() => {
        window.location.reload();
      })
      .catch(() =>
        createAlert({
          message: s__('ProjectSettings|Failed to protect the tag'),
        }),
      );
  }
}
