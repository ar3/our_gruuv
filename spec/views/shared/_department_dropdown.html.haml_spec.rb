require 'rails_helper'

RSpec.describe 'shared/_department_dropdown', type: :view do
  let(:company) { create(:organization, :company, name: 'Company') }
  let(:form) { double('Form', label: '', select: '', object: nil) }
  
  before do
    assign(:organization, company)
    allow(view).to receive(:render).and_call_original
    allow(view).to receive(:form_with).and_return(form)
  end

  describe 'department sorting' do
    let!(:dept_a) { create(:organization, :department, name: 'a', parent: company) }
    let!(:dept_b) { create(:organization, :department, name: 'b', parent: company) }
    let!(:dept_c) { create(:organization, :department, name: 'c', parent: company) }
    let!(:dept_d) { create(:organization, :department, name: 'd', parent: company) }
    let!(:dept_c1) { create(:organization, :department, name: '1', parent: dept_c) }
    let!(:dept_c2) { create(:organization, :department, name: '2', parent: dept_c) }

    it 'sorts departments so children appear immediately after their parent' do
      # Create a mock form object
      form_object = double('FormObject')
      allow(form).to receive(:label).and_return('')
      allow(form).to receive(:select) do |field_name, options, opts, html_opts|
        # Extract department names from options (skip company and "No Department" if present)
        dept_names = options.reject { |opt| opt[0] == 'Company' || opt[0] == 'No Department' || opt[0] == company.name }
                            .map { |opt| opt[0] }
        
        # Expected order: Company > a, Company > b, Company > c, Company > c > 1, Company > c > 2, Company > d
        expected_order = ['Company > a', 'Company > b', 'Company > c', 'Company > c > 1', 'Company > c > 2', 'Company > d']
        expect(dept_names).to eq(expected_order)
      end
      
      render partial: 'shared/department_dropdown',
             locals: {
               form: form,
               organization: company,
               field_name: :department_id,
               label_text: 'Department',
               selected_department_id: nil,
               include_blank: false,
               help_text: nil
             }
    end

    it 'sorts top-level departments alphabetically' do
      form_object = double('FormObject')
      allow(form).to receive(:label).and_return('')
      allow(form).to receive(:select) do |field_name, options, opts, html_opts|
        # Get only top-level departments (those with exactly one " > " separator, meaning Company > dept_name)
        top_level_depts = options.select { |opt| opt[0] != 'Company' && opt[0] != 'No Department' && opt[0] != company.name && opt[0].count('>') == 1 }
                                 .map { |opt| opt[0] }
        
        expect(top_level_depts).to eq(['Company > a', 'Company > b', 'Company > c', 'Company > d'])
      end
      
      render partial: 'shared/department_dropdown',
             locals: {
               form: form,
               organization: company,
               field_name: :department_id,
               label_text: 'Department',
               selected_department_id: nil,
               include_blank: false,
               help_text: nil
             }
    end

    it 'places child departments immediately after their parent' do
      form_object = double('FormObject')
      allow(form).to receive(:label).and_return('')
      allow(form).to receive(:select) do |field_name, options, opts, html_opts|
        dept_names = options.reject { |opt| opt[0] == 'Company' || opt[0] == 'No Department' || opt[0] == company.name }
                            .map { |opt| opt[0] }
        
        # Find index of 'Company > c'
        c_index = dept_names.index('Company > c')
        expect(c_index).not_to be_nil
        
        # 'Company > c > 1' and 'Company > c > 2' should come immediately after 'Company > c'
        expect(dept_names[c_index + 1]).to eq('Company > c > 1')
        expect(dept_names[c_index + 2]).to eq('Company > c > 2')
        
        # 'Company > d' should come after all children of 'c'
        d_index = dept_names.index('Company > d')
        expect(d_index).to be > c_index + 2
      end
      
      render partial: 'shared/department_dropdown',
             locals: {
               form: form,
               organization: company,
               field_name: :department_id,
               label_text: 'Department',
               selected_department_id: nil,
               include_blank: false,
               help_text: nil
             }
    end
  end
end

