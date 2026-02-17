require 'rails_helper'

RSpec.describe 'organizations/goals/_goal_owner_select', type: :view do
  it 'renders a select with the given options and selected value' do
    options = [
      ['Teammate: Alice', 'CompanyTeammate_1'],
      ['Company: Acme', 'Company_2'],
      ['Department: Engineering', 'Department_3']
    ]
    render partial: 'organizations/goals/goal_owner_select',
           locals: {
             options: options,
             selected_value: 'Company_2',
             name: 'owner_id',
             id: 'owner-select',
             select_class: 'form-select',
             required: true
           }

    expect(rendered).to include('id="owner-select"')
    expect(rendered).to include('class="form-select"')
    expect(rendered).to include('name="owner_id"')
    expect(rendered).to match(/required/)
    options.each do |label, value|
      expect(rendered).to include(label)
      expect(rendered).to include("value=\"#{value}\"")
    end
    expect(rendered).to include('selected="selected" value="Company_2"')
  end

  it 'uses default name and class when not provided' do
    render partial: 'organizations/goals/goal_owner_select',
           locals: { options: [['Me', 'CompanyTeammate_1']], selected_value: 'CompanyTeammate_1' }

    expect(rendered).to include('name="owner_id"')
    expect(rendered).to include('class="form-select"')
  end

  it 'excludes filter options (everyone_in_company, created_by_me) when include_filter_options is false' do
    options = [
      ['All goals visible to everyone', 'everyone_in_company'],
      ['All goals created by me', 'created_by_me'],
      ['Teammate: Alice', 'CompanyTeammate_1']
    ]
    render partial: 'organizations/goals/goal_owner_select',
           locals: { options: options, selected_value: 'CompanyTeammate_1', include_filter_options: false }

    expect(rendered).not_to include('everyone_in_company')
    expect(rendered).not_to include('created_by_me')
    expect(rendered).to include('Teammate: Alice')
    expect(rendered).to include('CompanyTeammate_1')
  end

  it 'excludes filter options by default when include_filter_options is omitted' do
    options = [
      ['All goals visible to everyone', 'everyone_in_company'],
      ['Teammate: Alice', 'CompanyTeammate_1']
    ]
    render partial: 'organizations/goals/goal_owner_select',
           locals: { options: options, selected_value: 'CompanyTeammate_1' }

    expect(rendered).not_to include('everyone_in_company')
    expect(rendered).to include('Teammate: Alice')
  end

  it 'includes filter options when include_filter_options is true' do
    options = [
      ['All goals visible to everyone', 'everyone_in_company'],
      ['All goals created by me', 'created_by_me'],
      ['Teammate: Alice', 'CompanyTeammate_1']
    ]
    render partial: 'organizations/goals/goal_owner_select',
           locals: { options: options, selected_value: 'CompanyTeammate_1', include_filter_options: true }

    expect(rendered).to include('everyone_in_company')
    expect(rendered).to include('created_by_me')
    expect(rendered).to include('Teammate: Alice')
  end

  it 'renders optgroups when grouped_options is provided' do
    grouped_options = [
      ['Filter', [['All goals', 'everyone_in_company'], ['My goals', 'created_by_me']]],
      ['Teammates', [['Teammate: Alice', 'CompanyTeammate_1']]],
      ['Company', [['Company: Acme', 'Company_2']]]
    ]
    render partial: 'organizations/goals/goal_owner_select',
           locals: { grouped_options: grouped_options, selected_value: 'Company_2', name: 'owner_id' }

    expect(rendered).to include('<optgroup label="Filter">')
    expect(rendered).to include('<optgroup label="Teammates">')
    expect(rendered).to include('<optgroup label="Company">')
    expect(rendered).to include('selected="selected" value="Company_2"')
  end
end
