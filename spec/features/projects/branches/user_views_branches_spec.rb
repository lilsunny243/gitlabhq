# frozen_string_literal: true

require "spec_helper"

RSpec.describe "User views branches", :js, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { project.first_owner }

  before do
    sign_in(user)
  end

  context "all branches" do
    before do
      visit(project_branches_path(project))
    end

    describe 'default branch' do
      before do
        search_branches('master')
      end

      it "shows the default branch" do
        expect(page).to have_content("Branches").and have_content("master")

        expect(page.all(".graph-side")).to all(have_content(/\d+/))
      end

      it "does not show the \"More actions\" dropdown" do
        expect(page).not_to have_selector('[data-testid="branch-more-actions"]')
      end
    end

    describe 'non-default branch' do
      before do
        search_branches('feature')
      end

      it "shows the branches" do
        expect(page).to have_content("Branches").and have_content("feature")

        expect(page.all(".graph-side")).to all(have_content(/\d+/))
      end

      it "shows the \"More actions\" dropdown" do
        expect(page).to have_button('More actions')
      end
    end
  end

  context "protected branches" do
    let_it_be(:protected_branch) { create(:protected_branch, project: project) }

    before do
      visit(project_protected_branches_path(project))
    end

    it "shows branches" do
      page.within(".protected-branches-list") do
        expect(page).to have_content(protected_branch.name).and have_no_content("master")
      end
    end
  end

  def search_branches(query)
    branch_search = find('input[data-testid="branch-search"]')
    branch_search.set(query)
    branch_search.native.send_keys(:enter)
  end
end
