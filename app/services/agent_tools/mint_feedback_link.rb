# frozen_string_literal: true

module AgentTools
  # Mint (find or create) a Feedback Request answer link for observer → observed + topics.
  class MintFeedbackLink < Base
    def call(
      context:,
      observed: nil,
      observer: nil,
      topics: nil,
      feedback_request_id: nil,
      observed_teammate_id: nil,
      observed_email: nil,
      observed_phone: nil,
      observer_person_id: nil,
      observer_teammate_id: nil,
      observer_email: nil,
      observer_phone: nil,
      **_ignored
    )
      observed_attrs = coerce_party(
        observed,
        teammate_id: observed_teammate_id,
        email: observed_email,
        phone: observed_phone
      )
      observer_attrs = coerce_party(
        observer,
        person_id: observer_person_id,
        teammate_id: observer_teammate_id,
        email: observer_email,
        phone: observer_phone
      )

      return err('observed is required', code: 'validation_failed') if observed_attrs.blank?
      return err('observer is required', code: 'validation_failed') if observer_attrs.blank?

      mint = FeedbackRequests::MintLink.new(
        organization: context.organization,
        acting_teammate: context.company_teammate,
        observed: observed_attrs,
        observer: observer_attrs,
        topics: topics,
        feedback_request_id: feedback_request_id
      )
      result = mint.call
      return err(result.error, code: result.error_code || 'validation_failed') unless result.ok?

      # Same gate as /internal accept_feedback_offer: can view subject's internal page.
      unless CompanyTeammatePolicy.new(context.pundit_user, result.observed).internal?
        return err('Not authorized to mint feedback for that teammate', code: 'not_authorized')
      end

      ok(mint.link_payload(result))
    end

    private

    def coerce_party(value, **flat)
      hash =
        case value
        when ActionController::Parameters
          value.to_unsafe_h.symbolize_keys
        when Hash
          value.to_h.symbolize_keys
        else
          {}
        end
      flat.each { |k, v| hash[k] = v if v.present? }
      hash.compact
    end
  end
end
