# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BitbucketServerImport::Importers::PullRequestNotesImporter, feature_category: :importers do
  include AfterNextHelpers

  let_it_be(:project) do
    create(:project, :repository, :import_started,
      import_data_attributes: {
        data: { 'project_key' => 'key', 'repo_slug' => 'slug' },
        credentials: { 'token' => 'token' }
      }
    )
  end

  let_it_be(:pull_request_data) { Gitlab::Json.parse(fixture_file('importers/bitbucket_server/pull_request.json')) }
  let_it_be(:pull_request) { BitbucketServer::Representation::PullRequest.new(pull_request_data) }
  let_it_be(:note_author) { create(:user, username: 'note_author', email: 'note_author@example.org') }

  let_it_be(:pull_request_author) do
    create(:user, username: 'pull_request_author', email: 'pull_request_author@example.org')
  end

  let(:merge_event) do
    instance_double(
      BitbucketServer::Representation::Activity,
      comment?: false,
      merge_event?: true,
      committer_email: pull_request_author.email,
      merge_timestamp: now,
      merge_commit: '12345678'
    )
  end

  let(:pr_note) do
    instance_double(
      BitbucketServer::Representation::Comment,
      note: 'Hello world',
      author_email: note_author.email,
      author_username: note_author.username,
      comments: [],
      created_at: now,
      updated_at: now,
      parent_comment: nil)
  end

  let(:pr_comment) do
    instance_double(
      BitbucketServer::Representation::Activity,
      comment?: true,
      inline_comment?: false,
      merge_event?: false,
      comment: pr_note)
  end

  let_it_be(:sample) { RepoHelpers.sample_compare }
  let_it_be(:now) { Time.now.utc.change(usec: 0) }

  def expect_log(stage:, message:)
    allow(Gitlab::BitbucketServerImport::Logger).to receive(:info).and_call_original
    expect(Gitlab::BitbucketServerImport::Logger)
      .to receive(:info).with(include(import_stage: stage, message: message))
  end

  subject(:importer) { described_class.new(project, pull_request.to_hash) }

  describe '#execute', :clean_gitlab_redis_cache do
    context 'when a matching merge request is not found' do
      it 'does nothing' do
        expect { importer.execute }.not_to change { Note.count }
      end

      it 'logs its progress' do
        expect_log(stage: 'import_pull_request_notes', message: 'starting')
        expect_log(stage: 'import_pull_request_notes', message: 'finished')

        importer.execute
      end
    end

    context 'when a matching merge request is found' do
      let_it_be(:merge_request) { create(:merge_request, iid: pull_request.iid, source_project: project) }

      it 'logs its progress' do
        allow_next(BitbucketServer::Client).to receive(:activities).and_return([])

        expect_log(stage: 'import_pull_request_notes', message: 'starting')
        expect_log(stage: 'import_pull_request_notes', message: 'finished')

        importer.execute
      end

      context 'when PR has comments' do
        before do
          allow_next(BitbucketServer::Client).to receive(:activities).and_return([pr_comment])
        end

        it 'imports the stand alone comments' do
          expect { subject.execute }.to change { Note.count }.by(1)

          expect(merge_request.notes.count).to eq(1)
          expect(merge_request.notes.first).to have_attributes(
            note: end_with(pr_note.note),
            author: note_author,
            created_at: pr_note.created_at,
            updated_at: pr_note.created_at
          )
        end

        it 'logs its progress' do
          expect_log(stage: 'import_standalone_pr_comments', message: 'starting')
          expect_log(stage: 'import_standalone_pr_comments', message: 'finished')

          importer.execute
        end
      end

      context 'when PR has threaded discussion' do
        let_it_be(:reply_author) { create(:user, username: 'reply_author', email: 'reply_author@example.org') }
        let_it_be(:inline_note_author) do
          create(:user, username: 'inline_note_author', email: 'inline_note_author@example.org')
        end

        let(:reply) do
          instance_double(
            BitbucketServer::Representation::PullRequestComment,
            author_email: reply_author.email,
            author_username: reply_author.username,
            note: 'I agree',
            created_at: now,
            updated_at: now,
            parent_comment: nil)
        end

        let(:pr_inline_note) do
          instance_double(
            BitbucketServer::Representation::PullRequestComment,
            file_type: 'ADDED',
            from_sha: pull_request.target_branch_sha,
            to_sha: pull_request.source_branch_sha,
            file_path: '.gitmodules',
            old_pos: nil,
            new_pos: 4,
            note: 'Hello world',
            author_email: inline_note_author.email,
            author_username: inline_note_author.username,
            comments: [reply],
            created_at: now,
            updated_at: now,
            parent_comment: nil)
        end

        let(:pr_inline_comment) do
          instance_double(
            BitbucketServer::Representation::Activity,
            comment?: true,
            inline_comment?: true,
            merge_event?: false,
            comment: pr_inline_note)
        end

        before do
          allow_next(BitbucketServer::Client).to receive(:activities).and_return([pr_inline_comment])
        end

        it 'imports the threaded discussion' do
          expect { subject.execute }.to change { Note.count }.by(2)

          expect(merge_request.discussions.count).to eq(1)

          notes = merge_request.notes.order(:id).to_a
          start_note = notes.first
          expect(start_note.type).to eq('DiffNote')
          expect(start_note.note).to end_with(pr_inline_note.note)
          expect(start_note.created_at).to eq(pr_inline_note.created_at)
          expect(start_note.updated_at).to eq(pr_inline_note.updated_at)
          expect(start_note.position.old_line).to be_nil
          expect(start_note.position.new_line).to eq(pr_inline_note.new_pos)
          expect(start_note.author).to eq(inline_note_author)

          reply_note = notes.last
          expect(reply_note.note).to eq(reply.note)
          expect(reply_note.author).to eq(reply_author)
          expect(reply_note.created_at).to eq(reply.created_at)
          expect(reply_note.updated_at).to eq(reply.created_at)
          expect(reply_note.position.old_line).to be_nil
          expect(reply_note.position.new_line).to eq(pr_inline_note.new_pos)
        end

        it 'logs its progress' do
          expect_log(stage: 'import_inline_comments', message: 'starting')
          expect_log(stage: 'import_inline_comments', message: 'finished')

          importer.execute
        end
      end

      context 'when PR has a merge event' do
        before do
          allow_next(BitbucketServer::Client).to receive(:activities).and_return([merge_event])
        end

        it 'imports the merge event' do
          importer.execute

          merge_request.reload

          expect(merge_request.metrics.merged_by).to eq(pull_request_author)
          expect(merge_request.metrics.merged_at).to eq(merge_event.merge_timestamp)
          expect(merge_request.merge_commit_sha).to eq(merge_event.merge_commit)
        end
      end
    end
  end
end
