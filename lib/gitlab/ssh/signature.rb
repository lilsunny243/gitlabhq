# frozen_string_literal: true

# Signature verification with ed25519 keys
# requires this gem to be loaded.
require 'ed25519'

module Gitlab
  module Ssh
    class Signature
      include Gitlab::Utils::StrongMemoize

      GIT_NAMESPACE = 'git'

      def initialize(signature_text, signed_text, signer, committer_email)
        @signature_text = signature_text
        @signed_text = signed_text
        @signer = signer
        @committer_email = committer_email
      end

      def verification_status
        strong_memoize(:verification_status) do
          next :unverified unless all_attributes_present?
          next :verified_system if verified_by_gitlab?
          next :unverified unless valid_signature_blob?
          next :unknown_key unless signed_by_key
          next :other_user unless committer
          next :other_user unless signed_by_key.user == committer

          if signed_by_user_email_verified?
            :verified
          else
            :unverified
          end
        end
      end

      def signed_by_key
        strong_memoize(:signed_by_key) do
          next unless key_fingerprint

          Key.signing.find_by_fingerprint_sha256(key_fingerprint)
        end
      end

      def key_fingerprint
        strong_memoize(:key_fingerprint) { signature&.public_key&.fingerprint }
      end

      private

      def all_attributes_present?
        # Signing an empty string is valid, but signature_text and committer_email
        # must be non-empty.
        @signed_text && @signature_text.present? && @committer_email.present?
      end

      # Verifies the signature using the public key embedded in the blob.
      # This proves that the signed_text was signed by the private key
      # of the public key identified by `key_fingerprint`. Afterwards, we
      # still need to check that the key belongs to the committer.
      def valid_signature_blob?
        return false unless signature
        return false unless signature.namespace == GIT_NAMESPACE

        signature.verify(@signed_text)
      end

      def committer
        # Lookup by email because users can push verified commits that were made
        # by someone else. For example: Doing a rebase.
        strong_memoize(:committer) { User.find_by_any_email(@committer_email) }
      end

      def signed_by_user_email_verified?
        signed_by_key.user.verified_emails.include?(@committer_email)
      end

      def signature
        strong_memoize(:signature) do
          ::SSHData::Signature.parse_pem(@signature_text)
        rescue SSHData::DecodeError
          nil
        end
      end

      # If a commit is signed by Gitaly, the Gitaly returns `SIGNER_SYSTEM` as a signer
      # In order to calculate it, the signature is Verified using the Gitaly's public key:
      # https://gitlab.com/gitlab-org/gitaly/-/blob/v16.2.0-rc2/internal/gitaly/service/commit/commit_signatures.go#L63
      #
      # It is safe to skip verification step if the commit has been signed by Gitaly
      def verified_by_gitlab?
        @signer == :SIGNER_SYSTEM
      end
    end
  end
end
