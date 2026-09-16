# frozen_string_literal: true

module MaapCleanupInbox
  # Org-wide MAAP cleanup inbox: mismatches and gaps that keep a MAAP from being "clean".
  # Counts always; item rows only for expanded subtypes.
  class Builder
    Item = Data.define(
      :id,
      :subtype_key,
      :teammate_id,
      :person_name,
      :title,
      :subtitle,
      :tenure_url,
      :seat_url
    )
    SubtypeSummary = Data.define(:key, :label, :count, :items, :expanded)
    Section = Data.define(:key, :label, :subtypes)

    SECTION_DEFS = [
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

      Item.new(
        id: "mismatched-seat-position-#{tenure.id}",
        subtype_key: :mismatched_seat_position,
        teammate_id: teammate.id,
        person_name: person_name_for(teammate),
        title: "#{seat.display_name} ↔ #{position.title.display_name}",
        subtitle: "Seat titles do not include this position's title",
        tenure_url: routes.organization_company_teammate_employment_tenure_path(
          organization,
          teammate,
          tenure
        ),
        seat_url: routes.organization_seat_path(organization, seat)
      )
    end

    def person_name_for(teammate)
      teammate.person&.display_name || teammate.to_s
    end
  end
end
