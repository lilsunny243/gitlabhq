# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::OtherMarkup, feature_category: :wiki do
  let(:context) { {} }

  context 'when restructured text' do
    it 'renders' do
      input = <<~RST
        Header
        ======

        *emphasis*; **strong emphasis**; `interpreted text`
      RST

      output = <<~HTML
        <h1>Header</h1>
        <p><em>emphasis</em>; <strong>strong emphasis</strong>; <cite>interpreted text</cite></p>
      HTML

      expect(render('unimportant_name.rst', input, context)).to include(output.strip)
    end

    context 'when PlantUML is enabled' do
      it 'generates the diagram' do
        Gitlab::CurrentSettings.current_application_settings.update!(plantuml_enabled: true, plantuml_url: 'https://plantuml.com/plantuml')

        input = <<~RST
          .. plantuml::
                 :caption: Caption with **bold** and *italic*

                 Bob -> Alice: hello
                 Alice -> Bob: hi
        RST

        output = <<~HTML
          <img class="plantuml" src="https://plantuml.com/plantuml/png/U9npoazIqBLJSCp9J4wrKiX8pSd9vm9pGA9E-Kb0iKm0o4SAt000" data-diagram="plantuml" data-diagram-src="data:text/plain;base64,Qm9iIC0+IEFsaWNlOiBoZWxsbwpBbGljZSAtPiBCb2I6IGhp">
          <p>Caption with <strong>bold</strong> and <em>italic</em></p>
        HTML

        expect(render('unimportant_name.rst', input, context)).to include(output.strip)
      end
    end
  end

  context 'XSS Checks' do
    links = {
      'links' => {
        file: 'file.rdoc',
        input: 'XSS[JaVaScriPt:alert(1)]',
        output: "\n" + '<p><a>XSS</a></p>' + "\n"
      }
    }
    links.each do |name, data|
      it "does not convert dangerous #{name} into HTML" do
        expect(render(data[:file], data[:input], context)).to eq(data[:output])
      end
    end
  end

  context 'when rendering takes too long' do
    let_it_be(:file_name) { 'foo.bar' }
    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:context) { { project: project } }
    let_it_be(:text) { +'Noël' }

    before do
      stub_const('Gitlab::OtherMarkup::RENDER_TIMEOUT', 0.1)
      allow(GitHub::Markup).to receive(:render) do
        sleep(0.2)
        text
      end
    end

    it 'times out' do
      # expect 3 times because of timeout in SyntaxHighlightFilter and BlockquoteFenceFilter
      expect(Gitlab::RenderTimeout).to receive(:timeout).exactly(3).times.and_call_original
      expect(Gitlab::ErrorTracking).to receive(:track_exception).with(
        instance_of(Timeout::Error),
        project_id: context[:project].id, file_name: file_name,
        class_name: described_class.name.demodulize
      )

      expect(render(file_name, text, context)).to eq("<p>#{text}</p>")
    end
  end

  def render(...)
    described_class.render(...)
  end
end
