# frozen_string_literal: true

module FeedbackRequests
  # Resolves observed/observer identity bags for MintLink.
  # Observed must be exactly one CompanyTeammate in the org.
  # Observer may be a Person (stub created from email/phone when missing).
  class PartyResolver
    Error = Class.new(StandardError)
    AmbiguousError = Class.new(Error)
    NotFoundError = Class.new(Error)

    def self.resolve_observed!(organization:, attrs:)
      new(organization: organization).resolve_observed!(attrs)
    end

    def self.resolve_observer!(organization:, attrs:, create_stub: true)
      new(organization: organization).resolve_observer!(attrs, create_stub: create_stub)
    end

    def initialize(organization:)
      @organization = organization
    end

    # @return [CompanyTeammate]
    def resolve_observed!(attrs)
      attrs = normalize_attrs(attrs)
      return fail_not_found!('observed is required') if attrs.empty?

      teammates = candidate_teammates(attrs)
      if teammates.size > 1
        raise AmbiguousError, "observed matched #{teammates.size} teammates; pass teammate_id"
      end
      raise NotFoundError, 'observed teammate not found in this organization' if teammates.empty?

      teammates.first
    end

    # @return [Hash] { person:, teammate: CompanyTeammate|nil, created_person: bool }
    def resolve_observer!(attrs, create_stub: true)
      attrs = normalize_attrs(attrs)
      return fail_not_found!('observer is required') if attrs.empty?

      people = candidate_people(attrs)
      if people.size > 1
        raise AmbiguousError, "observer matched #{people.size} people; pass person_id or teammate_id"
      end

      created = false
      person = people.first
      if person.nil?
        raise NotFoundError, 'observer not found' unless create_stub

        person = create_person_stub!(attrs)
        created = true
      end

      teammate = person.company_teammates.find_by(organization_id: @organization.id)
      { person: person, teammate: teammate, created_person: created }
    end

    private

    def normalize_attrs(attrs)
      hash = attrs.respond_to?(:to_unsafe_h) ? attrs.to_unsafe_h : attrs
      hash = {} unless hash.respond_to?(:[])
      {
        teammate_id: present(hash[:teammate_id] || hash['teammate_id']),
        person_id: present(hash[:person_id] || hash['person_id']),
        email: present(hash[:email] || hash['email'])&.to_s&.strip,
        phone: present(hash[:phone] || hash['phone'])&.to_s&.strip
      }.compact
    end

    def present(value)
      value.presence
    end

    def candidate_teammates(attrs)
      scope = CompanyTeammate.where(organization_id: @organization.id)
      matched = []

      if attrs[:teammate_id]
        matched << scope.find_by(id: attrs[:teammate_id])
      end

      if attrs[:person_id]
        matched << scope.find_by(person_id: attrs[:person_id])
      end

      if attrs[:email]
        person = Person.find_by_email_insensitive(attrs[:email])
        matched << scope.find_by(person_id: person.id) if person
      end

      if attrs[:phone]
        person = Person.find_by_textable_phone(attrs[:phone])
        matched << scope.find_by(person_id: person.id) if person
      end

      matched.compact.uniq(&:id)
    end

    def candidate_people(attrs)
      matched = []

      if attrs[:teammate_id]
        tm = CompanyTeammate.find_by(id: attrs[:teammate_id], organization_id: @organization.id)
        matched << tm.person if tm
      end

      if attrs[:person_id]
        matched << Person.find_by(id: attrs[:person_id])
      end

      if attrs[:email]
        matched << Person.find_by_email_insensitive(attrs[:email])
      end

      if attrs[:phone]
        matched << Person.find_by_textable_phone(attrs[:phone])
      end

      matched.compact.uniq(&:id)
    end

    def create_person_stub!(attrs)
      email = attrs[:email].presence
      phone = attrs[:phone].present? ? PhoneNumberNormalizer.call(attrs[:phone]) : nil
      raise NotFoundError, 'observer needs email or phone to create a person stub' if email.blank? && phone.blank?

      local = email.to_s.split('@').first.presence || 'External'
      Person.create!(
        email: email.presence || Person.phone_placeholder_email_for(phone),
        unique_textable_phone_number: phone,
        first_name: local.to_s[0, 40],
        last_name: 'Respondent'
      )
    end

    def fail_not_found!(message)
      raise NotFoundError, message
    end
  end
end
