# frozen_string_literal: true

class AddObservableMomentNotifierToOrganizations < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:organizations, :observable_moment_notifier_teammate_id)

    add_reference :organizations, :observable_moment_notifier_teammate,
                  foreign_key: { to_table: :teammates },
                  index: true,
                  null: true
  end
end
