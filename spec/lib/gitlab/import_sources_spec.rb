# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ImportSources, feature_category: :importers do
  describe '.options' do
    it 'returns a hash' do
      expected =
        {
          'GitHub' => 'github',
          'Bitbucket Cloud' => 'bitbucket',
          'Bitbucket Server' => 'bitbucket_server',
          'FogBugz' => 'fogbugz',
          'Repository by URL' => 'git',
          'GitLab export' => 'gitlab_project',
          'Gitea' => 'gitea',
          'Manifest file' => 'manifest'
        }

      expect(described_class.options).to eq(expected)
    end
  end

  describe '.values' do
    it 'returns an array' do
      expected =
        %w(
          github
          bitbucket
          bitbucket_server
          fogbugz
          git
          gitlab_project
          gitea
          manifest
        )

      expect(described_class.values).to eq(expected)
    end
  end

  describe '.importer_names' do
    it 'returns an array of importer names' do
      expected =
        %w(
          github
          bitbucket
          bitbucket_server
          fogbugz
          gitlab_project
          gitea
        )

      expect(described_class.importer_names).to eq(expected)
    end
  end

  describe '.importer' do
    import_sources = {
      'github' => Gitlab::GithubImport::ParallelImporter,
      'bitbucket' => Gitlab::BitbucketImport::ParallelImporter,
      'bitbucket_server' => Gitlab::BitbucketServerImport::ParallelImporter,
      'fogbugz' => Gitlab::FogbugzImport::Importer,
      'git' => nil,
      'gitlab_project' => Gitlab::ImportExport::Importer,
      'gitea' => Gitlab::LegacyGithubImport::Importer,
      'manifest' => nil
    }

    import_sources.each do |name, klass|
      it "returns #{klass} when given #{name}" do
        expect(described_class.importer(name)).to eq(klass)
      end
    end
  end

  describe '.import_table' do
    subject { described_class.import_table }

    describe 'Bitbucket cloud' do
      it 'returns the ParallelImporter' do
        is_expected.to include(
          described_class::ImportSource.new(
            'bitbucket',
            'Bitbucket Cloud',
            Gitlab::BitbucketImport::ParallelImporter
          )
        )
      end

      context 'when flag is disabled' do
        before do
          stub_feature_flags(bitbucket_parallel_importer: false)
        end

        it 'returns the legacy Importer' do
          is_expected.to include(
            described_class::ImportSource.new(
              'bitbucket',
              'Bitbucket Cloud',
              Gitlab::BitbucketImport::Importer
            )
          )
        end
      end
    end
  end

  describe '.title' do
    import_sources = {
      'github' => 'GitHub',
      'bitbucket' => 'Bitbucket Cloud',
      'bitbucket_server' => 'Bitbucket Server',
      'fogbugz' => 'FogBugz',
      'git' => 'Repository by URL',
      'gitlab_project' => 'GitLab export',
      'gitea' => 'Gitea',
      'manifest' => 'Manifest file'
    }

    import_sources.each do |name, title|
      it "returns #{title} when given #{name}" do
        expect(described_class.title(name)).to eq(title)
      end
    end
  end

  describe 'imports_repository? checker' do
    let(:allowed_importers) { %w[github gitlab_project bitbucket bitbucket_server] }

    it 'fails if any importer other than the allowed ones implements this method' do
      current_importers = described_class.values.select { |kind| described_class.importer(kind).try(:imports_repository?) }
      not_allowed_importers = current_importers - allowed_importers

      expect(not_allowed_importers).to be_empty, failure_message(not_allowed_importers)
    end

    def failure_message(importers_class_names)
      <<-MSG
        It looks like the #{importers_class_names.join(', ')} importers implements its own way to import the repository.
        That means that the lfs object download must be handled for each of them. You can use 'LfsImportService' and
        'LfsDownloadService' to implement it. After that, add the importer name to the list of allowed importers in this spec.
      MSG
    end
  end
end
