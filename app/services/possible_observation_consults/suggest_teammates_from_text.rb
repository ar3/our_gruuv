# frozen_string_literal: true

module PossibleObservationConsults
  # Roster name match against paste/upload text — human confirms before consult.
  class SuggestTeammatesFromText
    MIN_TOKEN_LENGTH = 3

    def self.call(organization:, plaintext:)
      new(organization: organization, plaintext: plaintext).call
    end

    def initialize(organization:, plaintext:)
      @organization = organization
      @plaintext = plaintext.to_s
      @haystack = @plaintext.downcase
    end

    def call
      return [] if @haystack.blank?

      org_ids = @organization.self_and_descendants.map(&:id)
      CompanyTeammate
        .where(organization_id: org_ids)
        .includes(:person)
        .find_each
        .select { |tm| mentioned?(tm) }
        .sort_by { |tm| tm.person.casual_name.to_s.downcase }
    end

    private

    def mentioned?(teammate)
      person = teammate.person
      return false unless person

      tokens = [
        person.casual_name,
        person.display_name,
        person.first_name,
        person.preferred_name
      ].compact_blank.map { |t| t.to_s.strip }.uniq

      tokens.any? do |token|
        next false if token.length < MIN_TOKEN_LENGTH

        @haystack.match?(/\b#{Regexp.escape(token.downcase)}\b/)
      end
    end
  end
end
