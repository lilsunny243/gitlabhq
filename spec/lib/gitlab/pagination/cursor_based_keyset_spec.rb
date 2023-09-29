# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Pagination::CursorBasedKeyset do
  subject { described_class }

  describe '.available_for_type?' do
    context 'with api_keyset_pagination_multi_order FF disabled' do
      before do
        stub_feature_flags(api_keyset_pagination_multi_order: false)
      end

      it 'returns true for Group' do
        expect(subject.available_for_type?(Group.all)).to be_truthy
      end

      it 'returns true for Ci::Build' do
        expect(subject.available_for_type?(Ci::Build.all)).to be_truthy
      end

      it 'returns true for Packages::BuildInfo' do
        expect(subject.available_for_type?(Packages::BuildInfo.all)).to be_truthy
      end

      it 'return false for User' do
        expect(subject.available_for_type?(User.all)).to be_falsey
      end
    end

    context 'with api_keyset_pagination_multi_order FF enabled' do
      before do
        stub_feature_flags(api_keyset_pagination_multi_order: true)
      end

      it 'returns true for Group' do
        expect(subject.available_for_type?(Group.all)).to be_truthy
      end

      it 'returns true for Ci::Build' do
        expect(subject.available_for_type?(Ci::Build.all)).to be_truthy
      end

      it 'returns true for Packages::BuildInfo' do
        expect(subject.available_for_type?(Packages::BuildInfo.all)).to be_truthy
      end

      it 'returns true for User' do
        expect(subject.available_for_type?(User.all)).to be_truthy
      end

      it 'return false for other types of relations' do
        expect(subject.available_for_type?(Issue.all)).to be_falsey
      end
    end
  end

  describe '.enforced_for_type?' do
    subject { described_class.enforced_for_type?(relation) }

    context 'when relation is Group' do
      let(:relation) { Group.all }

      it { is_expected.to be true }
    end

    context 'when relation is AuditEvent' do
      let(:relation) { AuditEvent.all }

      it { is_expected.to be false }
    end

    context 'when relation is Ci::Build' do
      let(:relation) { Ci::Build.all }

      it { is_expected.to be false }
    end
  end

  describe '.available?' do
    let(:request_context) { double('request_context', params: { order_by: order_by, sort: sort }) }
    let(:cursor_based_request_context) { Gitlab::Pagination::Keyset::CursorBasedRequestContext.new(request_context) }

    context 'with order-by name asc' do
      let(:order_by) { :name }
      let(:sort) { :asc }

      it 'returns true for Group' do
        expect(subject.available?(cursor_based_request_context, Group.all)).to be_truthy
      end

      it 'return false for other types of relations' do
        expect(subject.available?(cursor_based_request_context, Issue.all)).to be_falsey
        expect(subject.available?(cursor_based_request_context, Ci::Build.all)).to be_falsey
        expect(subject.available?(cursor_based_request_context, Packages::BuildInfo.all)).to be_falsey
      end
    end

    context 'with order-by id desc' do
      let(:order_by) { :id }
      let(:sort) { :desc }

      context 'with api_keyset_pagination_multi_order FF disabled' do
        before do
          stub_feature_flags(api_keyset_pagination_multi_order: false)
        end

        it 'returns true for Ci::Build' do
          expect(subject.available?(cursor_based_request_context, Ci::Build.all)).to be_truthy
        end

        it 'returns true for AuditEvent' do
          expect(subject.available?(cursor_based_request_context, AuditEvent.all)).to be_truthy
        end

        it 'returns true for Packages::BuildInfo' do
          expect(subject.available?(cursor_based_request_context, Packages::BuildInfo.all)).to be_truthy
        end

        it 'returns false for User' do
          expect(subject.available?(cursor_based_request_context, User.all)).to be_falsey
        end
      end

      context 'with api_keyset_pagination_multi_order FF enabled' do
        before do
          stub_feature_flags(api_keyset_pagination_multi_order: true)
        end

        it 'returns true for Ci::Build' do
          expect(subject.available?(cursor_based_request_context, Ci::Build.all)).to be_truthy
        end

        it 'returns true for AuditEvent' do
          expect(subject.available?(cursor_based_request_context, AuditEvent.all)).to be_truthy
        end

        it 'returns true for Packages::BuildInfo' do
          expect(subject.available?(cursor_based_request_context, Packages::BuildInfo.all)).to be_truthy
        end

        it 'returns true for User' do
          expect(subject.available?(cursor_based_request_context, User.all)).to be_truthy
        end
      end
    end

    context 'with other order-by columns' do
      let(:order_by) { :path }
      let(:sort) { :asc }

      it 'returns false for Group' do
        expect(subject.available?(cursor_based_request_context, Group.all)).to be_falsey
      end

      it 'return false for other types of relations' do
        expect(subject.available?(cursor_based_request_context, Issue.all)).to be_falsey
      end
    end
  end
end
