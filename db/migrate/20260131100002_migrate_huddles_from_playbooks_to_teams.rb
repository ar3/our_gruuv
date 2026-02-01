class MigrateHuddlesFromPlaybooksToTeams < ActiveRecord::Migration[8.0]
  def up
    # For each huddle with a huddle_playbook, set the team_id from the playbook
    execute <<-SQL
      UPDATE huddles
      SET team_id = huddle_playbooks.team_id
      FROM huddle_playbooks
      WHERE huddles.huddle_playbook_id = huddle_playbooks.id
        AND huddle_playbooks.team_id IS NOT NULL
    SQL

    # For huddles where the playbook had no team, we need to find/create a default team
    # This handles company-level playbooks by creating a "General" team
    execute <<-SQL
      WITH playbooks_needing_teams AS (
        SELECT DISTINCT hp.id as playbook_id, hp.company_id
        FROM huddle_playbooks hp
        JOIN huddles h ON h.huddle_playbook_id = hp.id
        WHERE hp.team_id IS NULL
      ),
      created_teams AS (
        INSERT INTO teams (company_id, name, created_at, updated_at)
        SELECT DISTINCT pnt.company_id, 'General', NOW(), NOW()
        FROM playbooks_needing_teams pnt
        WHERE NOT EXISTS (
          SELECT 1 FROM teams t
          WHERE t.company_id = pnt.company_id AND t.name = 'General'
        )
        RETURNING id, company_id
      ),
      all_general_teams AS (
        SELECT id, company_id FROM created_teams
        UNION ALL
        SELECT id, company_id FROM teams WHERE name = 'General'
      )
      UPDATE huddles
      SET team_id = agt.id
      FROM huddle_playbooks hp, all_general_teams agt
      WHERE huddles.huddle_playbook_id = hp.id
        AND hp.team_id IS NULL
        AND hp.company_id = agt.company_id
        AND huddles.team_id IS NULL
    SQL

    # Migrate slack_channel from playbooks to team's huddle_channel via ThirdPartyObjectAssociation
    # First, find or create the ThirdPartyObject for the channel, then create the association
    execute <<-SQL
      WITH playbook_channels AS (
        SELECT DISTINCT
          hp.team_id,
          hp.slack_channel,
          hp.company_id,
          t.company_id as team_company_id
        FROM huddle_playbooks hp
        JOIN teams t ON t.id = hp.team_id
        WHERE hp.slack_channel IS NOT NULL
          AND hp.slack_channel != ''
          AND hp.team_id IS NOT NULL
      ),
      channel_mappings AS (
        SELECT 
          pc.team_id,
          tpo.id as third_party_object_id
        FROM playbook_channels pc
        JOIN third_party_objects tpo ON 
          tpo.third_party_source = 'slack'
          AND tpo.third_party_object_type = 'channel'
          AND tpo.display_name = pc.slack_channel
          AND tpo.organization_id = pc.team_company_id
      )
      INSERT INTO third_party_object_associations (
        third_party_object_id,
        associatable_type,
        associatable_id,
        association_type,
        created_at,
        updated_at
      )
      SELECT 
        cm.third_party_object_id,
        'Team',
        cm.team_id,
        'huddle_channel',
        NOW(),
        NOW()
      FROM channel_mappings cm
      WHERE NOT EXISTS (
        SELECT 1 FROM third_party_object_associations tpoa
        WHERE tpoa.associatable_type = 'Team'
          AND tpoa.associatable_id = cm.team_id
          AND tpoa.association_type = 'huddle_channel'
      )
    SQL
  end

  def down
    # Remove huddle_channel associations for teams
    execute <<-SQL
      DELETE FROM third_party_object_associations
      WHERE associatable_type = 'Team'
        AND association_type = 'huddle_channel'
    SQL

    # Clear team_id from huddles
    execute <<-SQL
      UPDATE huddles SET team_id = NULL
    SQL
  end
end
