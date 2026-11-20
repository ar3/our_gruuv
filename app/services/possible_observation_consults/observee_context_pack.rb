# frozen_string_literal: true

module PossibleObservationConsults
  # MAAP catalog for transcript cue rating:
  # - 0 observees → company values (Aspirations) only
  # - 1 observee → that person's SubjectContextPack
  # - N observees → shared Assignments/Abilities (intersection) + company values
  class ObserveeContextPack
    Result = Struct.new(:prompt_text, :catalog, :observee_name, keyword_init: true)

    def self.call(teammates:, organization:)
      new(teammates: teammates, organization: organization).call
    end

    def initialize(teammates:, organization:)
      @teammates = Array(teammates).compact
      @organization = organization
    end

    def call
      return aspirations_only_pack if @teammates.empty?
      return single_pack(@teammates.first) if @teammates.one?

      intersection_pack
    end

    private

    def single_pack(teammate)
      pack = PossibleObservationSlackSearches::SubjectContextPack.call(
        teammate: teammate,
        organization: @organization
      )
      Result.new(
        prompt_text: pack.prompt_text,
        catalog: pack.catalog,
        observee_name: person_name(teammate)
      )
    end

    def aspirations_only_pack
      catalog = empty_catalog
      text = aspirations_section(catalog)
      Result.new(
        prompt_text: "#{text}\n\nASSIGNMENTS (outcomes only):\n(none — no named observee)\n\nABILITIES:\n(none — no named observee)\n\nACTIVE GOALS:\n(none)",
        catalog: catalog,
        observee_name: "the team"
      )
    end

    def intersection_pack
      packs = @teammates.map { |tm|
        PossibleObservationSlackSearches::SubjectContextPack.call(
          teammate: tm,
          organization: @organization
        )
      }

      catalog = empty_catalog
      aspiration_maps = packs.map { |pack| pack.catalog["Aspiration"] || {} }
      assignment_id_sets = packs.map { |pack| (pack.catalog["Assignment"] || {}).keys.map(&:to_i).to_set }
      ability_id_sets = packs.map { |pack| (pack.catalog["Ability"] || {}).keys.map(&:to_i).to_set }

      catalog["Aspiration"] = aspiration_maps.reduce({}) { |memo, map| memo.merge(map) }
      shared_assignment_ids = assignment_id_sets.reduce(&:intersection)
      shared_ability_ids = ability_id_sets.reduce(&:intersection)

      first_catalog = packs.first.catalog
      shared_assignment_ids.each do |id|
        catalog["Assignment"][id] = first_catalog.dig("Assignment", id) ||
          packs.filter_map { |pack| pack.catalog.dig("Assignment", id) }.first
      end
      shared_ability_ids.each do |id|
        catalog["Ability"][id] = first_catalog.dig("Ability", id) ||
          packs.filter_map { |pack| pack.catalog.dig("Ability", id) }.first
      end

      names = @teammates.map { |tm| person_name(tm) }
      observee_name = names.to_sentence(two_words_connector: " and ", last_word_connector: ", and ")

      sections = []
      sections << aspirations_lines(catalog)
      sections << assignments_lines(catalog)
      sections << abilities_lines(catalog)
      sections << "ACTIVE GOALS:\n(none — multiple observees; rate shared work and values only)"
      sections << "Shared observees: #{observee_name}. Only suggest Assignments/Abilities that appear for every observee, plus company values."

      Result.new(
        prompt_text: sections.compact_blank.join("\n\n"),
        catalog: catalog,
        observee_name: observee_name
      )
    end

    def empty_catalog
      {
        "Assignment" => {},
        "Ability" => {},
        "Aspiration" => {},
        "Goal" => {}
      }
    end

    def aspirations_section(catalog)
      aspirations = Aspiration.within_hierarchy(@organization).ordered.to_a
      return "ASPIRATIONS:\n(none)" if aspirations.empty?

      lines = aspirations.map do |aspiration|
        catalog["Aspiration"][aspiration.id] = aspiration.name.to_s
        desc = aspiration.description.to_s.gsub(/\s+/, " ").strip.truncate(500)
        "- [Aspiration id=#{aspiration.id}] #{aspiration.name}\n  #{desc}"
      end
      "ASPIRATIONS (use these exact names/ids when suggesting):\n#{lines.join("\n")}"
    end

    def aspirations_lines(catalog)
      return "ASPIRATIONS:\n(none)" if catalog["Aspiration"].blank?

      lines = catalog["Aspiration"].map { |id, name|
        "- [Aspiration id=#{id}] #{name}"
      }
      "ASPIRATIONS (use these exact names/ids when suggesting):\n#{lines.join("\n")}"
    end

    def assignments_lines(catalog)
      return "ASSIGNMENTS (outcomes only):\n(none — no shared assignments across observees)" if catalog["Assignment"].blank?

      lines = catalog["Assignment"].map { |id, name|
        "- [Assignment id=#{id}] #{name}"
      }
      "ASSIGNMENTS (shared across observees — outcomes only):\n#{lines.join("\n")}"
    end

    def abilities_lines(catalog)
      return "ABILITIES:\n(none — no shared abilities across observees)" if catalog["Ability"].blank?

      lines = catalog["Ability"].map { |id, name|
        "- [Ability id=#{id}] #{name}"
      }
      "ABILITIES (shared across observees):\n#{lines.join("\n")}"
    end

    def person_name(teammate)
      teammate.person.casual_name.presence || teammate.person.display_name
    end
  end
end
