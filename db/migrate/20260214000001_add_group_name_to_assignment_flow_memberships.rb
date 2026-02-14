# frozen_string_literal: true

class AddGroupNameToAssignmentFlowMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :assignment_flow_memberships, :group_name, :string
  end
end
