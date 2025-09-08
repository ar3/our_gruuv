#!/usr/bin/env ruby
# MAAP Data Import Script
# Parses amy_maap.md and creates all necessary data for the demo

require_relative '../../config/environment'

class MaapDataImporter
  def initialize
    @errors = []
    @created_count = 0
    @skipped_count = 0
    @updated_count = 0
  end

  def run
    puts "🚀 Starting MAAP Data Import..."
    puts "=" * 50

    begin
      create_organization
      create_abilities
      create_assignments
      create_position_data
      create_people
      create_relationships
      
      puts "\n✅ Import completed successfully!"
      print_summary
    rescue => e
      @errors << "Fatal error: #{e.message}"
      puts "\n❌ Import failed with fatal error: #{e.message}"
      print_summary
      exit 1
    end
  end

  private

  def create_organization
    puts "\n📁 Creating organization..."
    
    @organization = Organization.find_or_create_by(name: 'CareerPlug') do |org|
      org.type = 'Company'
      puts "  ✅ Created CareerPlug organization"
      @created_count += 1
    end
    
    if @organization.persisted? && @organization.previously_new_record?
      puts "  ✅ Created CareerPlug organization"
      @created_count += 1
    else
      puts "  ⏭️  CareerPlug organization already exists"
      @skipped_count += 1
    end
  end

  def create_abilities
    puts "\n🎯 Creating abilities..."
    
    ability_data = [
      { name: 'Communication', description: 'Ability to communicate effectively with others' },
      { name: 'Executive Coaching', description: 'Ability to coach and develop executive-level skills' },
      { name: 'Learning & Development', description: 'Ability to design and deliver learning programs' },
      { name: 'Emotional Intelligence', description: 'Ability to understand and manage emotions' },
      { name: 'Project Management', description: 'Ability to plan and execute projects effectively' },
      { name: 'Data Insights', description: 'Ability to analyze data and derive insights' },
      { name: 'Tool Proficiency', description: 'Ability to master and effectively use tools' },
      { name: 'Interviewing', description: 'Ability to conduct effective interviews' },
      { name: 'Training', description: 'Ability to train and develop others' }
    ]

    @abilities = {}
    
    ability_data.each do |data|
      ability = Ability.find_or_create_by(name: data[:name], organization: @organization) do |a|
        a.description = data[:description]
        a.semantic_version = '1.0.0'
        a.created_by = Person.first || Person.create!(first_name: 'System', last_name: 'User', email: 'system@careerplug.com')
        a.updated_by = Person.first || Person.create!(first_name: 'System', last_name: 'User', email: 'system@careerplug.com')
      end
      
      @abilities[data[:name]] = ability
      
      if ability.persisted? && ability.previously_new_record?
        puts "  ✅ Created ability: #{data[:name]}"
        @created_count += 1
      else
        puts "  ⏭️  Ability already exists: #{data[:name]}"
        @skipped_count += 1
      end
    end
  end

  def create_assignments
    puts "\n📋 Creating assignments..."
    
    assignment_data = [
      {
        title: 'Employee Growth Plan Champion',
        tagline: 'Champion of employee development, operationalizing the growth mindset',
        description: 'As a champion of employee development, you help us live our Keep Growing value everyday by operationalizing the growth mindset and helping individuals, and therefore the company, reach its potential.',
        abilities: ['Executive Coaching', 'Learning & Development', 'Emotional Intelligence'],
        energy_percentage: 30,
        required: true
      },
      {
        title: 'Quarterly Conversation Coordinator',
        tagline: 'Keep the company accountable to holding regular performance reviews',
        description: 'Employees deserve to know where they stand, regularly. You keep the company accountable to holding regular performance reviews and growth conversations.',
        abilities: ['Project Management', 'Communication', 'Data Insights'],
        energy_percentage: 20,
        required: true
      },
      {
        title: 'Learning Librarian',
        tagline: 'Curation of learning and development resources for all',
        description: 'A curation of learning and development resources for all. The Learning Librarian makes it easy for employees to have the resources they need to upskill and growth.',
        abilities: ['Communication', 'Learning & Development', 'Data Insights'],
        energy_percentage: nil,
        required: true
      },
      {
        title: 'Tooling Admin - CultureAmp',
        tagline: 'Ensure our tools are maintained, supporting business needs, and delivering ROI',
        description: 'We ensure our tools are maintained, supporting business needs, and delivering ROI.',
        abilities: ['Communication', 'Tool Proficiency', 'Data Insights'],
        energy_percentage: nil,
        required: true
      },
      {
        title: 'Lifeline Interview Facilitator',
        tagline: 'Guide candidates in telling their story and connecting it to career goals',
        description: 'Hiring managers need to understand someone\'s career journey, and their aspirations for the future, to make informed decisions in the final stages of the hiring process.',
        abilities: ['Interviewing', 'Emotional Intelligence'],
        energy_percentage: nil,
        required: false
      },
      {
        title: 'New Hire Onboarding Agent',
        tagline: 'Set new hires up for success',
        description: 'We set new hires up for success!',
        abilities: ['Training', 'Communication'],
        energy_percentage: nil,
        required: false
      }
    ]

    @assignments = {}
    
    assignment_data.each do |data|
      assignment = Assignment.find_or_create_by(title: data[:title], company: @organization) do |a|
        a.tagline = data[:tagline]
        a.required_activities = data[:description]
      end
      
      @assignments[data[:title]] = assignment
      
      if assignment.persisted? && assignment.previously_new_record?
        puts "  ✅ Created assignment: #{data[:title]}"
        @created_count += 1
        
        # Create assignment-ability relationships
        data[:abilities].each do |ability_name|
          ability = @abilities[ability_name]
          if ability
            assignment_ability = AssignmentAbility.find_or_create_by(assignment: assignment, ability: ability) do |aa|
              aa.milestone_level = 2 # Default milestone level
            end
            
            if assignment_ability.persisted? && assignment_ability.previously_new_record?
              puts "    ✅ Added ability requirement: #{ability_name} (Level 2)"
              @created_count += 1
            end
          else
            @errors << "Ability not found: #{ability_name} for assignment #{data[:title]}"
          end
        end
      else
        puts "  ⏭️  Assignment already exists: #{data[:title]}"
        @skipped_count += 1
      end
    end
  end

  def create_position_data
    puts "\n💼 Creating position data..."
    
    # Create Position Major Level
    @position_major_level = PositionMajorLevel.find_or_create_by(set_name: 'Management', major_level: 1) do |pml|
      pml.description = 'Management level positions'
    end
    
    if @position_major_level.persisted? && @position_major_level.previously_new_record?
      puts "  ✅ Created position major level: Management Level 1"
      @created_count += 1
    else
      puts "  ⏭️  Position major level already exists: Management Level 1"
      @skipped_count += 1
    end
    
    # Create Position Type
    @position_type = PositionType.find_or_create_by(external_title: 'Growth & Development Manager', organization: @organization, position_major_level: @position_major_level) do |pt|
      pt.position_summary = 'Manager responsible for employee growth and development programs'
    end
    
    if @position_type.persisted? && @position_type.previously_new_record?
      puts "  ✅ Created position type: Growth & Development Manager"
      @created_count += 1
    else
      puts "  ⏭️  Position type already exists: Growth & Development Manager"
      @skipped_count += 1
    end
    
    # Create Position Levels
    @position_levels = {}
    [1, 2, 3].each do |level|
      position_level = PositionLevel.find_or_create_by(level: "#{level}.0", position_major_level: @position_major_level) do |pl|
        # PositionLevel only has level field, no additional attributes needed
      end
      
      @position_levels[level] = position_level
      
      if position_level.persisted? && position_level.previously_new_record?
        puts "  ✅ Created position level: Level #{level}.0"
        @created_count += 1
      else
        puts "  ⏭️  Position level already exists: Level #{level}.0"
        @skipped_count += 1
      end
    end
    
    # Create Positions
    @positions = {}
    [1, 2, 3].each do |level|
      position = Position.find_or_create_by(position_type: @position_type, position_level: @position_levels[level]) do |p|
        # Position will be created with default attributes
      end
      
      @positions[level] = position
      
      if position.persisted? && position.previously_new_record?
        puts "  ✅ Created position: Growth & Development Manager Level #{level}"
        @created_count += 1
      else
        puts "  ⏭️  Position already exists: Growth & Development Manager Level #{level}"
        @skipped_count += 1
      end
    end
  end

  def create_people
    puts "\n👥 Creating people..."
    
    # Create Amy Campero
    @amy = Person.find_or_create_by(email: 'amy.campero@careerplug.com') do |p|
      p.first_name = 'Amy'
      p.last_name = 'Campero'
    end
    
    if @amy.persisted? && @amy.previously_new_record?
      puts "  ✅ Created person: Amy Campero"
      @created_count += 1
    else
      puts "  ⏭️  Person already exists: Amy Campero"
      @skipped_count += 1
    end
    
    # Create Natalie Morgan
    @natalie = Person.find_or_create_by(email: 'natalie.morgan@careerplug.com') do |p|
      p.first_name = 'Natalie'
      p.last_name = 'Morgan'
    end
    
    if @natalie.persisted? && @natalie.previously_new_record?
      puts "  ✅ Created person: Natalie Morgan"
      @created_count += 1
    else
      puts "  ⏭️  Person already exists: Natalie Morgan"
      @skipped_count += 1
    end
  end

  def create_relationships
    puts "\n🔗 Creating relationships..."
    
    # Create position-assignment relationships first
    create_position_assignments
    
    # Create employment tenures
    create_employment_tenure(@amy, 'Growth & Development Manager')
    create_employment_tenure(@natalie, 'Sr. Director People')
    
    # Create assignment tenures for Amy
    create_assignment_tenures(@amy)
    
    # Create person milestones for Amy
    create_person_milestones(@amy)
  end

  def create_employment_tenure(person, position_title)
    employment_tenure = EmploymentTenure.find_or_create_by(person: person, company: @organization) do |et|
      et.started_at = 6.months.ago
      et.position = @positions[1] # Use Level 1 position for now
      et.manager = person == @amy ? @natalie : nil
    end
    
    if employment_tenure.persisted? && employment_tenure.previously_new_record?
      puts "  ✅ Created employment tenure: #{person.first_name} #{person.last_name} as #{position_title}"
      @created_count += 1
    else
      puts "  ⏭️  Employment tenure already exists: #{person.first_name} #{person.last_name} as #{position_title}"
      @skipped_count += 1
    end
  end

  def create_assignment_tenures(person)
    if person == @amy
      # Amy's current assignments with energy percentages
      assignment_tenures = [
        { assignment: @assignments['Employee Growth Plan Champion'], energy: 30 },
        { assignment: @assignments['Quarterly Conversation Coordinator'], energy: 20 },
        { assignment: @assignments['Learning Librarian'], energy: 25 },
        { assignment: @assignments['Tooling Admin - CultureAmp'], energy: 15 }
      ]
      
      assignment_tenures.each do |data|
        assignment_tenure = AssignmentTenure.find_or_create_by(person: person, assignment: data[:assignment]) do |at|
          at.started_at = 3.months.ago
          at.anticipated_energy_percentage = data[:energy]
        end
        
        if assignment_tenure.persisted? && assignment_tenure.previously_new_record?
          puts "  ✅ Created assignment tenure: #{person.first_name} #{person.last_name} - #{data[:assignment].title} (#{data[:energy]}%)"
          @created_count += 1
        else
          puts "  ⏭️  Assignment tenure already exists: #{person.first_name} #{person.last_name} - #{data[:assignment].title}"
          @skipped_count += 1
        end
      end
    end
  end

  def create_person_milestones(person)
    if person == @amy
      # Amy's current milestones
      milestones = [
        { ability: @abilities['Communication'], level: 2 },
        { ability: @abilities['Executive Coaching'], level: 2 }
      ]
      
      milestones.each do |data|
        person_milestone = PersonMilestone.find_or_create_by(person: person, ability: data[:ability], milestone_level: data[:level]) do |pm|
          pm.certified_by = @natalie
          pm.attained_at = 2.months.ago
        end
        
        if person_milestone.persisted? && person_milestone.previously_new_record?
          puts "  ✅ Created person milestone: #{person.first_name} #{person.last_name} - #{data[:ability].name} Level #{data[:level]}"
          @created_count += 1
        else
          puts "  ⏭️  Person milestone already exists: #{person.first_name} #{person.last_name} - #{data[:ability].name} Level #{data[:level]}"
          @skipped_count += 1
        end
      end
    end
  end

  def create_position_assignments
    # Create position-assignment relationships for all levels
    [1, 2, 3].each do |level|
      position = @positions[level]
      
      # Required assignments
      required_assignments = [
        @assignments['Employee Growth Plan Champion'],
        @assignments['Quarterly Conversation Coordinator'],
        @assignments['Learning Librarian'],
        @assignments['Tooling Admin - CultureAmp']
      ]
      
      required_assignments.each do |assignment|
        position_assignment = PositionAssignment.find_or_create_by(position: position, assignment: assignment) do |pa|
          pa.assignment_type = 'required'
          pa.min_estimated_energy = assignment.title == 'Employee Growth Plan Champion' ? 25 : 10
          pa.max_estimated_energy = assignment.title == 'Employee Growth Plan Champion' ? 35 : 20
        end
        
        if position_assignment.persisted? && position_assignment.previously_new_record?
          puts "  ✅ Created position assignment: Level #{level} - #{assignment.title} (required)"
          @created_count += 1
        else
          puts "  ⏭️  Position assignment already exists: Level #{level} - #{assignment.title}"
          @skipped_count += 1
        end
      end
      
      # Optional assignments
      optional_assignments = [
        @assignments['Lifeline Interview Facilitator'],
        @assignments['New Hire Onboarding Agent']
      ]
      
      optional_assignments.each do |assignment|
        position_assignment = PositionAssignment.find_or_create_by(position: position, assignment: assignment) do |pa|
          pa.assignment_type = 'suggested'
          pa.min_estimated_energy = 5
          pa.max_estimated_energy = 15
        end
        
        if position_assignment.persisted? && position_assignment.previously_new_record?
          puts "  ✅ Created position assignment: Level #{level} - #{assignment.title} (suggested)"
          @created_count += 1
        else
          puts "  ⏭️  Position assignment already exists: Level #{level} - #{assignment.title}"
          @skipped_count += 1
        end
      end
    end
  end

  def print_summary
    puts "\n" + "=" * 50
    puts "📊 IMPORT SUMMARY"
    puts "=" * 50
    puts "✅ Created: #{@created_count} records"
    puts "⏭️  Skipped: #{@skipped_count} records"
    puts "🔄 Updated: #{@updated_count} records"
    
    if @errors.any?
      puts "\n❌ ERRORS (#{@errors.count}):"
      @errors.each_with_index do |error, index|
        puts "  #{index + 1}. #{error}"
      end
    else
      puts "\n🎉 No errors encountered!"
    end
    
    puts "\n📋 DATA CREATED:"
    puts "  • Organization: CareerPlug"
    puts "  • Abilities: #{@abilities&.keys&.join(', ') || 'None'}"
    puts "  • Assignments: #{@assignments&.keys&.join(', ') || 'None'}"
    puts "  • Position Type: Growth & Development Manager"
    puts "  • Position Levels: 1, 2, 3"
    puts "  • People: Amy Campero, Natalie Morgan"
    puts "  • Amy's Milestones: Communication Level 2, Executive Coaching Level 2"
    puts "  • Amy's Assignments: Employee Growth Plan Champion (30%), Quarterly Conversation Coordinator (20%), Learning Librarian (25%), Tooling Admin - CultureAmp (15%)"
    puts "=" * 50
  end
end

# Run the importer
if __FILE__ == $0
  importer = MaapDataImporter.new
  importer.run
end
