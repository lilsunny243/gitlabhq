# frozen_string_literal: true

module QA
  RSpec.describe 'Create' do
    describe 'Repository License Detection', product_group: :source_code do
      after do
        project.remove_via_api!
      end

      let(:project) { create(:project) }

      shared_examples 'project license detection' do
        it 'displays the name of the license on the repository' do
          license_path = Runtime::Path.fixture('software_licenses', license_file_name)
          Resource::Repository::Commit.fabricate_via_api! do |commit|
            commit.project = project
            commit.add_files([{ file_path: 'LICENSE', content: File.read(license_path) }])
          end

          project.visit!

          Page::Project::Show.perform do |project|
            Support::Waiter.wait_until(reload_page: project, message: 'Waiting for licence') do
              project.has_license?(rendered_license_name)
            end
          end
        end
      end

      context 'on a project with a commonly used LICENSE',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/366842' do
        it_behaves_like 'project license detection' do
          let(:license_file_name) { 'bsd-3-clause' }
          let(:rendered_license_name) { 'BSD 3-Clause "New" or "Revised" License' }
        end
      end

      context 'on a project with an unrecognized LICENSE',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/366843' do
        it_behaves_like 'project license detection' do
          let(:license_file_name) { 'other' }
          let(:rendered_license_name) { 'LICENSE' }
        end
      end
    end
  end
end
