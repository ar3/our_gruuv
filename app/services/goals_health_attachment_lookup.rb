# frozen_string_literal: true

# Batched attachment / child-goal enrichment for Goals Health rows (one query set per page).
class GoalsHealthAttachmentLookup
  TYPE_META = {
    "Assignment" => { plural: "assignments", singular: "assignment" },
    "Ability" => { plural: "abilities", singular: "ability" },
    "Aspiration" => { plural: "values", singular: "value" },
    "Prompt" => { plural: "prompts", singular: "prompt" }
  }.freeze

  Entry = Data.define(
    :active_with_attachments_count,
    :active_child_count,
    :type_groups
  )

  TypeGroup = Data.define(:associable_type, :plural_label, :singular_label, :count, :sole)

  SoleAssociable = Data.define(:id, :name, :associable_type)

  def self.load_for_goals(goals)
    new(goals).load
  end

  def initialize(goals)
    @goals = Array(goals)
    @goals_by_id = @goals.index_by(&:id)
  end

  def load
    goal_ids = @goals_by_id.keys
    return empty_map if goal_ids.empty?

    child_ids = GoalLink.where(child_id: goal_ids).distinct.pluck(:child_id).to_set
    associations = GoalAssociation.where(goal_id: goal_ids).to_a
    associables_by_key = load_associables(associations)
    prompt_attachments_by_goal_id = load_prompt_attachments(goal_ids)

    associations_by_goal_id = associations.group_by(&:goal_id)

    @goals_by_id.keys.index_with do |goal_id|
      association_rows = Array(associations_by_goal_id[goal_id]).filter_map do |assoc|
        key = [assoc.associable_type, assoc.associable_id]
        associable = associables_by_key[key]
        next unless associable

        {
          associable_type: assoc.associable_type,
          id: assoc.associable_id,
          name: associable_name(associable)
        }
      end

      {
        child: child_ids.include?(goal_id),
        associations: association_rows + Array(prompt_attachments_by_goal_id[goal_id])
      }
    end
  end

  # Fold per-goal facts for one teammate's active goals into display Entry.
  def self.entry_for_active_goals(active_goals, per_goal_facts)
    active_goals = Array(active_goals)
    facts = per_goal_facts || {}

    active_child_count = active_goals.count { |goal| facts.dig(goal.id, :child) }
    attached_goals = active_goals.select { |goal| Array(facts.dig(goal.id, :associations)).any? }

    by_type = Hash.new { |h, k| h[k] = {} }
    attached_goals.each do |goal|
      Array(facts.dig(goal.id, :associations)).each do |assoc|
        by_type[assoc[:associable_type]][assoc[:id]] = assoc[:name]
      end
    end

    type_groups = TYPE_META.filter_map do |type, meta|
      names_by_id = by_type[type]
      next if names_by_id.blank?

      sole =
        if names_by_id.size == 1
          id, name = names_by_id.first
          SoleAssociable.new(id: id, name: name, associable_type: type)
        end

      TypeGroup.new(
        associable_type: type,
        plural_label: meta[:plural],
        singular_label: meta[:singular],
        count: names_by_id.size,
        sole: sole
      )
    end

    Entry.new(
      active_with_attachments_count: attached_goals.size,
      active_child_count: active_child_count,
      type_groups: type_groups
    )
  end

  private

  def empty_map
    {}
  end

  def load_associables(associations)
    associations.group_by(&:associable_type).each_with_object({}) do |(type, rows), memo|
      ids = rows.map(&:associable_id).uniq
      records =
        case type
        when "Assignment" then Assignment.where(id: ids).index_by(&:id)
        when "Ability" then Ability.where(id: ids).index_by(&:id)
        when "Aspiration" then Aspiration.where(id: ids).index_by(&:id)
        else {}
        end
      records.each { |id, record| memo[[type, id]] = record }
    end
  end

  def load_prompt_attachments(goal_ids)
    PromptGoal
      .where(goal_id: goal_ids)
      .includes(prompt: :prompt_template)
      .group_by(&:goal_id)
      .transform_values do |rows|
        rows.map do |prompt_goal|
          prompt = prompt_goal.prompt
          {
            associable_type: "Prompt",
            id: prompt.id,
            name: prompt.prompt_template&.title.presence || "Prompt ##{prompt.id}"
          }
        end
      end
  end

  def associable_name(associable)
    if associable.respond_to?(:display_name)
      associable.display_name
    elsif associable.respond_to?(:title) && associable.title.present?
      associable.title
    else
      associable.name
    end
  end
end
