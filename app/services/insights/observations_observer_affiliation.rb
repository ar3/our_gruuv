# frozen_string_literal: true

require 'set'

module Insights
  # Classifies observation observers for Insights:
  # - Teammate / Internal = any CompanyTeammate for the company (incl. terminated)
  # - External = never hired (no teammate record for the company)
  class ObservationsObserverAffiliation
    EXTERNAL_LABEL = 'External'
    INTERNAL_LABEL = 'Internal'
    NO_DEPARTMENT_LABEL = 'No Department'

    def self.teammate_person_ids(organization:, person_ids:)
      ids = Array(person_ids).compact.uniq
      return Set.new if ids.empty?

      CompanyTeammate.where(organization: organization, person_id: ids).distinct.pluck(:person_id).to_set
    end

    def self.external?(person_id, teammate_person_ids)
      person_id.blank? || !teammate_person_ids.include?(person_id)
    end

    def self.affiliation_label(person_id, teammate_person_ids)
      external?(person_id, teammate_person_ids) ? EXTERNAL_LABEL : INTERNAL_LABEL
    end

    # Department bucket for observer charts. Never-hired → External;
    # teammates without a department on active tenure → No Department.
    def self.observer_department_label(person_id:, teammate:)
      return EXTERNAL_LABEL if teammate.blank?

      teammate.active_employment_tenure&.position&.title&.department&.name.presence || NO_DEPARTMENT_LABEL
    end

    def self.sort_department_names(names)
      Array(names).uniq.sort_by do |name|
        [
          case name
          when NO_DEPARTMENT_LABEL then 1
          when EXTERNAL_LABEL then 2
          else 0
          end,
          name.to_s
        ]
      end
    end
  end
end
