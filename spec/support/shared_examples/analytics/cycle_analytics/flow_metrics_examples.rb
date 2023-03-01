# frozen_string_literal: true

RSpec.shared_examples 'value stream analytics flow metrics issueCount examples' do
  let_it_be(:milestone) { create(:milestone, group: group) }
  let_it_be(:label) { create(:group_label, group: group) }

  let_it_be(:author) { create(:user) }
  let_it_be(:assignee) { create(:user) }

  let_it_be(:issue1) { create(:issue, project: project1, author: author, created_at: 12.days.ago) }
  let_it_be(:issue2) { create(:issue, project: project2, author: author, created_at: 13.days.ago) }

  let_it_be(:issue3) do
    create(:labeled_issue,
      project: project1,
      labels: [label],
      author: author,
      milestone: milestone,
      assignees: [assignee],
      created_at: 14.days.ago)
  end

  let_it_be(:issue4) do
    create(:labeled_issue,
      project: project2,
      labels: [label],
      assignees: [assignee],
      created_at: 15.days.ago)
  end

  let_it_be(:issue_outside_of_the_range) { create(:issue, project: project2, author: author, created_at: 50.days.ago) }

  let(:query) do
    <<~QUERY
      query($path: ID!, $assigneeUsernames: [String!], $authorUsername: String, $milestoneTitle: String, $labelNames: [String!], $from: Time!, $to: Time!) {
        #{context}(fullPath: $path) {
          flowMetrics {
            issueCount(assigneeUsernames: $assigneeUsernames, authorUsername: $authorUsername, milestoneTitle: $milestoneTitle, labelNames: $labelNames, from: $from, to: $to) {
              value
              unit
              identifier
              title
            }
          }
        }
      }
    QUERY
  end

  let(:variables) do
    {
      path: full_path,
      from: 20.days.ago.iso8601,
      to: 10.days.ago.iso8601
    }
  end

  subject(:result) do
    post_graphql(query, current_user: current_user, variables: variables)

    graphql_data.dig(context.to_s, 'flowMetrics', 'issueCount')
  end

  it 'returns the correct count' do
    expect(result).to eq({
      'identifier' => 'issues',
      'unit' => nil,
      'value' => 4,
      'title' => n_('New Issue', 'New Issues', 4)
    })
  end

  context 'with partial filters' do
    let(:variables) do
      {
        path: full_path,
        assigneeUsernames: [assignee.username],
        labelNames: [label.title],
        from: 20.days.ago.iso8601,
        to: 10.days.ago.iso8601
      }
    end

    it 'returns filtered count' do
      expect(result).to eq({
        'identifier' => 'issues',
        'unit' => nil,
        'value' => 2,
        'title' => n_('New Issue', 'New Issues', 2)
      })
    end
  end

  context 'with all filters' do
    let(:variables) do
      {
        path: full_path,
        assigneeUsernames: [assignee.username],
        labelNames: [label.title],
        authorUsername: author.username,
        milestoneTitle: milestone.title,
        from: 20.days.ago.iso8601,
        to: 10.days.ago.iso8601
      }
    end

    it 'returns filtered count' do
      expect(result).to eq({
        'identifier' => 'issues',
        'unit' => nil,
        'value' => 1,
        'title' => n_('New Issue', 'New Issues', 1)
      })
    end
  end

  context 'when the user is not authorized' do
    let(:current_user) { create(:user) }

    it 'returns nil' do
      expect(result).to eq(nil)
    end
  end
end
