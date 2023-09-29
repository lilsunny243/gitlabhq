# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BulkImports::Projects::Pipelines::ReferencesPipeline, feature_category: :importers do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:bulk_import) { create(:bulk_import, user: user) }
  let_it_be(:config) { create(:bulk_import_configuration, bulk_import: bulk_import, url: 'https://my.gitlab.com') }
  let_it_be(:entity) do
    create(
      :bulk_import_entity,
      :project_entity,
      project: project,
      bulk_import: bulk_import,
      source_full_path: 'source/full/path'
    )
  end

  let_it_be(:tracker) { create(:bulk_import_tracker, entity: entity) }
  let_it_be(:context) { BulkImports::Pipeline::Context.new(tracker) }
  let(:issue) { create(:issue, project: project, description: 'https://my.gitlab.com/source/full/path/-/issues/1') }
  let(:mr) do
    create(
      :merge_request,
      source_project: project,
      description: 'https://my.gitlab.com/source/full/path/-/merge_requests/1 @source_username? @bob, @alice!'
    )
  end

  let(:issue_note) do
    create(
      :note,
      project: project,
      noteable: issue,
      note: 'https://my.gitlab.com/source/full/path/-/issues/1 @older_username, not_a@username, and @old_username.'
    )
  end

  let(:mr_note) do
    create(
      :note,
      project: project,
      noteable: mr,
      note: 'https://my.gitlab.com/source/full/path/-/merge_requests/1 @same_username'
    )
  end

  let(:interchanged_usernames) do
    create(
      :note,
      project: project,
      noteable: mr,
      note: '@manuelgrabowski-admin, @boaty-mc-boatface'
    )
  end

  let(:old_note_html) { 'old note_html' }
  let(:system_note) do
    create(
      :note,
      project: project,
      system: true,
      noteable: issue,
      note: "mentioned in merge request !#{mr.iid} created by @old_username",
      note_html: old_note_html
    )
  end

  let(:username_system_note) do
    create(
      :note,
      project: project,
      system: true,
      noteable: issue,
      note: "mentioned in merge request created by @source_username.",
      note_html: 'empty'
    )
  end

  subject(:pipeline) { described_class.new(context) }

  before do
    project.add_owner(user)

    allow(Gitlab::Cache::Import::Caching)
      .to receive(:values_from_hash)
      .and_return({
        'old_username' => 'new_username',
        'older_username' => 'newer_username',
        'source_username' => 'destination_username',
        'bob' => 'alice-gdk',
        'alice' => 'bob-gdk',
        'manuelgrabowski' => 'manuelgrabowski-admin',
        'manuelgrabowski-admin' => 'manuelgrabowski',
        'boaty-mc-boatface' => 'boatymcboatface',
        'boatymcboatface' => 'boaty-mc-boatface'
      })
  end

  def create_project_data
    [issue, mr, issue_note, mr_note, system_note, username_system_note]
  end

  def create_username_project_data
    [username_system_note]
  end

  describe '#extract' do
    it 'returns ExtractedData containing issues, mrs & their notes' do
      create_project_data

      extracted_data = subject.extract(context)

      expect(extracted_data).to be_instance_of(BulkImports::Pipeline::ExtractedData)
      expect(extracted_data.data).to contain_exactly(issue, mr, issue_note, system_note, username_system_note, mr_note)
      expect(system_note.note_html).not_to eq(old_note_html)
      expect(system_note.note_html)
        .to include("class=\"gfm gfm-merge_request\">!#{mr.iid}</a>")
        .and include(project.full_path.to_s)
        .and include("@old_username")
      expect(username_system_note.note_html)
        .to include("@source_username")
    end

    context 'when object body is nil' do
      let(:issue) { create(:issue, project: project, description: nil) }

      it 'returns ExtractedData not containing the object' do
        extracted_data = subject.extract(context)

        expect(extracted_data.data).to contain_exactly(issue_note, mr, mr_note)
      end
    end
  end

  describe '#transform' do
    it 'updates matching urls and usernames with new ones' do
      transformed_mr = subject.transform(context, mr)
      transformed_note = subject.transform(context, mr_note)
      transformed_issue = subject.transform(context, issue)
      transformed_issue_note = subject.transform(context, issue_note)
      transformed_system_note = subject.transform(context, system_note)
      transformed_username_system_note = subject.transform(context, username_system_note)

      expected_url = URI('')
      expected_url.scheme = ::Gitlab.config.gitlab.https ? 'https' : 'http'
      expected_url.host = ::Gitlab.config.gitlab.host
      expected_url.port = ::Gitlab.config.gitlab.port
      expected_url.path = "/#{project.full_path}/-/merge_requests/#{mr.iid}"

      expect(transformed_issue_note.note).not_to include("@older_username")
      expect(transformed_mr.description).not_to include("@source_username")
      expect(transformed_system_note.note).not_to include("@old_username")
      expect(transformed_username_system_note.note).not_to include("@source_username")

      expect(transformed_issue.description).to eq('http://localhost:80/namespace1/project-1/-/issues/1')
      expect(transformed_mr.description).to eq("#{expected_url} @destination_username? @alice-gdk, @bob-gdk!")
      expect(transformed_note.note).to eq("#{expected_url} @same_username")
      expect(transformed_issue_note.note).to include("@newer_username, not_a@username, and @new_username.")
      expect(transformed_system_note.note).to eq("mentioned in merge request !#{mr.iid} created by @new_username")
      expect(transformed_username_system_note.note).to include("@destination_username.")
    end

    it 'handles situations where old usernames are substrings of new usernames' do
      transformed_mr = subject.transform(context, mr)

      expect(transformed_mr.description).to include("@alice-gdk")
      expect(transformed_mr.description).not_to include("@bob-gdk-gdk")
    end

    it 'handles situations where old and new usernames are interchanged' do
      # e.g
      # |------------------------|-------------------------|
      # | old_username           | new_username            |
      # |------------------------|-------------------------|
      # | @manuelgrabowski-admin | @manuelgrabowski        |
      # | @manuelgrabowski       | @manuelgrabowski-admin  |
      # |------------------------|-------------------------|

      transformed_interchanged_usernames = subject.transform(context, interchanged_usernames)

      expect(transformed_interchanged_usernames.note).to include("@manuelgrabowski")
      expect(transformed_interchanged_usernames.note).to include("@boatymcboatface")
      expect(transformed_interchanged_usernames.note).not_to include("@manuelgrabowski-admin")
      expect(transformed_interchanged_usernames.note).not_to include("@boaty-mc-boatface")
    end

    context 'when object does not have reference or username' do
      it 'returns object unchanged' do
        issue.update!(description: 'foo')

        transformed_issue = subject.transform(context, issue)

        expect(transformed_issue.description).to eq('foo')
      end
    end

    context 'when there are not matched urls or usernames' do
      let(:description) { 'https://my.gitlab.com/another/project/path/-/issues/1 @random_username' }

      shared_examples 'returns object unchanged' do
        it 'returns object unchanged' do
          issue.update!(description: description)

          transformed_issue = subject.transform(context, issue)

          expect(transformed_issue.description).to eq(description)
        end
      end

      include_examples 'returns object unchanged'

      context 'when url path does not start with source full path' do
        let(:description) { 'https://my.gitlab.com/another/source/full/path/-/issues/1' }

        include_examples 'returns object unchanged'
      end

      context 'when host does not match and url path starts with source full path' do
        let(:description) { 'https://another.gitlab.com/source/full/path/-/issues/1' }

        include_examples 'returns object unchanged'
      end

      context 'when url does not match at all' do
        let(:description) { 'https://website.example/foo/bar' }

        include_examples 'returns object unchanged'
      end
    end
  end

  describe '#load' do
    it 'saves the object when object body changed' do
      transformed_issue = subject.transform(context, issue)
      transformed_note = subject.transform(context, mr_note)
      transformed_mr = subject.transform(context, mr)
      transformed_issue_note = subject.transform(context, issue_note)
      transformed_system_note = subject.transform(context, system_note)

      expect(transformed_issue).to receive(:save!)
      expect(transformed_note).to receive(:save!)
      expect(transformed_mr).to receive(:save!)
      expect(transformed_issue_note).to receive(:save!)
      expect(transformed_system_note).to receive(:save!)

      subject.load(context, transformed_issue)
      subject.load(context, transformed_note)
      subject.load(context, transformed_mr)
      subject.load(context, transformed_issue_note)
      subject.load(context, transformed_system_note)
    end

    context 'when object body is not changed' do
      it 'does not save the object' do
        expect(mr).not_to receive(:save!)
        expect(mr_note).not_to receive(:save!)
        expect(system_note).not_to receive(:save!)

        subject.load(context, mr)
        subject.load(context, mr_note)
        subject.load(context, system_note)
      end
    end
  end
end
