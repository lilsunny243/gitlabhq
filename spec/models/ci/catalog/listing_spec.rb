# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Catalog::Listing, feature_category: :pipeline_composition do
  let_it_be(:namespace) { create(:group) }
  let_it_be(:project_1) { create(:project, namespace: namespace, name: 'X Project') }
  let_it_be(:project_2) { create(:project, namespace: namespace, name: 'B Project') }
  let_it_be(:project_3) { create(:project) }
  let_it_be(:user) { create(:user) }

  let(:list) { described_class.new(namespace, user) }

  describe '#new' do
    context 'when namespace is not a root namespace' do
      let(:namespace) { create(:group, :nested) }

      it 'raises an exception' do
        expect { list }.to raise_error(ArgumentError, 'Namespace is not a root namespace')
      end
    end
  end

  describe '#resources' do
    subject(:resources) { list.resources }

    context 'when the user has access to all projects in the namespace' do
      before do
        namespace.add_developer(user)
      end

      context 'when the namespace has no catalog resources' do
        it { is_expected.to be_empty }
      end

      context 'when the namespace has catalog resources' do
        let_it_be(:resource) { create(:ci_catalog_resource, project: project_1) }
        let_it_be(:resource_2) { create(:ci_catalog_resource, project: project_2) }
        let_it_be(:other_namespace_resource) { create(:ci_catalog_resource, project: project_3) }

        it 'contains only catalog resources for projects in that namespace' do
          is_expected.to contain_exactly(resource, resource_2)
        end

        context 'with a sort parameter' do
          subject(:resources) { list.resources(sort: sort) }

          context 'when the sort is name ascending' do
            let_it_be(:sort) { :name_asc }

            it 'contains catalog resources for projects sorted by name' do
              is_expected.to eq([resource_2, resource])
            end
          end

          context 'when the sort is name descending' do
            let_it_be(:sort) { :name_desc }

            it 'contains catalog resources for projects sorted by name' do
              is_expected.to eq([resource, resource_2])
            end
          end
        end
      end
    end

    context 'when the user only has access to some projects in the namespace' do
      let!(:resource_1) { create(:ci_catalog_resource, project: project_1) }
      let!(:resource_2) { create(:ci_catalog_resource, project: project_2) }

      before do
        project_1.add_developer(user)
        project_2.add_guest(user)
      end

      it 'only returns catalog resources for projects the user has access to' do
        is_expected.to contain_exactly(resource_1)
      end
    end

    context 'when the user does not have access to the namespace' do
      let!(:resource) { create(:ci_catalog_resource, project: project_1) }

      it { is_expected.to be_empty }
    end
  end
end
