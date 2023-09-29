# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::GithubImport::Settings, feature_category: :importers do
  subject(:settings) { described_class.new(project) }

  let_it_be(:project) { create(:project) }

  let(:optional_stages) do
    {
      single_endpoint_issue_events_import: true,
      single_endpoint_notes_import: false,
      attachments_import: false,
      collaborators_import: false
    }
  end

  describe '.stages_array' do
    let(:expected_list) do
      stages = described_class::OPTIONAL_STAGES
      [
        {
          name: 'single_endpoint_issue_events_import',
          label: stages[:single_endpoint_issue_events_import][:label],
          selected: false,
          details: stages[:single_endpoint_issue_events_import][:details]
        },
        {
          name: 'single_endpoint_notes_import',
          label: stages[:single_endpoint_notes_import][:label],
          selected: false,
          details: stages[:single_endpoint_notes_import][:details]
        },
        {
          name: 'attachments_import',
          label: stages[:attachments_import][:label].strip,
          selected: false,
          details: stages[:attachments_import][:details]
        },
        {
          name: 'collaborators_import',
          label: stages[:collaborators_import][:label].strip,
          selected: true,
          details: stages[:collaborators_import][:details]
        }
      ]
    end

    it 'returns stages list as array' do
      expect(described_class.stages_array).to match_array(expected_list)
    end
  end

  describe '#write' do
    let(:data_input) do
      {
        optional_stages: {
          single_endpoint_issue_events_import: true,
          single_endpoint_notes_import: 'false',
          attachments_import: nil,
          collaborators_import: false,
          foo: :bar
        },
        timeout_strategy: "optimistic",
        additional_access_tokens: %w[foo bar]
      }.stringify_keys
    end

    it 'puts optional steps, timeout strategy & access tokens into projects import_data' do
      project.create_or_update_import_data(credentials: { user: 'token' })

      settings.write(data_input)

      expect(project.import_data.data['optional_stages'])
        .to eq optional_stages.stringify_keys
      expect(project.import_data.data['timeout_strategy'])
        .to eq("optimistic")
      expect(project.import_data.credentials.fetch(:additional_access_tokens))
        .to eq(data_input['additional_access_tokens'])
    end
  end

  describe '#enabled?' do
    it 'returns is enabled or not specific optional stage' do
      project.create_or_update_import_data(data: { optional_stages: optional_stages })

      expect(settings.enabled?(:single_endpoint_issue_events_import)).to eq true
      expect(settings.enabled?(:single_endpoint_notes_import)).to eq false
      expect(settings.enabled?(:attachments_import)).to eq false
      expect(settings.enabled?(:collaborators_import)).to eq false
    end
  end

  describe '#disabled?' do
    it 'returns is disabled or not specific optional stage' do
      project.create_or_update_import_data(data: { optional_stages: optional_stages })

      expect(settings.disabled?(:single_endpoint_issue_events_import)).to eq false
      expect(settings.disabled?(:single_endpoint_notes_import)).to eq true
      expect(settings.disabled?(:attachments_import)).to eq true
      expect(settings.disabled?(:collaborators_import)).to eq true
    end
  end
end
