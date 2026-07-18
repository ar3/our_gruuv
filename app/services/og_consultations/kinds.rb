# frozen_string_literal: true

module OgConsultations
  # Central map of consultation kind → result class, job, runner, and display metadata.
  # Add new kinds here first, then wire controllers/jobs to look up via {.fetch}.
  #
  # Class names are stored as strings to avoid Zeitwerk circular loads at boot.
  module Kinds
    Entry = Data.define(
      :kind,
      :label,
      :result_class_name,
      :job_class_name,
      :runner_class_name,
      :llm_purpose,
      :billable
    ) do
      def result_class
        result_class_name.constantize
      end

      def job_class
        job_class_name.constantize
      end

      def runner_class
        runner_class_name&.constantize
      end
    end

    REGISTRY = {
      OgConsultation::KIND_ABILITY_CLARITY => Entry.new(
        kind: OgConsultation::KIND_ABILITY_CLARITY,
        label: 'Ability clarity',
        result_class_name: 'AbilityClarityResult',
        job_class_name: 'AbilityClarityJob',
        runner_class_name: 'Maap::AbilityClarityRunner',
        llm_purpose: 'ability_clarity',
        billable: true
      ),
      OgConsultation::KIND_ASSIGNMENT_CLARITY => Entry.new(
        kind: OgConsultation::KIND_ASSIGNMENT_CLARITY,
        label: 'Assignment clarity',
        result_class_name: 'AssignmentClarityResult',
        job_class_name: 'AssignmentClarityJob',
        runner_class_name: 'Maap::AssignmentClarityRunner',
        llm_purpose: 'assignment_clarity',
        billable: true
      ),
      OgConsultation::KIND_POSITION_CLARITY => Entry.new(
        kind: OgConsultation::KIND_POSITION_CLARITY,
        label: 'Position clarity',
        result_class_name: 'PositionClarityResult',
        job_class_name: 'PositionClarityJob',
        runner_class_name: 'Maap::PositionClarityRunner',
        llm_purpose: 'position_clarity',
        billable: true
      ),
      OgConsultation::KIND_TEAMMATE_GROWTH => Entry.new(
        kind: OgConsultation::KIND_TEAMMATE_GROWTH,
        label: 'Teammate growth',
        result_class_name: 'TeammateGrowthResult',
        job_class_name: 'TeammateGrowthJob',
        runner_class_name: 'Maap::TeammateGrowthRunner',
        llm_purpose: 'teammate_growth',
        billable: true
      ),
      OgConsultation::KIND_OGO_SEARCH_TRANSCRIPT => Entry.new(
        kind: OgConsultation::KIND_OGO_SEARCH_TRANSCRIPT,
        label: 'OGO search (transcript)',
        result_class_name: 'OgoSearchResult',
        job_class_name: 'PossibleObservationTranscriptExtractionJob',
        runner_class_name: nil,
        llm_purpose: 'transcript_chunk',
        billable: true
      ),
      OgConsultation::KIND_OGO_SEARCH_SLACK => Entry.new(
        kind: OgConsultation::KIND_OGO_SEARCH_SLACK,
        label: 'OGO search (Slack)',
        result_class_name: 'OgoSearchResult',
        job_class_name: 'PossibleObservationSlackSearchExtractionJob',
        runner_class_name: nil,
        llm_purpose: 'slack_chunk',
        billable: true
      )
    }.freeze

    module_function

    def all
      REGISTRY.values
    end

    def kinds
      REGISTRY.keys
    end

    def fetch(kind)
      REGISTRY.fetch(kind.to_s)
    rescue KeyError
      raise KeyError, "Unknown OgConsultation kind: #{kind.inspect}. Register it in OgConsultations::Kinds."
    end

    def result_class_for(kind)
      fetch(kind).result_class
    end

    def job_class_for(kind)
      fetch(kind).job_class
    end

    def runner_class_for(kind)
      fetch(kind).runner_class
    end

    def label_for(kind)
      fetch(kind).label
    end

    def known?(kind)
      REGISTRY.key?(kind.to_s)
    end
  end
end
