# frozen_string_literal: true

module AssociableGoalsHelper
  def associable_goals_choose_manage_path(organization, associable, **options)
    case associable
    when Assignment
      choose_manage_goals_organization_assignment_path(organization, associable, **options)
    when Ability
      choose_manage_goals_organization_ability_path(organization, associable, **options)
    when Aspiration
      choose_manage_goals_organization_aspiration_path(organization, associable, **options)
    else
      raise ArgumentError, "Unsupported associable: #{associable.class.name}"
    end
  end

  def associable_goals_manage_path(organization, associable, **options)
    case associable
    when Assignment
      manage_goals_organization_assignment_path(organization, associable, **options)
    when Ability
      manage_goals_organization_ability_path(organization, associable, **options)
    when Aspiration
      manage_goals_organization_aspiration_path(organization, associable, **options)
    else
      raise ArgumentError, "Unsupported associable: #{associable.class.name}"
    end
  end

  def associable_goals_associate_existing_path(organization, associable, **options)
    case associable
    when Assignment
      associate_existing_goals_organization_assignment_path(organization, associable, **options)
    when Ability
      associate_existing_goals_organization_ability_path(organization, associable, **options)
    when Aspiration
      associate_existing_goals_organization_aspiration_path(organization, associable, **options)
    else
      raise ArgumentError, "Unsupported associable: #{associable.class.name}"
    end
  end

  def associable_goal_associations_path(organization, associable, **options)
    case associable
    when Assignment
      organization_assignment_goal_associations_path(organization, associable, **options)
    when Ability
      organization_ability_goal_associations_path(organization, associable, **options)
    when Aspiration
      organization_aspiration_goal_associations_path(organization, associable, **options)
    else
      raise ArgumentError, "Unsupported associable: #{associable.class.name}"
    end
  end

  def associable_goal_association_path(organization, associable, goal_association, **options)
    case associable
    when Assignment
      organization_assignment_goal_association_path(organization, associable, goal_association, **options)
    when Ability
      organization_ability_goal_association_path(organization, associable, goal_association, **options)
    when Aspiration
      organization_aspiration_goal_association_path(organization, associable, goal_association, **options)
    else
      raise ArgumentError, "Unsupported associable: #{associable.class.name}"
    end
  end

  def associable_goals_default_show_path(organization, associable)
    case associable
    when Assignment
      organization_assignment_path(organization, associable)
    when Ability
      organization_ability_path(organization, associable)
    when Aspiration
      organization_aspiration_path(organization, associable)
    else
      raise ArgumentError, "Unsupported associable: #{associable.class.name}"
    end
  end

  # 1-by-1 check-in context for the same catalog object (assignment / ability / aspiration).
  def organization_teammate_lens_show_path(organization, teammate, associable)
    case associable
    when Assignment
      organization_teammate_assignment_path(organization, teammate, associable)
    when Ability
      organization_teammate_ability_path(organization, teammate, associable)
    when Aspiration
      organization_teammate_aspiration_path(organization, teammate, associable)
    else
      raise ArgumentError, "Unsupported associable: #{associable.class.name}"
    end
  end

  def organization_teammate_lens_catalog_href(organization, associable, viewing_person)
    teammate = organization.teammates.find_by(person_id: viewing_person.id)
    return if teammate.blank?

    organization_teammate_lens_show_path(organization, teammate, associable)
  end

  def organization_teammate_lens_catalog_label(associable, viewing_person)
    casual = viewing_person.casual_name.presence || viewing_person.display_name
    "#{associable_display_title(associable)} + #{casual}"
  end

  def associable_display_title(associable)
    case associable
    when Assignment
      associable.title
    when Ability
      associable.name
    when Aspiration
      associable.name
    else
      associable.to_s
    end
  end
end
