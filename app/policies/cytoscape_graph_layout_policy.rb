# frozen_string_literal: true

class CytoscapeGraphLayoutPolicy < ApplicationPolicy
  def show?
    layoutable_viewable?
  end

  def update?
    layoutable_editable?
  end

  def destroy?
    update?
  end

  private

  def layoutable_viewable?
    case record
    when Organization
      OrganizationPolicy.new(pundit_user, record).view_assignment_flows?
    when Assignment
      AssignmentPolicy.new(pundit_user, record).show?
    when Position
      PositionPolicy.new(pundit_user, record).show?
    else
      false
    end
  end

  def layoutable_editable?
    case record
    when Organization
      OrganizationPolicy.new(pundit_user, record).update_cytoscape_graph_layout?
    when Assignment
      AssignmentPolicy.new(pundit_user, record).update_cytoscape_graph_layout?
    when Position
      PositionPolicy.new(pundit_user, record).update_cytoscape_graph_layout?
    else
      false
    end
  end
end
