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
    it 'returns enhanced preview with action indicators' do
      parser.parse
      enhanced = parser.enhanced_preview_actions
      
      expect(enhanced['assignments'].first).to have_key('action')
      expect(enhanced['abilities'].first).to have_key('action')
      expect(enhanced['assignment_abilities'].first).to have_key('action')
      expect(enhanced['position_assignments'].first).to have_key('action')
    end
  end
end

