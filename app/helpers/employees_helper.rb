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
end

