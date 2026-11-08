# frozen_string_literal: true

module FeedbackRequests
  # Builds relevance feedback offers for a viewer looking at a subject's /internal page.
  # Offers are computed only — FeedbackRequest rows are created on click.
  class RelevanceOffers
    Offer = Data.define(
      :kind,           # 'values' | 'assignment' | 'ability'
      :offer_key,      # stable find-or-create key
      :label,          # button / list label
      :description,    # short why-this-is-relevant copy
      :primary_object, # Aspiration collection / Assignment / Ability (or nil)
      :score           # higher = more relevant (for ordering)
    )

    MAX_ASSIGNMENT_OFFERS = 2
    MAX_ABILITY_OFFERS = 2

    def self.call(viewer:, subject:)
      new(viewer: viewer, subject: subject).call
    end

    def initialize(viewer:, subject:)
      @viewer = viewer
      @subject = subject
      @organization = subject.organization
    end

    def call
      offers = []
      offers << values_offer
      offers.concat(assignment_offers)
      offers.concat(ability_offers)
      offers
    end

    private

    attr_reader :viewer, :subject, :organization

    def values_offer
      values = company_values
      Offer.new(
        kind: 'values',
        offer_key: 'values',
        label: "Give #{casual(subject)} feedback about company values",
        description: values.any? ? "#{values.size} #{'value'.pluralize(values.size)}" : 'Company values',
        primary_object: values,
        score: 0
      )
    end

    def company_values
      scope = Aspiration.for_company(organization).ordered
      company_level = scope.select(&:company_level_aspirational_value?)
      company_level.presence || scope.to_a
    end

    def assignment_offers
      pairs = []
      subject_assignments = subject.active_assignments.includes(
        :assignment_abilities,
        :abilities,
        supplier_supply_relationships: :consumer_assignment
      )
      viewer_assignment_ids = viewer.active_assignments.pluck(:id).to_set

      subject_assignments.each do |supplier|
        supplier.consumer_assignments.each do |consumer|
          next unless viewer_assignment_ids.include?(consumer.id)

          energy = subject_energy_for(supplier)
          pairs << {
            assignment: supplier,
            score: energy.to_i,
            consumer_title: consumer.title
          }
        end
      end

      pairs
        .uniq { |row| row[:assignment].id }
        .sort_by { |row| [-row[:score], row[:assignment].title.to_s] }
        .first(MAX_ASSIGNMENT_OFFERS)
        .map do |row|
          assignment = row[:assignment]
          Offer.new(
            kind: 'assignment',
            offer_key: "assignment:#{assignment.id}",
            label: "Give feedback on #{assignment.title}",
            description: "Your #{row[:consumer_title]} benefits from #{casual(subject)}'s #{assignment.title}",
            primary_object: assignment,
            score: row[:score]
          )
        end
    end

    def ability_offers
      required = required_ability_rows
      return [] if required.empty?

      scored = required.filter_map do |row|
        ability = row[:ability]
        subject_level = subject.highest_milestone_for_ability(ability).to_i
        viewer_level = viewer.highest_milestone_for_ability(ability).to_i
        next if viewer_level <= subject_level

        {
          ability: ability,
          score: viewer_level - subject_level,
          viewer_level: viewer_level,
          subject_level: subject_level
        }
      end

      scored
        .uniq { |row| row[:ability].id }
        .sort_by { |row| [-row[:score], -row[:viewer_level], row[:ability].name.to_s] }
        .first(MAX_ABILITY_OFFERS)
        .map do |row|
          ability = row[:ability]
          Offer.new(
            kind: 'ability',
            offer_key: "ability:#{ability.id}",
            label: "Give feedback on #{ability.name}",
            description: "You're at milestone #{row[:viewer_level]}; #{casual(subject)} is at #{row[:subject_level]} and needs this ability",
            primary_object: ability,
            score: row[:score]
          )
        end
    end

    def required_ability_rows
      subject.active_assignments.includes(assignment_abilities: :ability).flat_map do |assignment|
        assignment.assignment_abilities.map do |aa|
          { ability: aa.ability, required_level: aa.milestone_level }
        end
      end
    end

    def subject_energy_for(assignment)
      subject.assignment_tenures.active.where(assignment: assignment).maximum(:anticipated_energy_percentage)
    end

    def casual(teammate)
      teammate.person.casual_name.presence || teammate.person.display_name
    end
  end
end
