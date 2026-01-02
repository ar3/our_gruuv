module EmployeesHelper
  def format_snapshot_changes(snapshot, person, organization, current_user: nil, previous_snapshot: nil)
    return nil unless snapshot&.maap_data
    
    # Auto-find previous snapshot if not provided
    resolved_previous_snapshot = previous_snapshot || find_previous_snapshot(snapshot, person, organization)
    
    service = MaapChangeDetectionService.new(
      person: person,
      maap_snapshot: snapshot,
      current_user: current_user || current_company_teammate,
      previous_snapshot: resolved_previous_snapshot
    )
    
    detailed_changes = service.detailed_changes
    format_changes_for_display(detailed_changes, organization)
  end

  def format_snapshot_all_fields(snapshot, person, organization, previous_snapshot: nil)
    return nil unless snapshot&.maap_data
    
    # Auto-find previous snapshot if not provided
    resolved_previous_snapshot = previous_snapshot || find_previous_snapshot(snapshot, person, organization)
    
    old_data = resolved_previous_snapshot&.maap_data || {}
    new_data = snapshot.maap_data
    
    {
      employment: format_employment_all_fields(old_data, new_data, organization),
      assignments: format_assignments_all_fields(old_data, new_data, organization),
      abilities: format_abilities_all_fields(old_data, new_data, organization),
      aspirations: format_aspirations_all_fields(old_data, new_data, organization)
    }
  end
  
  private
  
  def find_previous_snapshot(snapshot, person, organization)
    return nil unless snapshot&.created_at
    
    MaapSnapshot.for_employee(person)
                .for_company(organization)
                .where('created_at < ?', snapshot.created_at)
                .order(created_at: :desc)
                .first
  end

  def parse_date(value)
    return nil unless value.present?
    return value.to_date if value.is_a?(Date) || value.is_a?(Time) || value.is_a?(DateTime)
    Date.parse(value.to_s) rescue nil
  end
  
  def format_changes_for_display(changes_hash, organization)
    formatted = {}
    
    # Format employment changes
    if changes_hash[:employment][:has_changes]
      formatted[:employment] = format_employment_changes(changes_hash[:employment][:details], organization)
    end
    
    # Format assignment changes
    if changes_hash[:assignments][:has_changes]
      formatted[:assignments] = format_assignment_changes(changes_hash[:assignments][:details], organization)
    end
    
    # Format milestone changes
    if changes_hash[:milestones][:has_changes]
      formatted[:milestones] = format_milestone_changes(changes_hash[:milestones][:details], organization)
    end
    
    # Format aspiration changes
    if changes_hash[:aspirations][:has_changes]
      formatted[:aspirations] = format_aspiration_changes(changes_hash[:aspirations][:details], organization)
    end
    
    formatted
  end
  
  def format_employment_changes(changes, organization)
    formatted_changes = []
    
    changes.each do |change|
      case change[:field]
      when 'position'
        # Handle special case where current is the string "none"
        if change[:current] == 'none' || change[:current].blank?
          current_name = 'None'
        else
          current_name = Position.find_by(id: change[:current])&.display_name || 'None'
        end
        
        # Handle special case where proposed is "new position" (string) or an ID
        if change[:proposed] == 'new position' || change[:proposed].blank?
          proposed_name = change[:proposed] == 'new position' ? 'New Position' : 'None'
        else
          proposed_name = Position.find_by(id: change[:proposed])&.display_name || 'None'
        end
        
        formatted_changes << {
          label: 'Position',
          current: current_name,
          proposed: proposed_name
        }
      when 'manager'
        current_name = change[:current].present? ? Person.find_by(id: change[:current])&.display_name : 'None'
        proposed_name = change[:proposed].present? ? Person.find_by(id: change[:proposed])&.display_name : 'None'
        formatted_changes << {
          label: 'Manager',
          current: current_name || 'None',
          proposed: proposed_name || 'None'
        }
      when 'started_at'
        current_date = parse_date(change[:current])
        proposed_date = parse_date(change[:proposed])
        formatted_changes << {
          label: 'Start Date',
          current: current_date ? current_date.strftime('%Y-%m-%d') : 'None',
          proposed: proposed_date ? proposed_date.strftime('%Y-%m-%d') : 'None'
        }
      when 'seat'
        current_name = change[:current].present? ? Seat.find_by(id: change[:current])&.display_name : 'None'
        proposed_name = change[:proposed].present? ? Seat.find_by(id: change[:proposed])&.display_name : 'None'
        formatted_changes << {
          label: 'Seat',
          current: current_name || 'None',
          proposed: proposed_name || 'None'
        }
      when 'employment'
        formatted_changes << {
          label: 'Employment',
          current: 'None',
          proposed: 'New employment created'
        }
      when 'employment_type'
        formatted_changes << {
          label: 'Employment Type',
          current: change[:current].present? ? change[:current].humanize : 'None',
          proposed: change[:proposed].present? ? change[:proposed].humanize : 'None'
        }
      when 'official_position_rating'
        formatted_changes << {
          label: 'Official Position Rating',
          current: change[:current].present? ? change[:current].to_s : 'None',
          proposed: change[:proposed].present? ? change[:proposed].to_s : 'None'
        }
      when 'new_rated_position'
        formatted_changes << {
          label: 'Rated Position',
          current: 'None',
          proposed: 'New rating'
        }
      when 'rated_position_removed'
        formatted_changes << {
          label: 'Rated Position',
          current: 'Had rating',
          proposed: 'None'
        }
      when 'rated_seat'
        current_name = change[:current].present? ? Seat.find_by(id: change[:current])&.display_name : 'None'
        proposed_name = change[:proposed].present? ? Seat.find_by(id: change[:proposed])&.display_name : 'None'
        formatted_changes << {
          label: 'Rated Seat',
          current: current_name || 'None',
          proposed: proposed_name || 'None'
        }
      when 'rated_manager'
        current_name = change[:current].present? ? Person.find_by(id: change[:current])&.display_name : 'None'
        proposed_name = change[:proposed].present? ? Person.find_by(id: change[:proposed])&.display_name : 'None'
        formatted_changes << {
          label: 'Rated Manager',
          current: current_name || 'None',
          proposed: proposed_name || 'None'
        }
      when 'rated_position'
        current_name = change[:current].present? ? Position.find_by(id: change[:current])&.display_name : 'None'
        proposed_name = change[:proposed].present? ? Position.find_by(id: change[:proposed])&.display_name : 'None'
        formatted_changes << {
          label: 'Rated Position',
          current: current_name || 'None',
          proposed: proposed_name || 'None'
        }
      when 'rated_employment_type'
        formatted_changes << {
          label: 'Rated Employment Type',
          current: change[:current].present? ? change[:current].humanize : 'None',
          proposed: change[:proposed].present? ? change[:proposed].humanize : 'None'
        }
      when 'rated_started_at'
        current_date = parse_date(change[:current])
        proposed_date = parse_date(change[:proposed])
        formatted_changes << {
          label: 'Rated Start Date',
          current: current_date ? current_date.strftime('%Y-%m-%d') : 'None',
          proposed: proposed_date ? proposed_date.strftime('%Y-%m-%d') : 'None'
        }
      when 'rated_ended_at'
        current_date = parse_date(change[:current])
        proposed_date = parse_date(change[:proposed])
        formatted_changes << {
          label: 'Rated End Date',
          current: current_date ? current_date.strftime('%Y-%m-%d') : 'None',
          proposed: proposed_date ? proposed_date.strftime('%Y-%m-%d') : 'None'
        }
      end
    end
    
    formatted_changes
  end
  
  def format_assignment_changes(changes, organization)
    formatted_assignments = []
    
    changes.each do |assignment_change|
      assignment_id = assignment_change[:assignment_id]
      assignment = Assignment.find_by(id: assignment_id)
      next unless assignment
      
      assignment_formatted = {
        assignment_name: assignment.title,
        assignment_id: assignment_id,
        changes: []
      }
      
      assignment_change[:changes].each do |change|
        case change[:field]
        when 'anticipated_energy_percentage'
          assignment_formatted[:changes] << {
            label: 'Anticipated Energy',
            current: "#{change[:current]}%",
            proposed: "#{change[:proposed]}%"
          }
        when 'started_at'
          current_date = parse_date(change[:current])
          proposed_date = parse_date(change[:proposed])
          assignment_formatted[:changes] << {
            label: 'Start Date',
            current: current_date ? current_date.strftime('%Y-%m-%d') : 'None',
            proposed: proposed_date ? proposed_date.strftime('%Y-%m-%d') : 'None'
          }
        when 'new_tenure'
          assignment_formatted[:changes] << {
            label: 'New Tenure',
            current: 'None',
            proposed: "#{change[:proposed]}% energy"
          }
        when 'new_assignment'
          assignment_formatted[:changes] << {
            label: 'New Assignment',
            current: 'None',
            proposed: change[:proposed]
          }
        when 'employee_actual_energy'
          assignment_formatted[:changes] << {
            label: 'Employee Actual Energy',
            current: change[:current].present? ? "#{change[:current]}%" : 'Not set',
            proposed: change[:proposed].present? ? "#{change[:proposed]}%" : 'Not set'
          }
        when 'employee_rating'
          assignment_formatted[:changes] << {
            label: 'Employee Rating',
            current: change[:current].present? ? change[:current].humanize : 'Not set',
            proposed: change[:proposed].present? ? change[:proposed].humanize : 'Not set'
          }
        when 'employee_personal_alignment'
          assignment_formatted[:changes] << {
            label: 'Employee Personal Alignment',
            current: change[:current].present? ? change[:current].humanize : 'Not set',
            proposed: change[:proposed].present? ? change[:proposed].humanize : 'Not set'
          }
        when 'employee_private_notes'
          assignment_formatted[:changes] << {
            label: 'Employee Private Notes',
            current: change[:current].present? ? truncate(change[:current], length: 50) : 'Not set',
            proposed: change[:proposed].present? ? truncate(change[:proposed], length: 50) : 'Not set'
          }
        when 'employee_completion'
          assignment_formatted[:changes] << {
            label: 'Employee Completion',
            current: change[:current] ? 'Completed' : 'Not completed',
            proposed: change[:proposed] ? 'Completed' : 'Not completed'
          }
        when 'new_employee_check_in'
          assignment_formatted[:changes] << {
            label: 'Employee Check-in',
            current: 'None',
            proposed: 'New check-in created'
          }
        when 'manager_rating'
          assignment_formatted[:changes] << {
            label: 'Manager Rating',
            current: change[:current].present? ? change[:current].humanize : 'Not set',
            proposed: change[:proposed].present? ? change[:proposed].humanize : 'Not set'
          }
        when 'manager_private_notes'
          assignment_formatted[:changes] << {
            label: 'Manager Private Notes',
            current: change[:current].present? ? truncate(change[:current], length: 50) : 'Not set',
            proposed: change[:proposed].present? ? truncate(change[:proposed], length: 50) : 'Not set'
          }
        when 'manager_completion'
          assignment_formatted[:changes] << {
            label: 'Manager Completion',
            current: change[:current] ? 'Completed' : 'Not completed',
            proposed: change[:proposed] ? 'Completed' : 'Not completed'
          }
        when 'new_manager_check_in'
          assignment_formatted[:changes] << {
            label: 'Manager Check-in',
            current: 'None',
            proposed: 'New check-in created'
          }
        when 'official_rating'
          assignment_formatted[:changes] << {
            label: 'Official Rating',
            current: change[:current].present? ? change[:current].humanize : 'Not set',
            proposed: change[:proposed].present? ? change[:proposed].humanize : 'Not set'
          }
        when 'new_rated_assignment'
          assignment_formatted[:changes] << {
            label: 'Rated Assignment',
            current: 'None',
            proposed: 'New rating'
          }
        when 'rated_assignment_removed'
          assignment_formatted[:changes] << {
            label: 'Rated Assignment',
            current: 'Had rating',
            proposed: 'None'
          }
        when 'rated_anticipated_energy_percentage'
          assignment_formatted[:changes] << {
            label: 'Rated Anticipated Energy',
            current: "#{change[:current]}%",
            proposed: "#{change[:proposed]}%"
          }
        when 'rated_started_at'
          current_date = parse_date(change[:current])
          proposed_date = parse_date(change[:proposed])
          assignment_formatted[:changes] << {
            label: 'Rated Start Date',
            current: current_date ? current_date.strftime('%Y-%m-%d') : 'None',
            proposed: proposed_date ? proposed_date.strftime('%Y-%m-%d') : 'None'
          }
        when 'rated_ended_at'
          current_date = parse_date(change[:current])
          proposed_date = parse_date(change[:proposed])
          assignment_formatted[:changes] << {
            label: 'Rated End Date',
            current: current_date ? current_date.strftime('%Y-%m-%d') : 'None',
            proposed: proposed_date ? proposed_date.strftime('%Y-%m-%d') : 'None'
          }
        when 'shared_notes'
          assignment_formatted[:changes] << {
            label: 'Shared Notes',
            current: change[:current].present? ? truncate(change[:current], length: 50) : 'Not set',
            proposed: change[:proposed].present? ? truncate(change[:proposed], length: 50) : 'Not set'
          }
        when 'official_completion'
          assignment_formatted[:changes] << {
            label: 'Official Completion',
            current: change[:current] ? 'Completed' : 'Not completed',
            proposed: change[:proposed] ? 'Completed' : 'Not completed'
          }
        when 'finalized_by'
          current_name = change[:current].present? ? Person.find_by(id: change[:current])&.display_name : 'None'
          proposed_name = change[:proposed].present? ? Person.find_by(id: change[:proposed])&.display_name : 'None'
          assignment_formatted[:changes] << {
            label: 'Finalized By',
            current: current_name || 'None',
            proposed: proposed_name || 'None'
          }
        when 'new_official_check_in'
          assignment_formatted[:changes] << {
            label: 'Official Check-in',
            current: 'None',
            proposed: 'New check-in finalized'
          }
        end
      end
      
      formatted_assignments << assignment_formatted if assignment_formatted[:changes].any?
    end
    
    formatted_assignments
  end
  
  def format_milestone_changes(changes, organization)
    formatted_milestones = []
    
    changes.each do |milestone_change|
      ability_id = milestone_change[:ability_id]
      ability = Ability.find_by(id: ability_id)
      next unless ability
      
      milestone_formatted = {
        ability_name: ability.name,
        ability_id: ability_id,
        changes: []
      }
      
      milestone_change[:changes].each do |change|
        case change[:field]
        when 'milestone_level'
          milestone_formatted[:changes] << {
            label: 'Milestone Level',
            current: change[:current].present? ? "Level #{change[:current]}" : 'None',
            proposed: change[:proposed].present? ? "Level #{change[:proposed]}" : 'None'
          }
        when 'certified_by'
          current_name = change[:current].present? ? Person.find_by(id: change[:current])&.display_name : 'None'
          proposed_name = change[:proposed].present? ? Person.find_by(id: change[:proposed])&.display_name : 'None'
          milestone_formatted[:changes] << {
            label: 'Certified By',
            current: current_name || 'None',
            proposed: proposed_name || 'None'
          }
        when 'attained_at'
          current_date = parse_date(change[:current])
          proposed_date = parse_date(change[:proposed])
          milestone_formatted[:changes] << {
            label: 'Attained At',
            current: current_date ? current_date.strftime('%Y-%m-%d') : 'None',
            proposed: proposed_date ? proposed_date.strftime('%Y-%m-%d') : 'None'
          }
        end
      end
      
      formatted_milestones << milestone_formatted if milestone_formatted[:changes].any?
    end
    
    formatted_milestones
  end
  
  def format_aspiration_changes(changes, organization)
    formatted_aspirations = []
    
    changes.each do |aspiration_change|
      aspiration_id = aspiration_change[:aspiration_id]
      aspiration = Aspiration.find_by(id: aspiration_id)
      next unless aspiration
      
      aspiration_formatted = {
        aspiration_name: aspiration.name || "Aspiration #{aspiration_id}",
        aspiration_id: aspiration_id,
        changes: []
      }
      
      aspiration_change[:changes].each do |change|
        case change[:field]
        when 'official_rating'
          aspiration_formatted[:changes] << {
            label: 'Official Rating',
            current: change[:current].present? ? change[:current].humanize : 'Not set',
            proposed: change[:proposed].present? ? change[:proposed].humanize : 'Not set'
          }
        when 'new_aspiration_rating'
          aspiration_formatted[:changes] << {
            label: 'New Aspiration Rating',
            current: 'None',
            proposed: change[:proposed].present? ? change[:proposed].humanize : 'Not set'
          }
        end
      end
      
      formatted_aspirations << aspiration_formatted if aspiration_formatted[:changes].any?
    end
    
    formatted_aspirations
  end

  def format_employment_all_fields(old_data, new_data, organization)
    old_position = old_data['position'] || {}
    new_position = new_data['position'] || {}
    
    old_rated = old_position['rated_position'] || {}
    new_rated = new_position['rated_position'] || {}
    
    fields = []
    
    # Current position fields
    fields << {
      label: 'Position',
      old: format_position_value(old_position['position_id']),
      new: format_position_value(new_position['position_id'])
    }
    
    fields << {
      label: 'Manager',
      old: format_company_teammate_value(old_position['manager_teammate_id']),
      new: format_company_teammate_value(new_position['manager_teammate_id'])
    }
    
    fields << {
      label: 'Seat',
      old: format_seat_value(old_position['seat_id']),
      new: format_seat_value(new_position['seat_id'])
    }
    
    fields << {
      label: 'Employment Type',
      old: format_employment_type_value(old_position['employment_type']),
      new: format_employment_type_value(new_position['employment_type'])
    }
    
    # Rated position fields
    fields << {
      label: 'Rated Position',
      old: format_position_value(old_rated['position_id']),
      new: format_position_value(new_rated['position_id'])
    }
    
    fields << {
      label: 'Rated Manager',
      old: format_company_teammate_value(old_rated['manager_teammate_id']),
      new: format_company_teammate_value(new_rated['manager_teammate_id'])
    }
    
    fields << {
      label: 'Rated Seat',
      old: format_seat_value(old_rated['seat_id']),
      new: format_seat_value(new_rated['seat_id'])
    }
    
    fields << {
      label: 'Rated Employment Type',
      old: format_employment_type_value(old_rated['employment_type']),
      new: format_employment_type_value(new_rated['employment_type'])
    }
    
    fields << {
      label: 'Official Position Rating',
      old: old_rated['official_position_rating'].present? ? old_rated['official_position_rating'].to_s : 'None',
      new: new_rated['official_position_rating'].present? ? new_rated['official_position_rating'].to_s : 'None'
    }
    
    fields << {
      label: 'Rated Start Date',
      old: format_date_value(old_rated['started_at']),
      new: format_date_value(new_rated['started_at'])
    }
    
    fields << {
      label: 'Rated End Date',
      old: format_date_value(old_rated['ended_at']),
      new: format_date_value(new_rated['ended_at'])
    }
    
    # Filter out fields starting with "Rated" (case-insensitive)
    fields.reject { |field| field[:label].downcase.start_with?('rated') }
  end

  def format_assignments_all_fields(old_data, new_data, organization)
    old_assignments = old_data['assignments'] || []
    new_assignments = new_data['assignments'] || []
    
    # Get all assignment IDs from both snapshots
    all_assignment_ids = (old_assignments.map { |a| a['assignment_id'] } + new_assignments.map { |a| a['assignment_id'] }).uniq.compact
    assignments = Assignment.where(id: all_assignment_ids).index_by(&:id)
    
    formatted_assignments = []
    
    all_assignment_ids.each do |assignment_id|
      assignment = assignments[assignment_id]
      next unless assignment
      
      old_assignment = old_assignments.find { |a| a['assignment_id'] == assignment_id } || {}
      new_assignment = new_assignments.find { |a| a['assignment_id'] == assignment_id } || {}
      
      old_rated = old_assignment['rated_assignment'] || {}
      new_rated = new_assignment['rated_assignment'] || {}
      
      assignment_fields = []
      
      # Current assignment fields
      assignment_fields << {
        label: 'Anticipated Energy',
        old: old_assignment['anticipated_energy_percentage'].present? ? "#{old_assignment['anticipated_energy_percentage']}%" : 'None',
        new: new_assignment['anticipated_energy_percentage'].present? ? "#{new_assignment['anticipated_energy_percentage']}%" : 'None'
      }
      
      # Rated assignment fields
      assignment_fields << {
        label: 'Rated Anticipated Energy',
        old: old_rated['anticipated_energy_percentage'].present? ? "#{old_rated['anticipated_energy_percentage']}%" : 'None',
        new: new_rated['anticipated_energy_percentage'].present? ? "#{new_rated['anticipated_energy_percentage']}%" : 'None'
      }
      
      assignment_fields << {
        label: 'Official Rating',
        old: old_rated['official_rating'].present? ? old_rated['official_rating'].humanize : 'None',
        new: new_rated['official_rating'].present? ? new_rated['official_rating'].humanize : 'None'
      }
      
      assignment_fields << {
        label: 'Rated Start Date',
        old: format_date_value(old_rated['started_at']),
        new: format_date_value(new_rated['started_at'])
      }
      
      assignment_fields << {
        label: 'Rated End Date',
        old: format_date_value(old_rated['ended_at']),
        new: format_date_value(new_rated['ended_at'])
      }
      
      # Filter out fields starting with "Rated" (case-insensitive)
      filtered_fields = assignment_fields.reject { |field| field[:label].downcase.start_with?('rated') }
      
      formatted_assignments << {
        assignment_name: assignment.title,
        assignment_id: assignment_id,
        fields: filtered_fields
      }
    end
    
    formatted_assignments
  end

  def format_abilities_all_fields(old_data, new_data, organization)
    old_abilities = old_data['abilities'] || []
    new_abilities = new_data['abilities'] || []
    
    # Get all ability IDs from both snapshots
    all_ability_ids = (old_abilities.map { |a| a['ability_id'] } + new_abilities.map { |a| a['ability_id'] }).uniq.compact
    abilities = Ability.where(id: all_ability_ids).index_by(&:id)
    
    formatted_abilities = []
    
    all_ability_ids.each do |ability_id|
      ability = abilities[ability_id]
      next unless ability
      
      old_ability = old_abilities.find { |a| a['ability_id'] == ability_id } || {}
      new_ability = new_abilities.find { |a| a['ability_id'] == ability_id } || {}
      
      ability_fields = []
      
      ability_fields << {
        label: 'Milestone Level',
        old: old_ability['milestone_level'].present? ? "Level #{old_ability['milestone_level']}" : 'None',
        new: new_ability['milestone_level'].present? ? "Level #{new_ability['milestone_level']}" : 'None'
      }
      
      ability_fields << {
        label: 'Certified By',
        old: format_person_value(old_ability['certified_by_id']),
        new: format_person_value(new_ability['certified_by_id'])
      }
      
      ability_fields << {
        label: 'Attained At',
        old: format_date_value(old_ability['attained_at']),
        new: format_date_value(new_ability['attained_at'])
      }
      
      formatted_abilities << {
        ability_name: ability.name,
        ability_id: ability_id,
        fields: ability_fields
      }
    end
    
    formatted_abilities
  end

  def format_aspirations_all_fields(old_data, new_data, organization)
    old_aspirations = old_data['aspirations'] || []
    new_aspirations = new_data['aspirations'] || []
    
    # Get all aspiration IDs from both snapshots
    all_aspiration_ids = (old_aspirations.map { |a| a['aspiration_id'] } + new_aspirations.map { |a| a['aspiration_id'] }).uniq.compact
    aspirations = Aspiration.where(id: all_aspiration_ids).index_by(&:id)
    
    formatted_aspirations = []
    
    all_aspiration_ids.each do |aspiration_id|
      aspiration = aspirations[aspiration_id]
      next unless aspiration
      
      old_aspiration = old_aspirations.find { |a| a['aspiration_id'] == aspiration_id } || {}
      new_aspiration = new_aspirations.find { |a| a['aspiration_id'] == aspiration_id } || {}
      
      aspiration_fields = []
      
      aspiration_fields << {
        label: 'Official Rating',
        old: old_aspiration['official_rating'].present? ? old_aspiration['official_rating'].humanize : 'None',
        new: new_aspiration['official_rating'].present? ? new_aspiration['official_rating'].humanize : 'None'
      }
      
      formatted_aspirations << {
        aspiration_name: aspiration.name || "Aspiration #{aspiration_id}",
        aspiration_id: aspiration_id,
        fields: aspiration_fields
      }
    end
    
    formatted_aspirations
  end

  def format_position_value(position_id)
    return 'None' unless position_id.present?
    Position.find_by(id: position_id)&.display_name || 'None'
  end

  def format_person_value(person_id)
    return 'None' unless person_id.present?
    Person.find_by(id: person_id)&.display_name || 'None'
  end

  def format_company_teammate_value(company_teammate_id)
    return 'None' unless company_teammate_id.present?
    CompanyTeammate.find_by(id: company_teammate_id)&.person&.display_name || 'None'
  end

  def format_seat_value(seat_id)
    return 'None' unless seat_id.present?
    Seat.find_by(id: seat_id)&.display_name || 'None'
  end

  def format_employment_type_value(employment_type)
    return 'None' unless employment_type.present?
    employment_type.humanize
  end

  def format_date_value(date_value)
    return 'None' unless date_value.present?
    date = parse_date(date_value)
    date ? date.strftime('%Y-%m-%d') : 'None'
  end
end

