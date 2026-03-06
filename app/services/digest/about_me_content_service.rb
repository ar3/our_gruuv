# frozen_string_literal: true

module Digest
  # Builds plain-text About Me section status and explanation for digest (Slack, etc.).
  # Uses the same status logic as the About Me page; returns section_name, status, and explanation sentence for yellow/red.
  class AboutMeContentService
    include AboutMeHelper

    SECTION_ORDER = [
      [:aspirations_check_in, 'Aspirational Values Check-In'],
      [:assignments_check_in, 'Assignments/Outcomes Check-In'],
      [:position_check_in, 'Position/Overall'],
      [:goals, 'Active Goals'],
      [:prompts, 'Prompts/Reflections'],
      [:stories, 'Stories'],
      [:one_on_one, '1:1 Area'],
      [:abilities, 'Abilities/Skills/Knowledge']
    ].freeze

    # Plain-text explanation per section and status (from status_conditions_popover_content)
    EXPLANATIONS = {
      aspirations_check_in: {
        red: 'None of the company aspirational values have check-ins within the last 90 days',
        yellow: 'No aspiration check-in has ever been finalized, OR no company aspirational values exist',
        green: 'All company aspirational values have check-ins within the last 90 days'
      },
      assignments_check_in: {
        red: 'None of the relevant assignments (required or active with energy > 0) have check-ins within the last 90 days',
        yellow: 'No assignment check-in has ever been finalized, OR no required assignments or active assignments with energy > 0',
        green: 'All relevant assignments (required or active with energy > 0) have check-ins within the last 90 days'
      },
      position_check_in: {
        red: 'Last finalized check-in was more than 90 days ago',
        yellow: 'No finalized check-in exists',
        green: 'Last finalized check-in was within the last 90 days'
      },
      goals: {
        red: 'No active goals',
        yellow: 'Has active goals but not all have check-ins in the past 2 weeks',
        green: 'Any goal completed in last 90 days, OR all active goals have check-ins in past 2 weeks'
      },
      prompts: {
        red: 'No prompts started or no responses provided',
        yellow: 'Has prompts with responses but no active goals associated',
        green: 'Has prompts with responses AND at least one active goal associated'
      },
      stories: {
        red: 'No observations given or received in the past 30 days',
        yellow: 'Only observations given OR only observations received (but not both)',
        green: 'Both observations given and received, OR 2+ observations given'
      },
      one_on_one: {
        red: 'No 1:1 link URL defined',
        yellow: nil,
        green: '1:1 link URL is present'
      },
      abilities: {
        red: 'More than 50% of required ability milestones are not met',
        yellow: 'No position or no required assignments with ability milestones',
        green: 'All required ability milestones are met'
      }
    }.freeze

    def initialize(teammate:, organization:)
      @teammate = teammate
      @organization = organization
      @company = organization.root_company || organization
    end

    def sections
      SECTION_ORDER.filter_map do |key, section_name|
        status = status_for(key)
        next nil if status.nil? # section hidden (e.g. prompts when no prompts)

        explanation = (status != :green && EXPLANATIONS[key]&.dig(status)) ? EXPLANATIONS[key][status] : nil
        { section_name: section_name, status: status, explanation_sentence: explanation }
      end
    end

    private

    attr_reader :teammate, :organization, :company

    def status_for(key)
      case key
      when :aspirations_check_in then aspirations_check_in_status_indicator(teammate, organization)
      when :assignments_check_in then assignments_check_in_status_indicator(teammate, organization)
      when :position_check_in then position_check_in_status_indicator(teammate)
      when :goals then goals_status_indicator(teammate)
      when :prompts
        ind = prompts_status_indicator(teammate)
        return nil if ind.nil? # section hidden when no active prompts
        ind
      when :stories then shareable_observations_status_indicator(teammate, organization)
      when :one_on_one then one_on_one_status_indicator(teammate.one_on_one_link)
      when :abilities then abilities_status_indicator(teammate, organization)
      else nil
      end
    end
  end
end
