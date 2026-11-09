# frozen_string_literal: true

module FeedbackRequests
  # Finds or creates a shared system FeedbackRequest for an offer, names the clicker
  # as a respondent, and returns the request ready for the answer flow.
  class AcceptSystemOffer
    Result = Data.define(:ok, :feedback_request, :error) do
      def ok?
        ok
      end
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, subject:, viewer:, offer_key:)
      @organization = organization
      @subject = subject
      @viewer = viewer
      @offer_key = offer_key.to_s
    end

    def call
      return fail_result('Offer is required.') if @offer_key.blank?
      return fail_result('You cannot give yourself feedback this way.') if @viewer.id == @subject.id
      return fail_result('Subject must be in this organization.') unless @subject.organization_id == @organization.id
      return fail_result('Viewer must be in this organization.') unless @viewer.organization_id == @organization.id

      offer = RelevanceOffers.call(viewer: @viewer, subject: @subject).find { |o| o.offer_key == @offer_key }
      return fail_result('That feedback offer is not available.') unless offer
      return fail_result('No focus objects available for that offer yet.') if rateables_for(offer).empty?

      feedback_request = nil
      FeedbackRequest.transaction do
        feedback_request = find_or_create!(offer)
        ensure_named_respondent!(feedback_request)
      end

      Result.new(ok: true, feedback_request: feedback_request, error: nil)
    rescue ActiveRecord::RecordNotUnique
      feedback_request = existing_for(@offer_key)
      ensure_named_respondent!(feedback_request) if feedback_request
      return fail_result('Could not open that feedback request.') unless feedback_request

      Result.new(ok: true, feedback_request: feedback_request, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      fail_result(e.record.errors.full_messages.to_sentence.presence || e.message)
    end

    private

    def find_or_create!(offer)
      existing = existing_for(offer.offer_key)
      return existing if existing

      create_for!(offer)
    end

    def existing_for(offer_key)
      FeedbackRequest.not_deleted.find_by(
        company_id: @organization.id,
        subject_of_feedback_teammate_id: @subject.id,
        system_offer_key: offer_key,
        requestor_teammate_id: nil
      )
    end

    def create_for!(offer)
      fr = FeedbackRequest.new(
        company: @organization,
        requestor_teammate: nil,
        subject_of_feedback_teammate: @subject,
        subject_line: subject_line_for(offer),
        audience: :recipients_only,
        system_offer_key: offer.offer_key
      )
      fr.save!

      build_questions!(fr, offer)
      fr
    end

    def build_questions!(fr, offer)
      position = 0
      rateables_for(offer).each do |rateable|
        position += 1
        question = fr.feedback_request_questions.build(
          position: position,
          rateable: rateable,
          question_text: ''
        )
        question.question_text = question.prompt_default_text.presence || fallback_question_text(rateable)
        question.save!
      end
    end

    def rateables_for(offer)
      case offer.kind
      when 'values'
        Array(offer.primary_object)
      when 'assignment'
        assignment = offer.primary_object
        [assignment] + assignment.abilities.to_a
      when 'ability'
        [offer.primary_object]
      else
        []
      end
    end

    def fallback_question_text(rateable)
      subject_name = @subject.person.casual_name.presence || 'them'
      case rateable
      when Aspiration
        "When I think about my recent experience of #{subject_name} living #{rateable.name}..."
      when Assignment
        "When I think about my recent experience of #{subject_name} being a #{rateable.title}..."
      when Ability
        "When I think about my recent experience of #{subject_name} demonstrating #{rateable.name}..."
      else
        "When I think about my recent experience with #{subject_name}..."
      end
    end

    def subject_line_for(offer)
      name = @subject.person.casual_name.presence || @subject.person.display_name
      case offer.kind
      when 'values'
        "Company values feedback for #{name}"
      when 'assignment'
        "#{offer.primary_object.title} feedback for #{name}"
      when 'ability'
        "#{offer.primary_object.name} feedback for #{name}"
      else
        "Feedback for #{name}"
      end
    end

    def ensure_named_respondent!(feedback_request)
      return if feedback_request.responders.exists?(id: @viewer.id)

      feedback_request.feedback_request_responders.create!(teammate: @viewer)
    end

    def fail_result(message)
      Result.new(ok: false, feedback_request: nil, error: message)
    end
  end
end
