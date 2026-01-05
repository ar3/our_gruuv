require 'rails_helper'

RSpec.describe AssignmentsAndAbilitiesUploadParser, type: :service do
  let(:valid_csv_content) do
    <<~CSV
      Assignment,Position(s),Team(s),Tagline,Outcomes,Abilities,Required Activities
      Employee Growth Plan Champion,"Growth & Development Manager",People,"As a champion of employee development, you help us live our Keep Growing value everyday by operationalizing the growth mindset and helping individuals, and therefore the company, reach its potential. ","% of employees with a goal in OurGruuv
      % of employees completing skills & dream goals 
      % of position filled by internal candidates 
      % of employees who earn level increases/promotions ","Executive Coaching 
      Learning & Development 
      Emotional Intelligence ","Host company-wide training sessions on growth plan development 
      Conduct one-on-one coaching sessions with employees to help them set and achieve their skill and optional dream goals.
      Track and report on the percentage of skill/dream goal completions and share success stories to encourage participation."
    CSV
  end

  let(:parser) { described_class.new(valid_csv_content) }

  describe '#initialize' do
    it 'sets file_content and initializes errors and parsed_data' do
      expect(parser.file_content).to eq(valid_csv_content)
      expect(parser.errors).to eq([])
      expect(parser.parsed_data).to eq({})
    end
  end

  describe '#parse' do
    context 'with valid CSV content' do
      it 'returns true and populates parsed_data' do
        expect(parser.parse).to be true
        expect(parser.errors).to be_empty
        expect(parser.parsed_data).to have_key(:assignments)
        expect(parser.parsed_data).to have_key(:abilities)
        expect(parser.parsed_data).to have_key(:assignment_abilities)
        expect(parser.parsed_data).to have_key(:position_assignments)
      end

      it 'parses assignments correctly' do
        parser.parse
        assignments = parser.parsed_data[:assignments]
        
        expect(assignments.length).to eq(1)
        expect(assignments.first['title']).to eq('Employee Growth Plan Champion')
        expect(assignments.first['tagline']).to be_present
      end

      it 'parses abilities correctly' do
        parser.parse
        abilities = parser.parsed_data[:abilities]
        
        expect(abilities.length).to be >= 3
        ability_names = abilities.map { |a| a['name'] }
        expect(ability_names).to include('Executive Coaching')
        expect(ability_names).to include('Learning & Development')
        expect(ability_names).to include('Emotional Intelligence')
      end

      it 'parses position titles correctly' do
        parser.parse
        position_assignments = parser.parsed_data[:position_assignments]
        
        expect(position_assignments.length).to eq(1)
        expect(position_assignments.first['position_title']).to eq('Growth & Development Manager')
      end

      it 'parses department names correctly' do
        parser.parse
        position_assignments = parser.parsed_data[:position_assignments]
        
        expect(position_assignments.first['department_names']).to include('People')
      end

      it 'parses department names with newlines' do
        csv_with_newline_dept = <<~CSV
          Assignment,Position(s),Team(s),Tagline,Outcomes,Abilities,Required Activities
          Test Assignment,Position,Engineering
          Sales,Tagline,Outcome,Ability,Activity
        CSV
        parser_newline = described_class.new(csv_with_newline_dept)
        parser_newline.parse
        position_assignments = parser_newline.parsed_data[:position_assignments]
        
        expect(position_assignments.first['department_names']).to include('Engineering')
      end

      it 'parses department names with mixed comma and newline' do
        csv_with_mixed_dept = <<~CSV
          Assignment,Position(s),Team(s),Tagline,Outcomes,Abilities,Required Activities
          Test Assignment,Position,"Engineering
          Sales",Tagline,Outcome,Ability,Activity
        CSV
        parser_mixed = described_class.new(csv_with_mixed_dept)
        parser_mixed.parse
        position_assignments = parser_mixed.parsed_data[:position_assignments]
        
        # Multiple departments should result in empty array
        expect(position_assignments.first['department_names']).to eq([])
      end

      it 'treats multiple departments as empty string' do
        csv_with_multiple_depts = <<~CSV
          Assignment,Position(s),Team(s),Tagline,Outcomes,Abilities,Required Activities
          Test Assignment,Position,"Engineering, Sales",Tagline,Outcome,Ability,Activity
        CSV
        parser_multiple = described_class.new(csv_with_multiple_depts)
        parser_multiple.parse
        position_assignments = parser_multiple.parsed_data[:position_assignments]
        
        # Multiple departments should result in empty array
        expect(position_assignments.first['department_names']).to eq([])
      end

      it 'parses outcomes as multiline' do
        parser.parse
        assignment = parser.parsed_data[:assignments].first
        expect(assignment['outcomes']).to be_an(Array)
        expect(assignment['outcomes'].length).to be > 1
      end

      it 'parses required activities as multiline' do
        parser.parse
        assignment = parser.parsed_data[:assignments].first
        expect(assignment['required_activities']).to be_an(Array)
        expect(assignment['required_activities'].length).to be > 1
      end

      it 'tracks row numbers' do
        parser.parse
        assignment = parser.parsed_data[:assignments].first
        expect(assignment['row']).to eq(2) # Header is row 1, first data row is row 2
      end
    end

    context 'with invalid CSV content' do
      let(:invalid_csv) { "Invalid,Headers\nValue1,Value2" }
      let(:parser) { described_class.new(invalid_csv) }

      it 'returns false and adds errors' do
        expect(parser.parse).to be false
        expect(parser.errors).not_to be_empty
      end
    end

    context 'with empty content' do
      let(:parser) { described_class.new('') }

      it 'returns false and adds error' do
        expect(parser.parse).to be false
        expect(parser.errors).to include("File content is required")
      end
    end

    context 'with comma-separated positions' do
      let(:csv_with_multiple_positions) do
        <<~CSV
          Assignment,Position(s),Team(s),Tagline,Outcomes,Abilities,Required Activities
          Test Assignment,"Position 1, Position 2",People,Tagline,Outcome,Ability,Activity
        CSV
      end
      let(:parser) { described_class.new(csv_with_multiple_positions) }

      it 'splits positions correctly' do
        parser.parse
        position_assignments = parser.parsed_data[:position_assignments]
        expect(position_assignments.length).to eq(2)
        expect(position_assignments.map { |pa| pa['position_title'] }).to include('Position 1')
        expect(position_assignments.map { |pa| pa['position_title'] }).to include('Position 2')
      end
    end

    context 'with newline-separated positions' do
      let(:csv_with_newline_positions) do
        <<~CSV
          Assignment,Position(s),Team(s),Tagline,Outcomes,Abilities,Required Activities
          Test Assignment,"Position 1
          Position 2",People,Tagline,Outcome,Ability,Activity
        CSV
      end
      let(:parser) { described_class.new(csv_with_newline_positions) }

      it 'splits positions by newline correctly' do
        parser.parse
        position_assignments = parser.parsed_data[:position_assignments]
        expect(position_assignments.length).to eq(2)
        expect(position_assignments.map { |pa| pa['position_title'] }).to include('Position 1')
        expect(position_assignments.map { |pa| pa['position_title'] }).to include('Position 2')
      end
    end

    context 'with mixed comma and newline-separated positions' do
      let(:csv_with_mixed_positions) do
        <<~CSV
          Assignment,Position(s),Team(s),Tagline,Outcomes,Abilities,Required Activities
          Test Assignment,"Position 1, Position 2
          Position 3",People,Tagline,Outcome,Ability,Activity
        CSV
      end
      let(:parser) { described_class.new(csv_with_mixed_positions) }

      it 'splits positions by both comma and newline correctly' do
        parser.parse
        position_assignments = parser.parsed_data[:position_assignments]
        expect(position_assignments.length).to eq(3)
        expect(position_assignments.map { |pa| pa['position_title'] }).to include('Position 1')
        expect(position_assignments.map { |pa| pa['position_title'] }).to include('Position 2')
        expect(position_assignments.map { |pa| pa['position_title'] }).to include('Position 3')
      end
    end
  end

  describe '#preview_actions' do
    it 'returns empty hash when parsed_data is empty' do
      expect(parser.preview_actions).to eq({})
    end

    it 'returns structured preview actions after parsing' do
      parser.parse
      preview = parser.preview_actions
      
      expect(preview).to have_key('assignments')
      expect(preview).to have_key('abilities')
      expect(preview).to have_key('assignment_abilities')
      expect(preview).to have_key('position_assignments')
    end
  end

  describe '#enhanced_preview_actions' do
    let(:organization) { create(:organization, type: 'Company') }
    let(:parser) { described_class.new(valid_csv_content, organization) }

    it 'returns enhanced preview with action indicators' do
      parser.parse
      enhanced = parser.enhanced_preview_actions
      
      expect(enhanced['assignments'].first).to have_key('action')
      expect(enhanced['abilities'].first).to have_key('action')
      expect(enhanced['assignment_abilities'].first).to have_key('action')
      expect(enhanced['position_assignments'].first).to have_key('action')
    end

    context 'position_assignments enhancement' do
      let!(:position_major_level) { create(:position_major_level) }
      let!(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.0') }
      let!(:position_type) do
        create(:position_type, external_title: 'Growth & Development Manager', organization: organization, position_major_level: position_major_level)
      end
      let!(:seat) { create(:seat, position_type: position_type, seat_needed_by: Date.current + 3.months) }

      it 'includes position, position_type, and seat information' do
        parser.parse
        enhanced = parser.enhanced_preview_actions
        pa = enhanced['position_assignments'].first
        
        expect(pa).to have_key('position_type_title')
        expect(pa).to have_key('position_display_name')
        expect(pa).to have_key('will_create_position')
        expect(pa).to have_key('seats_count')
        expect(pa).to have_key('seats')
        expect(pa).to have_key('will_update_seat_department')
      end

      it 'shows will_update_seat_department when department_names are present' do
        parser.parse
        enhanced = parser.enhanced_preview_actions
        pa = enhanced['position_assignments'].first
        
        expect(pa['will_update_seat_department']).to be true
        expect(pa['seats_count']).to eq(1)
      end

      it 'shows will_update_seat_department as false when department_names are not present' do
        csv_without_dept = <<~CSV
          Assignment,Position(s),Team(s),Tagline,Outcomes,Abilities,Required Activities
          Test Assignment,Growth & Development Manager,,Tagline,Outcome,Ability,Activity
        CSV
        parser_no_dept = described_class.new(csv_without_dept, organization)
        parser_no_dept.parse
        enhanced = parser_no_dept.enhanced_preview_actions
        pa = enhanced['position_assignments'].first
        
        expect(pa['will_update_seat_department']).to be false
      end

      it 'handles missing organization gracefully' do
        parser_no_org = described_class.new(valid_csv_content, nil)
        parser_no_org.parse
        enhanced = parser_no_org.enhanced_preview_actions
        pa = enhanced['position_assignments'].first
        
        expect(pa).to have_key('position_title')
        expect(pa).to have_key('will_update_seat_department')
        expect(pa['position_type_title']).to be_nil
        expect(pa['seats_count']).to eq(0)
      end
    end
  end
end

