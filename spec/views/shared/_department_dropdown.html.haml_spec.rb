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
    # Use Department model (Organization no longer has parent/children)
    let!(:dept_a) { create(:department, company: company, name: 'a') }
    let!(:dept_b) { create(:department, company: company, name: 'b') }
    let!(:dept_c) { create(:department, company: company, name: 'c') }
    let!(:dept_d) { create(:department, company: company, name: 'd') }
    let!(:dept_c1) { create(:department, company: company, parent_department: dept_c, name: '1') }
    let!(:dept_c2) { create(:department, company: company, parent_department: dept_c, name: '2') }

    it 'sorts departments so children appear immediately after their parent' do
      form_object = double('FormObject')
      allow(form).to receive(:label).and_return('')
      allow(form).to receive(:select) do |field_name, options, opts, html_opts|
        dept_names = options.reject { |opt| opt[0] == 'Company' || opt[0] == 'No Department' || opt[0] == company.name }
                            .map { |opt| opt[0] }
        # Department display_name: root is "name", child is "parent > name"
        expected_order = ['a', 'b', 'c', 'c > 1', 'c > 2', 'd']
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
               include_root_option: false,
               exclude_ids: [],
               help_text: nil
             }
    end

    it 'sorts top-level departments alphabetically' do
      form_object = double('FormObject')
      allow(form).to receive(:label).and_return('')
      allow(form).to receive(:select) do |field_name, options, opts, html_opts|
        # Top-level departments have no " > " in display_name
        top_level_depts = options.select { |opt| opt[0] != 'Company' && opt[0] != 'No Department' && opt[0] != company.name && !opt[0].include?(' > ') }
                                 .map { |opt| opt[0] }
        expect(top_level_depts).to eq(['a', 'b', 'c', 'd'])
      end
      
      render partial: 'shared/department_dropdown',
             locals: {
               form: form,
               organization: company,
               field_name: :department_id,
               label_text: 'Department',
               selected_department_id: nil,
               include_blank: false,
               include_root_option: false,
               exclude_ids: [],
               help_text: nil
             }
    end

    it 'places child departments immediately after their parent' do
      form_object = double('FormObject')
      allow(form).to receive(:label).and_return('')
      allow(form).to receive(:select) do |field_name, options, opts, html_opts|
        dept_names = options.reject { |opt| opt[0] == 'Company' || opt[0] == 'No Department' || opt[0] == company.name }
                            .map { |opt| opt[0] }
        c_index = dept_names.index('c')
        expect(c_index).not_to be_nil
        expect(dept_names[c_index + 1]).to eq('c > 1')
        expect(dept_names[c_index + 2]).to eq('c > 2')
        # 'd' should come after all children of 'c'
        d_index = dept_names.index('d')
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
               include_root_option: false,
               exclude_ids: [],
               help_text: nil
             }
    end
  end
end

