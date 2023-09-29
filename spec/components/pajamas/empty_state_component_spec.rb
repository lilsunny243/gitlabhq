# frozen_string_literal: true

require "spec_helper"

RSpec.describe Pajamas::EmptyStateComponent, type: :component, feature_category: :design_system do
  let(:title) { 'Empty state title' }
  let(:primary_button_link) { '#learn-more-primary' }
  let(:primary_button_text) { 'Learn more' }
  let(:secondary_button_link) { '#learn-more-secondary' }
  let(:secondary_button_text) { 'Another action' }
  let(:description) { 'Empty state description' }
  let(:svg_path) { 'illustrations/empty-state/empty-projects-deleted-md.svg' }
  let(:compact) { false }
  let(:empty_state_options) { { id: 'empty-state-rails-component' } }

  before do
    render_inline described_class.new(
      title: title,
      svg_path: svg_path,
      empty_state_options: empty_state_options,
      primary_button_link: primary_button_link,
      primary_button_text: primary_button_text,
      secondary_button_link: secondary_button_link,
      secondary_button_text: secondary_button_text,
      compact: compact) do |c|
      c.with_description { description } if description
    end
  end

  describe 'default' do
    it 'renders the primary action' do
      expect(page).to have_link(primary_button_text, href: primary_button_link)
    end

    it 'renders the secondary action' do
      expect(page).to have_link(secondary_button_text, href: secondary_button_link)
    end

    it 'renders image as illustration' do
      img = page.find('img')

      expect(img['src']).to eq(ActionController::Base.helpers.image_path(svg_path))
    end

    it 'renders title' do
      h1 = page.find('h1')

      expect(h1).to have_text(title)
    end

    it 'renders description' do
      expect(find_description).to have_text(description)
    end

    it 'renders section with flex direction column' do
      expect(find_section[:id]).to eq(empty_state_options[:id])
      expect(find_section[:class]).to eq("gl-display-flex empty-state gl-text-center gl-flex-direction-column")
    end
  end

  describe 'when compact' do
    let(:compact) { true }

    it 'renders section with flex direction row' do
      expect(find_section[:class]).to eq("gl-display-flex empty-state gl-flex-direction-row gl-align-items-center")
    end
  end

  describe 'when svg_path is empty' do
    let(:svg_path) { '' }

    it 'does not render image' do
      expect(page).not_to have_selector('img')
    end
  end

  describe 'when description is empty' do
    let(:description) { nil }

    it 'does not render a description' do
      expect(find_description).to be_nil
    end
  end

  describe 'with no buttons' do
    let(:primary_button_text) { nil }
    let(:secondary_button_text) { nil }

    it 'does not render any buttons' do
      expect(page).not_to have_selector('a')
    end
  end

  def find_section
    page.find('section')
  end

  def find_description
    page.first('[data-testid="empty-state-description"]', minimum: 0)
  end
end
