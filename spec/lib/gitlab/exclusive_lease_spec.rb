# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ExclusiveLease, :request_store, :clean_gitlab_redis_shared_state,
  :clean_gitlab_redis_cluster_shared_state, feature_category: :shared do
  let(:unique_key) { SecureRandom.hex(10) }

  describe '#try_obtain' do
    it 'cannot obtain twice before the lease has expired' do
      lease = described_class.new(unique_key, timeout: 3600)
      expect(lease.try_obtain).to be_present
      expect(lease.try_obtain).to eq(false)
    end

    it 'can obtain after the lease has expired' do
      timeout = 1
      lease = described_class.new(unique_key, timeout: timeout)
      lease.try_obtain # start the lease
      sleep(2 * timeout) # lease should have expired now
      expect(lease.try_obtain).to be_present
    end

    context 'when migrating across stores' do
      let(:lease) { described_class.new(unique_key, timeout: 3600) }

      before do
        stub_feature_flags(use_cluster_shared_state_for_exclusive_lease: false)
        allow(lease).to receive(:same_store).and_return(false)
      end

      it 'acquires 2 locks' do
        # stub first SETNX
        Gitlab::Redis::SharedState.with { |r| expect(r).to receive(:set).and_return(true) }
        Gitlab::Redis::ClusterSharedState.with { |r| expect(r).to receive(:set).and_call_original }

        expect(lease.try_obtain).to be_truthy
      end

      it 'rollback first lock if second lock is not acquired' do
        Gitlab::Redis::ClusterSharedState.with do |r|
          expect(r).to receive(:set).and_return(false)
          expect(r).to receive(:eval).and_call_original
        end

        Gitlab::Redis::SharedState.with do |r|
          expect(r).to receive(:set).and_call_original
          expect(r).to receive(:eval).and_call_original
        end

        expect(lease.try_obtain).to be_falsey
      end
    end

    context 'when cutting over to ClusterSharedState' do
      context 'when lock is not acquired' do
        it 'waits for existing holder to yield the lock' do
          Gitlab::Redis::ClusterSharedState.with { |r| expect(r).to receive(:set).and_call_original }
          Gitlab::Redis::SharedState.with { |r| expect(r).not_to receive(:set) }

          lease = described_class.new(unique_key, timeout: 3600)
          expect(lease.try_obtain).to be_truthy
        end
      end

      context 'when lock is still acquired' do
        let(:lease) { described_class.new(unique_key, timeout: 3600) }

        before do
          # simulates cutover where some application's feature-flag has not updated
          stub_feature_flags(use_cluster_shared_state_for_exclusive_lease: false)
          lease.try_obtain
          stub_feature_flags(use_cluster_shared_state_for_exclusive_lease: true)
        end

        it 'waits for existing holder to yield the lock' do
          Gitlab::Redis::ClusterSharedState.with { |r| expect(r).not_to receive(:set) }
          Gitlab::Redis::SharedState.with { |r| expect(r).not_to receive(:set) }

          expect(lease.try_obtain).to be_falsey
        end
      end
    end
  end

  describe '.redis_shared_state_key' do
    it 'provides a namespaced key' do
      expect(described_class.redis_shared_state_key(unique_key))
        .to start_with(described_class::PREFIX)
        .and include(unique_key)
    end
  end

  describe '.ensure_prefixed_key' do
    it 'does not double prefix a key' do
      prefixed = described_class.redis_shared_state_key(unique_key)

      expect(described_class.ensure_prefixed_key(unique_key))
        .to eq(described_class.ensure_prefixed_key(prefixed))
    end

    it 'raises errors when there is no key' do
      expect { described_class.ensure_prefixed_key(nil) }.to raise_error(described_class::NoKey)
    end
  end

  shared_examples 'write operations' do
    describe '#renew' do
      it 'returns true when we have the existing lease' do
        lease = described_class.new(unique_key, timeout: 3600)
        expect(lease.try_obtain).to be_present
        expect(lease.renew).to be_truthy
      end

      it 'returns false when we dont have a lease' do
        lease = described_class.new(unique_key, timeout: 3600)
        expect(lease.renew).to be_falsey
      end
    end

    describe 'cancellation' do
      def new_lease(key)
        described_class.new(key, timeout: 3600)
      end

      shared_examples 'cancelling a lease' do
        let(:lease) { new_lease(unique_key) }

        it 'releases the held lease' do
          uuid = lease.try_obtain
          expect(uuid).to be_present
          expect(new_lease(unique_key).try_obtain).to eq(false)

          cancel_lease(uuid)

          expect(new_lease(unique_key).try_obtain).to be_present
        end
      end

      describe '.cancel' do
        def cancel_lease(uuid)
          described_class.cancel(release_key, uuid)
        end

        context 'when called with the unprefixed key' do
          it_behaves_like 'cancelling a lease' do
            let(:release_key) { unique_key }
          end
        end

        context 'when called with the prefixed key' do
          it_behaves_like 'cancelling a lease' do
            let(:release_key) { described_class.redis_shared_state_key(unique_key) }
          end
        end

        it 'does not raise errors when given a nil key' do
          expect { described_class.cancel(nil, nil) }.not_to raise_error
        end
      end

      describe '#cancel' do
        def cancel_lease(_uuid)
          lease.cancel
        end

        it_behaves_like 'cancelling a lease'

        it 'is safe to call even if the lease was never obtained' do
          lease = new_lease(unique_key)

          lease.cancel

          expect(new_lease(unique_key).try_obtain).to be_present
        end
      end
    end

    describe '.reset_all!' do
      it 'removes all existing lease keys from redis' do
        uuid = described_class.new(unique_key, timeout: 3600).try_obtain

        expect(described_class.get_uuid(unique_key)).to eq(uuid)

        described_class.reset_all!

        expect(described_class.get_uuid(unique_key)).to be_falsey
      end
    end
  end

  shared_examples 'read operations' do
    describe '#exists?' do
      it 'returns true for an existing lease' do
        lease = described_class.new(unique_key, timeout: 3600)
        lease.try_obtain

        expect(lease.exists?).to eq(true)
      end

      it 'returns false for a lease that does not exist' do
        lease = described_class.new(unique_key, timeout: 3600)

        expect(lease.exists?).to eq(false)
      end
    end

    describe '.get_uuid' do
      it 'gets the uuid if lease with the key associated exists' do
        uuid = described_class.new(unique_key, timeout: 3600).try_obtain

        expect(described_class.get_uuid(unique_key)).to eq(uuid)
      end

      it 'returns false if the lease does not exist' do
        expect(described_class.get_uuid(unique_key)).to be false
      end
    end

    describe '#ttl' do
      it 'returns the TTL of the Redis key' do
        lease = described_class.new('kittens', timeout: 100)
        lease.try_obtain

        expect(lease.ttl <= 100).to eq(true)
      end

      it 'returns nil when the lease does not exist' do
        lease = described_class.new('kittens', timeout: 10)

        expect(lease.ttl).to be_nil
      end
    end
  end

  context 'when migrating across stores' do
    before do
      stub_feature_flags(use_cluster_shared_state_for_exclusive_lease: false)
    end

    it_behaves_like 'read operations'
    it_behaves_like 'write operations'
  end

  context 'when feature flags are all disabled' do
    before do
      stub_feature_flags(
        use_cluster_shared_state_for_exclusive_lease: false,
        enable_exclusive_lease_double_lock_rw: false
      )
    end

    it_behaves_like 'read operations'
    it_behaves_like 'write operations'
  end

  it_behaves_like 'read operations'
  it_behaves_like 'write operations'

  describe '.throttle' do
    it 'prevents repeated execution of the block' do
      number = 0

      action = -> { described_class.throttle(1) { number += 1 } }

      action.call
      action.call

      expect(number).to eq 1
    end

    it 'is distinct by block' do
      number = 0

      described_class.throttle(1) { number += 1 }
      described_class.throttle(1) { number += 1 }

      expect(number).to eq 2
    end

    it 'is distinct by key' do
      number = 0

      action = ->(k) { described_class.throttle(k) { number += 1 } }

      action.call(:a)
      action.call(:b)
      action.call(:a)

      expect(number).to eq 2
    end

    it 'allows a group to be passed' do
      number = 0

      described_class.throttle(1, group: :a) { number += 1 }
      described_class.throttle(1, group: :b) { number += 1 }
      described_class.throttle(1, group: :a) { number += 1 }
      described_class.throttle(1, group: :b) { number += 1 }

      expect(number).to eq 2
    end

    it 'defaults to a 60min timeout' do
      expect(described_class).to receive(:new).with(anything, hash_including(timeout: 1.hour.to_i)).and_call_original

      described_class.throttle(1) {}
    end

    it 'allows count to be specified' do
      expect(described_class)
        .to receive(:new)
        .with(anything, hash_including(timeout: 15.minutes.to_i))
        .and_call_original

      described_class.throttle(1, count: 4) {}
    end

    it 'allows period to be specified' do
      expect(described_class)
        .to receive(:new)
        .with(anything, hash_including(timeout: 1.day.to_i))
        .and_call_original

      described_class.throttle(1, period: 1.day) {}
    end

    it 'allows period and count to be specified' do
      expect(described_class)
        .to receive(:new)
        .with(anything, hash_including(timeout: 30.minutes.to_i))
        .and_call_original

      described_class.throttle(1, count: 48, period: 1.day) {}
    end
  end

  describe 'transitions between feature-flag toggles' do
    shared_examples 'retains behaviours across transitions' do |flag|
      it 'retains read behaviour' do
        lease = described_class.new(unique_key, timeout: 3600)
        uuid = lease.try_obtain

        expect(lease.ttl).not_to eq(nil)
        expect(lease.exists?).to be_truthy
        expect(described_class.get_uuid(unique_key)).to eq(uuid)

        # simulates transition
        stub_feature_flags({ flag => true })

        expect(lease.ttl).not_to eq(nil)
        expect(lease.exists?).to be_truthy
        expect(described_class.get_uuid(unique_key)).to eq(uuid)
      end

      it 'retains renew behaviour' do
        lease = described_class.new(unique_key, timeout: 3600)
        lease.try_obtain

        expect(lease.renew).to be_truthy

        # simulates transition
        stub_feature_flags({ flag => true })

        expect(lease.renew).to be_truthy
      end

      it 'retains cancel behaviour' do
        lease = described_class.new(unique_key, timeout: 3600)
        uuid = lease.try_obtain
        lease.cancel

        # proves successful cancellation
        expect(lease.try_obtain).to eq(uuid)

        # simulates transition
        stub_feature_flags({ flag => true })

        expect(lease.try_obtain).to be_falsey
        lease.cancel
        expect(lease.try_obtain).to eq(uuid)
      end
    end

    context 'when enabling enable_exclusive_lease_double_lock_rw' do
      before do
        stub_feature_flags(
          enable_exclusive_lease_double_lock_rw: false,
          use_cluster_shared_state_for_exclusive_lease: false
        )
      end

      it_behaves_like 'retains behaviours across transitions', :enable_exclusive_lease_double_lock_rw
    end

    context 'when enabling use_cluster_shared_state_for_exclusive_lease' do
      before do
        stub_feature_flags(use_cluster_shared_state_for_exclusive_lease: false)
      end

      it_behaves_like 'retains behaviours across transitions', :use_cluster_shared_state_for_exclusive_lease
    end
  end

  describe 'using current_request actor' do
    shared_context 'when double lock is enabled for the current request' do
      before do
        stub_feature_flags(
          enable_exclusive_lease_double_lock_rw: Feature.current_request,
          use_cluster_shared_state_for_exclusive_lease: false
        )
      end
    end

    shared_context 'when cutting over to ClusterSharedState for the current request' do
      before do
        stub_feature_flags(
          enable_exclusive_lease_double_lock_rw: true,
          use_cluster_shared_state_for_exclusive_lease: Feature.current_request
        )
      end
    end

    describe '#try_obtain' do
      let(:lease) { described_class.new(unique_key, timeout: 3600) }

      shared_examples 'acquires both locks' do
        it do
          Gitlab::Redis::SharedState.with { |r| expect(r).to receive(:set).and_call_original }
          Gitlab::Redis::ClusterSharedState.with { |r| expect(r).to receive(:set).and_call_original }

          expect(lease.try_obtain).to be_truthy
        end
      end

      shared_examples 'only acquires one lock' do
        it do
          used_store.with { |r| expect(r).to receive(:set).and_call_original }
          unused_store.with { |r| expect(r).not_to receive(:set) }

          expect(lease.try_obtain).to be_truthy
        end
      end

      context 'when double lock is enabled for the current request' do
        include_context 'when double lock is enabled for the current request'
        it_behaves_like 'acquires both locks'

        context 'for a different request' do
          before do
            stub_with_new_feature_current_request
          end

          let(:used_store) { Gitlab::Redis::SharedState }
          let(:unused_store) { Gitlab::Redis::ClusterSharedState }

          it_behaves_like 'only acquires one lock'
        end
      end

      context 'when cutting over to ClusterSharedState for the current request' do
        include_context 'when cutting over to ClusterSharedState for the current request'

        let(:used_store) { Gitlab::Redis::ClusterSharedState }
        let(:unused_store) { Gitlab::Redis::SharedState }

        it_behaves_like 'only acquires one lock'

        context 'for a different request' do
          before do
            stub_with_new_feature_current_request
          end

          it_behaves_like 'acquires both locks'
        end
      end
    end

    describe '.with_write_redis' do
      shared_examples 'writes to both stores in order' do
        it do
          first_store.with { |r| expect(r).to receive(:eval).ordered }
          second_store.with { |r| expect(r).to receive(:eval).ordered }

          described_class.with_write_redis { |r| r.eval(described_class::LUA_CANCEL_SCRIPT) }
        end
      end

      shared_examples 'only writes to one store' do
        it do
          used_store.with { |r| expect(r).to receive(:eval) }
          unused_store.with { |r| expect(r).not_to receive(:eval) }

          described_class.with_write_redis { |r| r.eval(described_class::LUA_CANCEL_SCRIPT) }
        end
      end

      context 'when double lock is enabled for the current request' do
        include_context 'when double lock is enabled for the current request'
        let(:first_store) { Gitlab::Redis::SharedState }
        let(:second_store) { Gitlab::Redis::ClusterSharedState }

        it_behaves_like 'writes to both stores in order'

        context 'for a different request' do
          before do
            stub_with_new_feature_current_request
          end

          let(:used_store) { Gitlab::Redis::SharedState }
          let(:unused_store) { Gitlab::Redis::ClusterSharedState }

          it_behaves_like 'only writes to one store'
        end
      end

      context 'when cutting over to ClusterSharedState for the current request' do
        include_context 'when cutting over to ClusterSharedState for the current request'
        let(:first_store) { Gitlab::Redis::ClusterSharedState }
        let(:second_store) { Gitlab::Redis::SharedState }

        it_behaves_like 'writes to both stores in order'

        context 'for a different request' do
          before do
            stub_with_new_feature_current_request
          end

          let(:first_store) { Gitlab::Redis::SharedState }
          let(:second_store) { Gitlab::Redis::ClusterSharedState }

          it_behaves_like 'writes to both stores in order'
        end
      end
    end

    describe '.with_read_redis' do
      shared_examples 'reads from both stores' do
        it do
          Gitlab::Redis::SharedState.with { |r| expect(r).to receive(:get) }
          Gitlab::Redis::ClusterSharedState.with { |r| expect(r).to receive(:get) }

          described_class.with_read_redis { |r| r.get(described_class.redis_shared_state_key("foobar")) }
        end
      end

      shared_examples 'only reads from one store' do
        it do
          used_store.with { |r| expect(r).to receive(:get) }
          unused_store.with { |r| expect(r).not_to receive(:get) }

          described_class.with_read_redis { |r| r.get(described_class.redis_shared_state_key("foobar")) }
        end
      end

      context 'when double lock is enabled for the current request' do
        include_context 'when double lock is enabled for the current request'
        it_behaves_like 'reads from both stores'

        context 'for a different request' do
          before do
            stub_with_new_feature_current_request
          end

          let(:used_store) { Gitlab::Redis::SharedState }
          let(:unused_store) { Gitlab::Redis::ClusterSharedState }

          it_behaves_like 'only reads from one store'
        end
      end

      context 'when cutting over to ClusterSharedState for the current request' do
        include_context 'when cutting over to ClusterSharedState for the current request'
        let(:used_store) { Gitlab::Redis::ClusterSharedState }
        let(:unused_store) { Gitlab::Redis::SharedState }

        it_behaves_like 'only reads from one store'

        context 'for a different request' do
          before do
            stub_with_new_feature_current_request
          end

          it_behaves_like 'reads from both stores'
        end
      end
    end
  end
end
