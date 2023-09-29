# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectAuthorization, feature_category: :groups_and_projects do
  describe 'create' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project_1) { create(:project) }

    let(:project_auth) do
      build(
        :project_authorization,
        user: user,
        project: project_1
      )
    end

    it 'sets is_unique' do
      expect { project_auth.save! }.to change { project_auth.is_unique }.to(true)
    end
  end

  describe 'unique user, project authorizations' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project_1) { create(:project) }

    let!(:project_auth) do
      create(
        :project_authorization,
        user: user,
        project: project_1,
        access_level: Gitlab::Access::DEVELOPER
      )
    end

    context 'with duplicate user and project authorization' do
      subject { project_auth.dup }

      it { is_expected.to be_invalid }

      context 'after validation' do
        before do
          subject.valid?
        end

        it 'contains duplicate error' do
          expect(subject.errors[:user]).to include('has already been taken')
        end
      end
    end

    context 'with multiple access levels for the same user and project' do
      subject do
        project_auth.dup.tap do |auth|
          auth.access_level = Gitlab::Access::MAINTAINER
        end
      end

      it { is_expected.to be_invalid }

      context 'after validation' do
        before do
          subject.valid?
        end

        it 'contains duplicate error' do
          expect(subject.errors[:user]).to include('has already been taken')
        end
      end
    end
  end

  describe 'relations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:user) }
    it { is_expected.to validate_presence_of(:access_level) }
    it { is_expected.to validate_inclusion_of(:access_level).in_array(Gitlab::Access.all_values) }
  end

  describe 'scopes' do
    describe '.non_guests' do
      let_it_be(:project) { create(:project) }
      let_it_be(:project_original_owner_authorization) { project.owner.project_authorizations.first }
      let_it_be(:project_authorization_guest) { create(:project_authorization, :guest, project: project) }
      let_it_be(:project_authorization_reporter) { create(:project_authorization, :reporter, project: project) }
      let_it_be(:project_authorization_developer) { create(:project_authorization, :developer, project: project) }
      let_it_be(:project_authorization_maintainer) { create(:project_authorization, :maintainer, project: project) }
      let_it_be(:project_authorization_owner) { create(:project_authorization, :owner, project: project) }

      it 'returns all records which are greater than Guests access' do
        expect(described_class.non_guests.map(&:attributes)).to match_array([
          project_authorization_reporter, project_authorization_developer,
          project_authorization_maintainer, project_authorization_owner,
          project_original_owner_authorization
        ].map(&:attributes))
      end
    end
  end

  describe '.insert_all' do
    let_it_be(:user) { create(:user) }
    let_it_be(:project_1) { create(:project) }
    let_it_be(:project_2) { create(:project) }
    let_it_be(:project_3) { create(:project) }

    it 'skips duplicates and inserts the remaining rows without error' do
      create(:project_authorization, user: user, project: project_1, access_level: Gitlab::Access::MAINTAINER)

      attributes = [
        { user_id: user.id, project_id: project_1.id, access_level: Gitlab::Access::MAINTAINER },
        { user_id: user.id, project_id: project_2.id, access_level: Gitlab::Access::MAINTAINER },
        { user_id: user.id, project_id: project_3.id, access_level: Gitlab::Access::MAINTAINER }
      ]

      described_class.insert_all(attributes)

      expect(user.project_authorizations.pluck(:user_id, :project_id, :access_level)).to match_array(attributes.map(&:values))
    end
  end
end
