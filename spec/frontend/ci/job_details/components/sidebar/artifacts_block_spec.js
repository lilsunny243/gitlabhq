import { GlPopover } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { trimText } from 'helpers/text_helper';
import ArtifactsBlock from '~/ci/job_details/components/sidebar/artifacts_block.vue';
import { getTimeago } from '~/lib/utils/datetime_utility';

describe('Artifacts block', () => {
  let wrapper;

  const createWrapper = (propsData) =>
    mountExtended(ArtifactsBlock, {
      propsData: {
        helpUrl: 'help-url',
        ...propsData,
      },
    });

  const findArtifactRemoveElt = () => wrapper.findByTestId('artifacts-remove-timeline');
  const findJobLockedElt = () => wrapper.findByTestId('artifacts-locked-message-content');
  const findKeepBtn = () => wrapper.findByTestId('keep-artifacts');
  const findDownloadBtn = () => wrapper.findByTestId('download-artifacts');
  const findBrowseBtn = () => wrapper.findByTestId('browse-artifacts-button');
  const findArtifactsHelpLink = () => wrapper.findByTestId('artifacts-help-link');
  const findPopover = () => wrapper.findComponent(GlPopover);

  const expireAt = '2018-08-14T09:38:49.157Z';
  const timeago = getTimeago();
  const formattedDate = timeago.format(expireAt);
  const lockedText =
    'These artifacts are the latest. They will not be deleted (even if expired) until newer artifacts are available.';

  const expiredArtifact = {
    expireAt,
    expired: true,
    locked: false,
  };

  const nonExpiredArtifact = {
    downloadPath: '/gitlab-org/gitlab-foss/-/jobs/98314558/artifacts/download',
    browsePath: '/gitlab-org/gitlab-foss/-/jobs/98314558/artifacts/browse',
    keepPath: '/gitlab-org/gitlab-foss/-/jobs/98314558/artifacts/keep',
    expireAt,
    expired: false,
    locked: false,
  };

  const lockedExpiredArtifact = {
    ...expiredArtifact,
    downloadPath: '/gitlab-org/gitlab-foss/-/jobs/98314558/artifacts/download',
    browsePath: '/gitlab-org/gitlab-foss/-/jobs/98314558/artifacts/browse',
    expired: true,
    locked: true,
  };

  const lockedNonExpiredArtifact = {
    ...nonExpiredArtifact,
    keepPath: undefined,
    locked: true,
  };

  describe('with expired artifacts that are not locked', () => {
    beforeEach(() => {
      wrapper = createWrapper({
        artifact: expiredArtifact,
      });
    });

    it('renders expired artifact date and info', () => {
      expect(trimText(findArtifactRemoveElt().text())).toBe(
        `The artifacts were removed ${formattedDate}`,
      );

      expect(
        findArtifactRemoveElt()
          .find('[data-testid="artifact-expired-help-link"]')
          .attributes('href'),
      ).toBe('help-url');
    });

    it('does not show the keep button', () => {
      expect(findKeepBtn().exists()).toBe(false);
    });

    it('does not show the download button', () => {
      expect(findDownloadBtn().exists()).toBe(false);
    });

    it('does not show the browse button', () => {
      expect(findBrowseBtn().exists()).toBe(false);
    });
  });

  describe('with artifacts that will expire', () => {
    beforeEach(() => {
      wrapper = createWrapper({
        artifact: nonExpiredArtifact,
      });
    });

    it('renders will expire artifact date and info', () => {
      expect(trimText(findArtifactRemoveElt().text())).toBe(
        `The artifacts will be removed ${formattedDate}`,
      );

      expect(
        findArtifactRemoveElt()
          .find('[data-testid="artifact-expired-help-link"]')
          .attributes('href'),
      ).toBe('help-url');
    });

    it('renders the keep button', () => {
      expect(findKeepBtn().exists()).toBe(true);
    });

    it('renders the download button', () => {
      expect(findDownloadBtn().exists()).toBe(true);
    });

    it('renders the browse button', () => {
      expect(findBrowseBtn().exists()).toBe(true);
    });
  });

  describe('with expired locked artifacts', () => {
    beforeEach(() => {
      wrapper = createWrapper({
        artifact: lockedExpiredArtifact,
      });
    });

    it('renders the information that the artefacts are locked', () => {
      expect(findArtifactRemoveElt().exists()).toBe(false);
      expect(trimText(findJobLockedElt().text())).toBe(lockedText);
    });

    it('does not render the keep button', () => {
      expect(findKeepBtn().exists()).toBe(false);
    });

    it('renders the download button', () => {
      expect(findDownloadBtn().exists()).toBe(true);
    });

    it('renders the browse button', () => {
      expect(findBrowseBtn().exists()).toBe(true);
    });
  });

  describe('with non expired locked artifacts', () => {
    beforeEach(() => {
      wrapper = createWrapper({
        artifact: lockedNonExpiredArtifact,
      });
    });

    it('renders the information that the artefacts are locked', () => {
      expect(findArtifactRemoveElt().exists()).toBe(false);
      expect(trimText(findJobLockedElt().text())).toBe(lockedText);
    });

    it('does not render the keep button', () => {
      expect(findKeepBtn().exists()).toBe(false);
    });

    it('renders the download button', () => {
      expect(findDownloadBtn().exists()).toBe(true);
    });

    it('renders the browse button', () => {
      expect(findBrowseBtn().exists()).toBe(true);
    });
  });

  describe('artifacts help text', () => {
    beforeEach(() => {
      wrapper = createWrapper({
        artifact: lockedNonExpiredArtifact,
      });
    });

    it('displays help text', () => {
      const expectedHelpText =
        'Job artifacts are files that are configured to be uploaded when a job finishes execution. Artifacts could be compiled files, unit tests or scanning reports, or any other files generated by a job.';

      expect(findPopover().text()).toBe(expectedHelpText);
    });

    it('links to artifacts help page', () => {
      expect(findArtifactsHelpLink().attributes('href')).toBe('/help/ci/jobs/job_artifacts');
    });
  });
});
