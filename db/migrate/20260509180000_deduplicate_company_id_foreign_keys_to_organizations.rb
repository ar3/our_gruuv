# frozen_string_literal: true

# abilities, aspirations, and titles had two PostgreSQL foreign key constraints on
# `company_id` referencing `organizations` (same column, same target). That led to
# duplicate `add_foreign_key` lines in db/schema.rb and db:schema:load failures.
#
# Cause: `remove_foreign_key :table, column: :company_id` only drops *one* matching
# constraint. The update_*_for_department_separation migrations then called
# `add_foreign_key`, leaving a second constraint in place.
class DeduplicateCompanyIdForeignKeysToOrganizations < ActiveRecord::Migration[8.0]
  TABLES = %w[abilities aspirations titles].freeze

  def up
    TABLES.each do |table|
      next unless table_exists?(table)
      next unless column_exists?(table, :company_id)

      fks = organization_company_id_fks(table)
      next if fks.size <= 1

      fks.each { |fk| remove_foreign_key table, name: fk.name }
      add_foreign_key table, :organizations, column: :company_id
    end
  end

  def down
    # Data repair: not reversible
  end

  private

  def organization_company_id_fks(table)
    foreign_keys(table).select do |fk|
      fk.to_table == "organizations" && Array(fk.column).map(&:to_s) == %w[company_id]
    end
  end
end
