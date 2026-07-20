# frozen_string_literal: true

module PossibleObservationConsults
  # Merge SubjectContextPack for every confirmed teammate into one consult prompt.
  class MultiSubjectContextPack
    Result = Struct.new(:prompt_text, :catalog, :subjects, keyword_init: true)

    def self.call(teammates:, organization:)
      new(teammates: teammates, organization: organization).call
    end

    def initialize(teammates:, organization:)
      @teammates = Array(teammates)
      @organization = organization
    end

    def call
      catalog = {
        "Assignment" => {},
        "Ability" => {},
        "Aspiration" => {},
        "Goal" => {}
      }
      subjects = []
      sections = []

      @teammates.each do |teammate|
        pack = PossibleObservationSlackSearches::SubjectContextPack.call(
          teammate: teammate,
          organization: @organization
        )
        name = teammate.person.casual_name.presence || teammate.person.display_name
        subjects << { "id" => teammate.id, "name" => name }
        pack.catalog.each do |type, map|
          catalog[type] ||= {}
          catalog[type].merge!(map)
        end
        sections << "=== SUBJECT: #{name} (company_teammate_id=#{teammate.id}) ===\n#{pack.prompt_text}"
      end

      Result.new(
        prompt_text: sections.compact_blank.join("\n\n"),
        catalog: catalog,
        subjects: subjects
      )
    end
  end
end
