# frozen_string_literal: true

module MaapCleanupInbox
  # Org-wide MAAP cleanup inbox: mismatches and gaps that keep a MAAP from being "clean".
  # Counts always; item rows only for expanded subtypes.
  class Builder
    Action = Data.define(:label, :url)
    Item = Data.define(
      :id,
      :subtype_key,
      :teammate_id,
      :person_name,
      :title,
      :subtitle,
      :actions
    )
    SubtypeSummary = Data.define(:key, :label, :count, :items, :expanded)
    Section = Data.define(:key, :label, :subtypes)

    SECTION_DEFS = [
      { key: :submitted_maap_proposals, label: "Submitted MAAP proposals" },
      { key: :seat_position_alignment, label: "Seat ↔ Position Alignment" }
    ].freeze

    def self.call(organization:, expanded_subtype_keys: [], routes: Rails.application.routes.url_helpers)
      new(
        organization: organization,
        expanded_subtype_keys: expanded_subtype_keys,
        routes: routes
      ).call
    end

    def initialize(organization:, expanded_subtype_keys:, routes:)
      @organization = organization
      @expanded = Array(expanded_subtype_keys).map(&:to_s).to_set
      @routes = routes
    end

    def call
      SECTION_DEFS.map { |defn| build_section(defn) }
    end

    private

    attr_reader :organization, :expanded, :routes

    def build_section(defn)
      Section.new(
        key: defn[:key],
        label: defn[:label],
        subtypes: send(:"#{defn[:key]}_subtypes")
      )
    end

    def subtype_summary(key, label, items:, count: nil)
      key = key.to_sym
      is_expanded = expanded.include?(key.to_s)
      SubtypeSummary.new(
        key: key,
        label: label,
        count: count.nil? ? items.size : count,
        items: is_expanded ? items : [],
        expanded: is_expanded
      )
    end

    def submitted_maap_proposals_subtypes
      proposals = submitted_proposals
      items = if expanded.include?("submitted_maap_proposals")
        proposals.map { |proposal| submitted_proposal_item(proposal) }
      else
        []
      end

      [
        subtype_summary(
          :submitted_maap_proposals,
          "Assignment and Ability proposals awaiting apply or reject",
          items: items,
          count: proposals.size
        )
      ]
    end

    def submitted_proposals
      @submitted_proposals ||= MaapProposal
        .submitted
        .for_organization(organization)
        .includes(:proposer, :proposable, proposer: :person)
        .created_first
        .to_a
    end

    def submitted_proposal_item(proposal)
      proposer = proposal.proposer
      title = proposal.proposed_title.presence || "Untitled proposal"
      kind_label = proposal.create_kind? ? "Create" : "Edit"
      target = if proposal.create_kind?
        "new Assignment"
      elsif proposal.proposable.respond_to?(:title)
        proposal.proposable.title
      elsif proposal.proposable.respond_to?(:name)
        proposal.proposable.name
      else
        proposal.proposable_type.to_s
      end

      review_url = if proposal.create_kind?
        routes.organization_maap_assignment_create_path(organization, proposal)
      elsif proposal.proposable_type == "Assignment" && proposal.proposable
        routes.organization_assignment_maap_proposal_path(organization, proposal.proposable, proposal)
      elsif proposal.proposable_type == "Ability" && proposal.proposable
        routes.organization_ability_maap_proposal_path(organization, proposal.proposable, proposal)
      end

      Item.new(
        id: "submitted-maap-proposal-#{proposal.id}",
        subtype_key: :submitted_maap_proposals,
        teammate_id: proposer&.id,
        person_name: person_name_for(proposer),
        title: "#{kind_label}: #{title}",
        subtitle: "Submitted proposal for #{target}",
        actions: [
          Action.new(label: "Review proposal", url: review_url)
        ].select { |action| action.url.present? }
      )
    end

    def seat_position_alignment_subtypes
      mismatched = mismatched_seat_position_tenures
      items = if expanded.include?("mismatched_seat_position")
        mismatched.map { |tenure| mismatched_seat_position_item(tenure) }
      else
        []
      end

      [
        subtype_summary(
          :mismatched_seat_position,
          "Active tenures where seat titles do not include the position title",
          items: items,
          count: mismatched.size
        )
      ]
    end

    def mismatched_seat_position_tenures
      @mismatched_seat_position_tenures ||= begin
        EmploymentTenure.active
          .where(company: organization)
          .where.not(seat_id: nil)
          .includes(:position, :seat, seat: :seat_titles, position: :title, company_teammate: :person)
          .select { |tenure| !tenure.seat.includes_title_id?(tenure.position.title_id) }
          .sort_by { |tenure| person_name_for(tenure.company_teammate).downcase }
      end
    end

    def mismatched_seat_position_item(tenure)
      teammate = tenure.company_teammate
      seat = tenure.seat
      position = tenure.position
      casual = casual_name_for(teammate)

      Item.new(
        id: "mismatched-seat-position-#{tenure.id}",
        subtype_key: :mismatched_seat_position,
        teammate_id: teammate.id,
        person_name: person_name_for(teammate),
        title: "#{seat.display_name} ↔ #{position.title.display_name}",
        subtitle: "Seat titles do not include this position's title",
        actions: [
          Action.new(
            label: "Change #{casual}'s Seat",
            url: routes.edit_organization_company_teammate_employment_tenure_path(
              organization,
              teammate,
              tenure
            )
          ),
          Action.new(
            label: "Add Positions to #{seat.display_name}",
            url: routes.manage_titles_organization_seat_path(organization, seat)
          )
        ]
      )
    end

    def person_name_for(teammate)
      teammate.person&.display_name || teammate.to_s
    end

    def casual_name_for(teammate)
      teammate.person&.casual_name.presence || person_name_for(teammate)
    end
  end
end
