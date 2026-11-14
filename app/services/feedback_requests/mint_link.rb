# frozen_string_literal: true

module FeedbackRequests
  # Find or create a Feedback Request for observer → observed + topics, return answer links.
  # Teammate observers → org answer URL (AcceptSystemOffer).
  # Never-hired observers → open_to_public + /f/:token (Person stub allowed).
  class MintLink
    include Rails.application.routes.url_helpers

    Result = Data.define(
      :ok?, :feedback_request, :created, :error, :error_code,
      :observed, :observer_person, :observer_teammate, :created_person
    )

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(organization:, acting_teammate:, observed:, observer:, topics: nil, feedback_request_id: nil)
      @organization = organization
      @acting_teammate = acting_teammate
      @observed_attrs = observed
      @observer_attrs = observer
      @topics = topics
      @feedback_request_id = feedback_request_id
    end

    def call
      return fail_result('Organization is required', code: 'validation_failed') if @organization.blank?
      return fail_result('Acting teammate is required', code: 'not_authorized') if @acting_teammate.blank?

      observed = PartyResolver.resolve_observed!(organization: @organization, attrs: @observed_attrs)
      observer = PartyResolver.resolve_observer!(organization: @organization, attrs: @observer_attrs)
      observer_person = observer[:person]
      observer_teammate = observer[:teammate]

      if observer_teammate && observer_teammate.id == observed.id
        return fail_result('Observer cannot be the same teammate as observed', code: 'validation_failed')
      end

      created = false
      feedback_request =
        if @feedback_request_id.present?
          find_existing_fr!(@feedback_request_id)
        elsif (by_name = find_fr_by_subject_line)
          by_name
        elsif observer_teammate
          offer_key = resolve_offer_key!(viewer: observer_teammate, subject: observed)
          existed = system_offer_exists?(subject: observed, offer_key: offer_key)
          accept = AcceptSystemOffer.call(
            organization: @organization,
            subject: observed,
            viewer: observer_teammate,
            offer_key: offer_key
          )
          return fail_result(accept.error, code: 'validation_failed') unless accept.ok?

          created = !existed
          accept.feedback_request
        else
          offer_key = resolve_offer_key!(viewer: @acting_teammate, subject: observed, allow_forced: true)
          fr, created = find_or_create_public_system_offer!(subject: observed, offer_key: offer_key)
          fr
        end

      if observer_teammate.nil? && !feedback_request.open_to_public?
        feedback_request.update!(audience: :open_to_public)
      end

      if observer_teammate && feedback_request.recipients_only?
        unless feedback_request.responders.exists?(id: observer_teammate.id)
          feedback_request.feedback_request_responders.create!(teammate: observer_teammate)
        end
      end

      Result.new(
        ok?: true,
        feedback_request: feedback_request,
        created: created,
        error: nil,
        error_code: nil,
        observed: observed,
        observer_person: observer_person,
        observer_teammate: observer_teammate,
        created_person: observer[:created_person]
      )
    rescue PartyResolver::AmbiguousError => e
      fail_result(e.message, code: 'ambiguous')
    rescue PartyResolver::NotFoundError => e
      fail_result(e.message, code: 'not_found')
    rescue ArgumentError => e
      fail_result(e.message, code: 'validation_failed')
    rescue ActiveRecord::RecordInvalid => e
      fail_result(e.record.errors.full_messages.to_sentence, code: 'validation_failed')
    end

    def link_payload(result)
      fr = result.feedback_request
      payload = {
        feedback_request_id: fr.id,
        created: result.created,
        created_person: result.created_person,
        system_offer_key: fr.system_offer_key,
        audience: fr.audience,
        subject_line: fr.subject_line,
        observed: {
          teammate_id: result.observed.id,
          person_id: result.observed.person_id,
          name: result.observed.person.display_name
        },
        observer: {
          person_id: result.observer_person.id,
          teammate_id: result.observer_teammate&.id,
          name: result.observer_person.display_name,
          external: result.observer_teammate.nil?
        },
        answer_path: answer_organization_feedback_request_path(@organization, fr),
        answer_url: absolute_url(answer_organization_feedback_request_url(@organization, fr))
      }
      if fr.open_to_public?
        payload[:public_answer_path] = public_feedback_request_path(fr.public_answer_token)
        payload[:public_answer_url] = absolute_url(public_feedback_request_url(fr.public_answer_token))
      end
      payload
    end

    private

    def find_existing_fr!(id)
      fr = FeedbackRequest.not_deleted.find_by(id: id, company_id: @organization.id)
      raise ArgumentError, 'feedback_request_id not found in this organization' unless fr

      fr
    end

    def find_fr_by_subject_line
      name = topic_subject_line
      return nil if name.blank?

      FeedbackRequest.not_deleted.find_by(
        company_id: @organization.id,
        subject_line: name
      )
    end

    def topic_subject_line
      case @topics
      when String
        @topics.strip.presence
      when Hash
        (@topics[:subject_line] || @topics['subject_line'] || @topics[:name] || @topics['name']).to_s.strip.presence
      end
    end

    def resolve_offer_key!(viewer:, subject:, allow_forced: false)
      key = explicit_offer_key
      if key.present?
        offers = RelevanceOffers.call(viewer: viewer, subject: subject)
        return key if offers.any? { |o| o.offer_key == key }
        return key if allow_forced && forced_offer_viable?(key, subject)

        raise ArgumentError, "topics offer_key #{key.inspect} is not available for this pair"
      end

      objects_key = offer_key_from_objects(subject)
      return objects_key if objects_key

      string_key = offer_key_from_topic_strings(viewer: viewer, subject: subject)
      return string_key if string_key

      offers = RelevanceOffers.call(viewer: viewer, subject: subject)
      best = offers.max_by(&:score)
      return best.offer_key if best

      'values'
    end

    def explicit_offer_key
      case @topics
      when String
        s = @topics.strip
        return s if s.match?(/\A(values|assignment:\d+|ability:\d+)\z/)
      when Hash
        (@topics[:offer_key] || @topics['offer_key']).presence
      end
      nil
    end

    def offer_key_from_objects(subject)
      list = topic_objects
      return nil if list.blank?

      first = list.first
      type = (first[:object_type] || first['object_type'] || first[:type] || first['type']).to_s
      id = first[:object_id] || first['object_id'] || first[:id] || first['id']
      case type
      when 'Assignment', 'assignment'
        assignment = Assignment.find_by(id: id, company_id: @organization.id)
        raise ArgumentError, 'Assignment topic not found' unless assignment

        "assignment:#{assignment.id}"
      when 'Ability', 'ability'
        ability = Ability.find_by(id: id, company_id: @organization.id)
        raise ArgumentError, 'Ability topic not found' unless ability

        "ability:#{ability.id}"
      when 'Aspiration', 'aspiration', 'Value', 'value', 'values'
        'values'
      else
        raise ArgumentError, "Unsupported topic object_type #{type.inspect}"
      end
    end

    def topic_objects
      case @topics
      when Array
        @topics
      when Hash
        objs = @topics[:objects] || @topics['objects']
        objs if objs.is_a?(Array)
      end
    end

    def offer_key_from_topic_strings(viewer:, subject:)
      strings = topic_strings
      return nil if strings.blank?

      joined = strings.map { |s| s.to_s.downcase }
      return 'values' if joined.any? { |s| s.match?(/\bvalues?\b|\baspirations?\b/) }

      offers = RelevanceOffers.call(viewer: viewer, subject: subject)
      offers.each do |offer|
        label = "#{offer.label} #{offer.description} #{offer.offer_key}".downcase
        return offer.offer_key if joined.any? { |s| label.include?(s) || s.include?(offer.offer_key) }
      end

      assignment = Assignment.where(company_id: @organization.id).find do |a|
        joined.any? { |s| a.title.to_s.downcase.include?(s) || s.include?(a.title.to_s.downcase) }
      end
      return "assignment:#{assignment.id}" if assignment

      ability = Ability.where(company_id: @organization.id).find do |a|
        joined.any? { |s| a.name.to_s.downcase.include?(s) || s.include?(a.name.to_s.downcase) }
      end
      return "ability:#{ability.id}" if ability

      nil
    end

    def topic_strings
      case @topics
      when Array
        @topics.select { |t| t.is_a?(String) }
      when Hash
        raw = @topics[:topics] || @topics['topics'] || @topics[:topic] || @topics['topic']
        Array(raw).select { |t| t.is_a?(String) }
      when String
        explicit_offer_key ? [] : [@topics]
      else
        []
      end
    end

    def forced_offer_viable?(key, subject)
      case key
      when 'values'
        Aspiration.for_company(@organization).exists?
      when /\Aassignment:(\d+)\z/
        Assignment.exists?(id: Regexp.last_match(1), company_id: @organization.id)
      when /\Aability:(\d+)\z/
        Ability.exists?(id: Regexp.last_match(1), company_id: @organization.id)
      else
        false
      end
    end

    def system_offer_exists?(subject:, offer_key:)
      FeedbackRequest.not_deleted.exists?(
        company_id: @organization.id,
        subject_of_feedback_teammate_id: subject.id,
        system_offer_key: offer_key,
        requestor_teammate_id: nil
      )
    end

    def find_or_create_public_system_offer!(subject:, offer_key:)
      existing = FeedbackRequest.not_deleted.find_by(
        company_id: @organization.id,
        subject_of_feedback_teammate_id: subject.id,
        system_offer_key: offer_key,
        requestor_teammate_id: nil
      )
      if existing
        existing.update!(audience: :open_to_public) unless existing.open_to_public?
        return [existing, false]
      end

      # Prefer AcceptSystemOffer when the offer is valid for the acting teammate,
      # then open it to the public for the external observer.
      accept = AcceptSystemOffer.call(
        organization: @organization,
        subject: subject,
        viewer: @acting_teammate,
        offer_key: offer_key
      )
      if accept.ok?
        fr = accept.feedback_request
        fr.update!(audience: :open_to_public)
        return [fr, true]
      end

      [create_forced_system_offer!(subject: subject, offer_key: offer_key), true]
    end

    def create_forced_system_offer!(subject:, offer_key:)
      kind, rateables = rateables_for_forced_key(offer_key)
      raise ArgumentError, "Cannot build questions for #{offer_key}" if rateables.empty?

      fr = FeedbackRequest.new(
        company: @organization,
        requestor_teammate: nil,
        subject_of_feedback_teammate: subject,
        subject_line: forced_subject_line(subject, kind, rateables.first),
        audience: :open_to_public,
        system_offer_key: offer_key
      )
      fr.save!

      rateables.each_with_index do |rateable, index|
        question = fr.feedback_request_questions.build(
          position: index + 1,
          rateable: rateable,
          question_text: ''
        )
        question.question_text = question.prompt_default_text.presence ||
                                 "When I think about my recent experience with #{subject.person.casual_name}..."
        question.save!
      end
      fr
    end

    def rateables_for_forced_key(offer_key)
      case offer_key
      when 'values'
        values = Aspiration.for_company(@organization).ordered.select(&:company_level_aspirational_value?)
        values = Aspiration.for_company(@organization).ordered.to_a if values.empty?
        ['values', values]
      when /\Aassignment:(\d+)\z/
        assignment = Assignment.find_by!(id: Regexp.last_match(1), company_id: @organization.id)
        ['assignment', [assignment] + assignment.abilities.to_a]
      when /\Aability:(\d+)\z/
        ability = Ability.find_by!(id: Regexp.last_match(1), company_id: @organization.id)
        ['ability', [ability]]
      else
        [nil, []]
      end
    end

    def forced_subject_line(subject, kind, primary)
      name = subject.person.casual_name.presence || subject.person.display_name
      case kind
      when 'values' then "Company values feedback for #{name}"
      when 'assignment' then "#{primary.title} feedback for #{name}"
      when 'ability' then "#{primary.name} feedback for #{name}"
      else "Feedback for #{name}"
      end
    end

    def absolute_url(url)
      url.to_s
    end

    def fail_result(message, code:)
      Result.new(
        ok?: false,
        feedback_request: nil,
        created: false,
        error: message,
        error_code: code,
        observed: nil,
        observer_person: nil,
        observer_teammate: nil,
        created_person: false
      )
    end
  end
end
