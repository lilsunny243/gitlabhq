# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AbuseReportsFinder, '#execute' do
  let(:params) { {} }
  let!(:user1) { create(:user) }
  let!(:user2) { create(:user) }
  let!(:abuse_report_1) { create(:abuse_report, category: 'spam', user: user1, reporter: user2) }
  let!(:abuse_report_2) { create(:abuse_report, :closed, category: 'phishing', user: user2) }

  subject { described_class.new(params).execute }

  context 'when params is empty' do
    it 'returns all abuse reports' do
      expect(subject).to match_array([abuse_report_1, abuse_report_2])
    end
  end

  context 'when params[:user_id] is present' do
    let(:params) { { user_id: user2 } }

    it 'returns abuse reports for the specified user' do
      expect(subject).to match_array([abuse_report_2])
    end
  end

  context 'when params[:status] is present' do
    context 'when value is "open"' do
      let(:params) { { status: 'open' } }

      it 'returns only open abuse reports' do
        expect(subject).to match_array([abuse_report_1])
      end
    end

    context 'when value is "closed"' do
      let(:params) { { status: 'closed' } }

      it 'returns only closed abuse reports' do
        expect(subject).to match_array([abuse_report_2])
      end
    end
  end

  context 'when params[:category] is present' do
    let(:params) { { category: 'phishing' } }

    it 'returns abuse reports with the specified category' do
      expect(subject).to match_array([abuse_report_2])
    end
  end
end
