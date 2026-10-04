# frozen_string_literal: true

module MaapProposals
  # Spawns a Seat create draft plus linked Title/Team/Position/Assignment/Ability proposals
  # from a confirmed Seat Suggestion chat summary.
  class CreateSeatSuggestionBundle
    def self.call(organization:, proposer:, bundle:)
      new(organization: organization, proposer: proposer, bundle: bundle).call
    end

    def initialize(organization:, proposer:, bundle:)
      @organization = organization
      @proposer = proposer
      @bundle = (bundle || {}).deep_stringify_keys
    end

    def call
      seat_data = hash_at("seat")
      title_data = hash_at("title")
      team_data = hash_at("team")
      position_data = hash_at("position")
      assignments = Array(@bundle["assignments"])

      created = []
      seat_proposal = nil

      ApplicationRecord.transaction do
        title_id, title_proposal = resolve_title!(title_data, created)
        team_id, team_proposal = resolve_team!(team_data, created)
        position_proposal = create_position_proposal!(position_data, title_id, title_proposal, created)
        assignment_links = create_assignment_graph!(assignments, created)

        if position_proposal
          payload = PositionPayload.from_hash(
            position_proposal.proposed_payload.merge("assignment_links" => assignment_links)
          )
          position_proposal.update!(proposed_payload: payload.to_h)
        end

        seat_payload = SeatPayload.from_hash(
          "title_id" => title_id,
          "additional_title_ids" => [],
          "title_proposal_id" => title_proposal&.id,
          "pending_title_name" => title_proposal ? title_data["external_title"] : nil,
          "seat_needed_by" => seat_data["seat_needed_by"].presence || (Date.current + 3.months).iso8601,
          "job_classification" => seat_data["job_classification"].presence || SeatPayload::JOB_CLASSIFICATIONS.first,
          "team_id" => team_id,
          "team_proposal_id" => team_proposal&.id,
          "pending_team_name" => team_proposal ? team_data["name"] : nil,
          "reports" => seat_data["reports"],
          "why_needed" => seat_data["why_needed"],
          "why_now" => seat_data["why_now"],
          "costs_risks" => seat_data["costs_risks"],
          "seat_disclaimer" => seat_data["seat_disclaimer"],
          "work_environment" => seat_data["work_environment"],
          "physical_requirements" => seat_data["physical_requirements"],
          "travel" => seat_data["travel"],
          "suggestion_source" => "seat_suggestion_chat"
        )

        seat_result = CreateSeatCreateDraft.call(
          organization: @organization,
          proposer: @proposer,
          payload: seat_payload
        )
        raise BundleFailed, seat_result.error unless seat_result.ok?

        seat_proposal = seat_result.value
        created << seat_proposal

        link!(seat_proposal, title_proposal, "title") if title_proposal
        link!(seat_proposal, team_proposal, "team") if team_proposal
        link!(seat_proposal, position_proposal, "position") if position_proposal
        created.select { |p| p.assignment_create? || (p.edit_kind? && p.proposable_type == "Assignment") }.each do |child|
          link!(seat_proposal, child, "assignment")
        end
        created.select { |p| p.ability_create? || (p.edit_kind? && p.proposable_type == "Ability") }.each do |child|
          link!(seat_proposal, child, "ability")
        end
      end

      Result.ok(
        seat_proposal: seat_proposal,
        proposals: created,
        redirect_path: Rails.application.routes.url_helpers.organization_maap_seat_create_path(
          @organization,
          seat_proposal
        )
      )
    rescue BundleFailed => e
      Result.err(e.messages)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages)
    end

    private

    class BundleFailed < StandardError
      attr_reader :messages

      def initialize(messages)
        @messages = Array(messages)
        super(@messages.join(", "))
      end
    end

    def hash_at(key)
      value = @bundle[key]
      value.is_a?(Hash) ? value : {}
    end

    def link!(parent, child, role)
      return if parent.nil? || child.nil?

      parent.link_child!(child, role: role)
    end

    def resolve_title!(data, created)
      mode = data["mode"].to_s
      if mode == "existing"
        title = find_title(data)
        raise BundleFailed, "Could not find existing title" if title.nil?

        return [title.id, nil]
      end

      payload = TitlePayload.from_hash(
        "external_title" => data["external_title"].presence || "Suggested Title",
        "position_major_level_id" => data["position_major_level_id"].presence ||
          TitlePayload.default_position_major_level(@organization)&.id,
        "department_id" => data["department_id"],
        "position_summary" => data["position_summary"],
        "alternative_titles" => data["alternative_titles"]
      )
      result = CreateTitleCreateDraft.call(
        organization: @organization,
        proposer: @proposer,
        payload: payload
      )
      raise BundleFailed, result.error unless result.ok?

      created << result.value
      [nil, result.value]
    end

    def resolve_team!(data, created)
      mode = data["mode"].to_s
      return [nil, nil] if mode.blank? || mode == "none"

      if mode == "existing"
        team = find_team(data)
        raise BundleFailed, "Could not find existing team" if team.nil?

        return [team.id, nil]
      end

      payload = TeamPayload.from_hash(
        "name" => data["name"].presence || "Suggested Team",
        "department_id" => data["department_id"]
      )
      result = CreateTeamCreateDraft.call(
        organization: @organization,
        proposer: @proposer,
        payload: payload
      )
      raise BundleFailed, result.error unless result.ok?

      created << result.value
      [nil, result.value]
    end

    def create_position_proposal!(data, title_id, title_proposal, created)
      return nil if data.blank? && title_id.blank? && title_proposal.nil?

      payload = PositionPayload.from_hash(
        "title_id" => title_id,
        "title_proposal_id" => title_proposal&.id,
        "position_level_hint" => data["position_level_hint"].presence || "1",
        "position_summary" => data["position_summary"],
        "assignment_links" => []
      )
      result = CreatePositionCreateDraft.call(
        organization: @organization,
        proposer: @proposer,
        payload: payload
      )
      raise BundleFailed, result.error unless result.ok?

      created << result.value
      result.value
    end

    def create_assignment_graph!(assignments, created)
      links = []
      assignments.each do |raw|
        next unless raw.is_a?(Hash)

        row = raw.deep_stringify_keys
        mode = row["mode"].to_s
        assignment_id = nil
        assignment_proposal = nil

        if mode == "edit" || mode == "existing"
          assignment = find_assignment(row)
          raise BundleFailed, "Could not find assignment #{row['title'] || row['path']}" if assignment.nil?

          assignment_id = assignment.id
          if mode == "edit"
            edit = create_assignment_edit!(assignment, row)
            created << edit if edit
          end
        else
          assignment_proposal = create_assignment_create!(row, created)
        end

        Array(row["abilities"]).each do |ability_raw|
          next unless ability_raw.is_a?(Hash)

          ensure_ability!(ability_raw.deep_stringify_keys, assignment_proposal, assignment_id, created)
        end

        links << {
          "assignment_id" => assignment_id,
          "assignment_proposal_id" => assignment_proposal&.id,
          "assignment_type" => row["assignment_type"].presence || "required",
          "energy_percentage" => row["energy_percentage"].presence&.to_i
        }
      end
      links
    end

    def create_assignment_create!(row, created)
      ability_milestones = []
      payload = AssignmentPayload.from_hash(
        "title" => row["title"].presence || "Suggested Assignment",
        "tagline" => row["tagline"],
        "required_activities" => row["required_activities"],
        "handbook" => row["handbook"],
        "department_id" => row["department_id"],
        "outcomes" => Array(row["outcomes"]).map { |o|
          o.is_a?(Hash) ? o : { "description" => o.to_s, "outcome_type" => "quantitative" }
        },
        "ability_milestones" => ability_milestones
      )
      result = CreateAssignmentCreateDraft.call(
        organization: @organization,
        proposer: @proposer,
        payload: payload
      )
      raise BundleFailed, result.error unless result.ok?

      created << result.value
      result.value
    end

    def create_assignment_edit!(assignment, row)
      current = AssignmentPayload.from_assignment(assignment).to_h
      merged = current.merge(
        {
          "tagline" => row["tagline"].presence || current["tagline"],
          "required_activities" => row["required_activities"].presence || current["required_activities"],
          "handbook" => row["handbook"].presence || current["handbook"]
        }.compact
      )
      proposal = MaapProposal.create!(
        organization: @organization,
        proposable: assignment,
        kind: "edit",
        status: "draft",
        proposer: @proposer,
        based_on_semantic_version: assignment.semantic_version,
        source: "in_product",
        proposed_payload: AssignmentPayload.from_hash(merged).to_h,
        content_schema_version: AssignmentPayload::SCHEMA_VERSION
      )
      proposal
    end

    def ensure_ability!(row, assignment_proposal, assignment_id, created)
      mode = row["mode"].to_s
      if mode == "existing" || mode == "edit"
        ability = find_ability(row)
        return if ability.nil?

        if mode == "edit"
          proposal = MaapProposal.create!(
            organization: @organization,
            proposable: ability,
            kind: "edit",
            status: "draft",
            proposer: @proposer,
            based_on_semantic_version: ability.semantic_version,
            source: "in_product",
            proposed_payload: AbilityPayload.from_ability(ability).to_h.merge(
              "description" => row["description"].presence || ability.description
            ),
            content_schema_version: AbilityPayload::SCHEMA_VERSION
          )
          created << proposal
        end

        attach_ability_milestone!(assignment_proposal, assignment_id, ability.id, row["milestone_level"])
        return
      end

      payload = AbilityPayload.from_hash(
        "name" => row["name"].presence || "Suggested Ability",
        "description" => row["description"].presence || "Describe this ability",
        "department_id" => row["department_id"],
        "milestone_1_description" => ability_milestone_description_for(row, 1),
        "milestone_2_description" => ability_milestone_description_for(row, 2),
        "milestone_3_description" => ability_milestone_description_for(row, 3),
        "milestone_4_description" => ability_milestone_description_for(row, 4),
        "milestone_5_description" => ability_milestone_description_for(row, 5)
      )
      result = CreateAbilityCreateDraft.call(
        organization: @organization,
        proposer: @proposer,
        payload: payload
      )
      raise BundleFailed, result.error unless result.ok?

      created << result.value
      # Ability create has no id yet; milestone wiring happens after ability apply.
      # Store pending milestone on assignment create payload via temporary key.
      return unless assignment_proposal

      pending = Array(assignment_proposal.proposed_payload["pending_ability_milestones"])
      pending << {
        "ability_proposal_id" => result.value.id,
        "milestone_level" => (row["milestone_level"].presence || 3).to_i
      }
      assignment_proposal.update!(
        proposed_payload: assignment_proposal.proposed_payload.merge("pending_ability_milestones" => pending)
      )
    end

    def attach_ability_milestone!(assignment_proposal, assignment_id, ability_id, milestone_level)
      level = (milestone_level.presence || 3).to_i
      if assignment_proposal
        milestones = Array(assignment_proposal.proposed_payload["ability_milestones"])
        milestones << { "ability_id" => ability_id, "milestone_level" => level }
        assignment_proposal.update!(
          proposed_payload: assignment_proposal.proposed_payload.merge("ability_milestones" => milestones)
        )
      elsif assignment_id
        # Edit path already handled separately; nothing to attach on create-less existing.
      end
    end

    def find_title(data)
      if data["title_id"].present?
        Title.find_by(id: data["title_id"], company: @organization)
      elsif data["external_title"].present?
        Title.unarchived.for_company(@organization)
             .find_by("LOWER(external_title) = ?", data["external_title"].to_s.downcase)
      end
    end

    def ability_milestone_description_for(row, level)
      full = row["milestone_#{level}_description"].presence
      return full if full.present?

      Ability.milestone_description_with_examples(level, ability_milestone_examples_for(row, level))
    end

    def ability_milestone_examples_for(row, level)
      nested = row["milestone_examples"]
      if nested.is_a?(Hash)
        value = nested[level.to_s].presence || nested[level].presence
        return value if value.present?
      end

      row["milestone_#{level}_examples"]
    end

    def find_team(data)
      if data["team_id"].present?
        Team.find_by(id: data["team_id"], company: @organization)
      elsif data["name"].present?
        Team.active.for_company(@organization).find_by("LOWER(name) = ?", data["name"].to_s.downcase)
      end
    end

    def find_assignment(data)
      if data["assignment_id"].present?
        Assignment.find_by(id: data["assignment_id"], company: @organization)
      elsif data["title"].present?
        Assignment.unarchived.where(company: @organization)
                  .find_by("LOWER(title) = ?", data["title"].to_s.downcase)
      end
    end

    def find_ability(data)
      if data["ability_id"].present?
        Ability.find_by(id: data["ability_id"], company: @organization)
      elsif data["name"].present?
        Ability.unarchived.where(company: @organization)
               .find_by("LOWER(name) = ?", data["name"].to_s.downcase)
      end
    end
  end
end
