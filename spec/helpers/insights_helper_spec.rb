require 'rails_helper'

RSpec.describe InsightsHelper, type: :helper do
  describe '#seats_by_state_chart_data' do
    it 'returns formatted data for seats by state chart' do
      helper.instance_variable_set(:@seats_by_state, {
        'draft' => 2,
        'open' => 5,
        'filled' => 10,
        'archived' => 1
      })
      
      data = helper.seats_by_state_chart_data
      
      expect(data.length).to eq(4)
      
      draft_entry = data.find { |d| d[:name] == 'Draft' }
      expect(draft_entry[:y]).to eq(2)
      expect(draft_entry[:color]).to eq('#6c757d')
      
      open_entry = data.find { |d| d[:name] == 'Open' }
      expect(open_entry[:y]).to eq(5)
      expect(open_entry[:color]).to eq('#ffc107')
      
      filled_entry = data.find { |d| d[:name] == 'Filled' }
      expect(filled_entry[:y]).to eq(10)
      expect(filled_entry[:color]).to eq('#28a745')
      
      archived_entry = data.find { |d| d[:name] == 'Archived' }
      expect(archived_entry[:y]).to eq(1)
      expect(archived_entry[:color]).to eq('#dc3545')
    end

    it 'handles empty data' do
      helper.instance_variable_set(:@seats_by_state, {})
      
      data = helper.seats_by_state_chart_data
      
      expect(data).to eq([])
    end
  end

  describe '#department_categories' do
    it 'returns unique sorted department names' do
      helper.instance_variable_set(:@open_seats_by_department, { 'Engineering' => 3, 'Product' => 2 })
      helper.instance_variable_set(:@filled_seats_by_department, { 'Engineering' => 5, 'Design' => 1 })
      
      categories = helper.department_categories
      
      expect(categories).to eq(['Design', 'Engineering', 'Product'])
    end

    it 'returns No Data when empty' do
      helper.instance_variable_set(:@open_seats_by_department, {})
      helper.instance_variable_set(:@filled_seats_by_department, {})
      
      categories = helper.department_categories
      
      expect(categories).to eq(['No Data'])
    end
  end

  describe '#open_seats_data' do
    it 'returns data array matching categories order' do
      helper.instance_variable_set(:@open_seats_by_department, { 'Engineering' => 3, 'Design' => 0 })
      helper.instance_variable_set(:@filled_seats_by_department, { 'Engineering' => 5, 'Design' => 1 })
      
      data = helper.open_seats_data
      
      # Categories are sorted: Design, Engineering
      expect(data).to eq([0, 3])
    end
  end

  describe '#filled_seats_data' do
    it 'returns data array matching categories order' do
      helper.instance_variable_set(:@open_seats_by_department, { 'Engineering' => 3, 'Design' => 0 })
      helper.instance_variable_set(:@filled_seats_by_department, { 'Engineering' => 5, 'Design' => 1 })
      
      data = helper.filled_seats_data
      
      # Categories are sorted: Design, Engineering
      expect(data).to eq([1, 5])
    end
  end

  describe '#titles_by_department_chart_data' do
    it 'returns formatted data for titles by department' do
      helper.instance_variable_set(:@titles_by_department, { 'Engineering' => 5, 'Product' => 3 })
      helper.instance_variable_set(:@titles_no_department, 2)
      
      data = helper.titles_by_department_chart_data
      
      expect(data.length).to eq(3)
      expect(data).to include({ name: 'Engineering', y: 5 })
      expect(data).to include({ name: 'Product', y: 3 })
      expect(data).to include({ name: 'No Department', y: 2 })
    end

    it 'excludes No Department when count is 0' do
      helper.instance_variable_set(:@titles_by_department, { 'Engineering' => 5 })
      helper.instance_variable_set(:@titles_no_department, 0)
      
      data = helper.titles_by_department_chart_data
      
      expect(data.length).to eq(1)
      expect(data.any? { |d| d[:name] == 'No Department' }).to be false
    end

    it 'handles empty data' do
      helper.instance_variable_set(:@titles_by_department, {})
      helper.instance_variable_set(:@titles_no_department, 0)
      
      data = helper.titles_by_department_chart_data
      
      expect(data).to eq([{ name: 'No Data', y: 0 }])
    end
  end

  describe '#titles_by_position_count_categories' do
    it 'returns formatted category labels' do
      helper.instance_variable_set(:@titles_by_position_count, { 0 => 2, 1 => 5, 3 => 1 })
      
      categories = helper.titles_by_position_count_categories
      
      expect(categories).to eq(['0 positions', '1 position', '3 positions'])
    end

    it 'handles empty data' do
      helper.instance_variable_set(:@titles_by_position_count, {})
      
      categories = helper.titles_by_position_count_categories
      
      expect(categories).to eq(['0 positions'])
    end
  end

  describe '#titles_by_position_count_data' do
    it 'returns values array' do
      helper.instance_variable_set(:@titles_by_position_count, { 0 => 2, 1 => 5, 3 => 1 })
      
      data = helper.titles_by_position_count_data
      
      expect(data).to eq([2, 5, 1])
    end

    it 'handles empty data' do
      helper.instance_variable_set(:@titles_by_position_count, {})
      
      data = helper.titles_by_position_count_data
      
      expect(data).to eq([0])
    end
  end

  describe '#positions_by_assignment_count_categories' do
    it 'returns formatted category labels' do
      helper.instance_variable_set(:@positions_by_required_assignment_count, { 0 => 3, 1 => 2, 5 => 1 })
      
      categories = helper.positions_by_assignment_count_categories
      
      expect(categories).to eq(['0 assignments', '1 assignment', '5 assignments'])
    end

    it 'handles empty data' do
      helper.instance_variable_set(:@positions_by_required_assignment_count, {})
      
      categories = helper.positions_by_assignment_count_categories
      
      expect(categories).to eq(['0 assignments'])
    end
  end

  describe '#positions_by_assignment_count_data' do
    it 'returns values array' do
      helper.instance_variable_set(:@positions_by_required_assignment_count, { 0 => 3, 1 => 2, 5 => 1 })
      
      data = helper.positions_by_assignment_count_data
      
      expect(data).to eq([3, 2, 1])
    end

    it 'handles empty data' do
      helper.instance_variable_set(:@positions_by_required_assignment_count, {})
      
      data = helper.positions_by_assignment_count_data
      
      expect(data).to eq([0])
    end
  end
end
