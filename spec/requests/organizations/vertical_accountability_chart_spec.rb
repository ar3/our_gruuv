require 'rails_helper'

RSpec.describe 'Organizations::VerticalAccountabilityChart', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:person_teammate) { create(:teammate, person: person, organization: organization) }

  describe 'GET /organizations/:id/vertical_accountability_chart' do
    context 'when user is authorized' do
      before do
        sign_in_as_teammate_for_request(person, organization)
      end

      context 'with no employees' do
        it 'returns http success' do
          get vertical_accountability_chart_organization_path(organization)
          expect(response).to have_http_status(:success)
        end

        it 'displays empty state message' do
          get vertical_accountability_chart_organization_path(organization)
          expect(response.body).to include('No Employees Found')
          expect(response.body).to include('No active employees found')
        end

        it 'assigns empty hierarchy tree' do
          get vertical_accountability_chart_organization_path(organization)
          expect(assigns(:hierarchy_tree)).to eq([])
        end
      end

      context 'with a single employee (no manager)' do
        let!(:employment_tenure) do
          create(:employment_tenure, teammate: person_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        end

        before do
          person_teammate.update!(first_employed_at: 1.year.ago)
        end

        it 'returns http success' do
          get vertical_accountability_chart_organization_path(organization)
          expect(response).to have_http_status(:success)
        end

        it 'assigns hierarchy tree with root employee' do
          get vertical_accountability_chart_organization_path(organization)
          tree = assigns(:hierarchy_tree)
          expect(tree).to be_an(Array)
          expect(tree.length).to eq(1)
          expect(tree.first[:person]).to eq(person)
          expect(tree.first[:children]).to eq([])
        end

        it 'displays employee name and position' do
          get vertical_accountability_chart_organization_path(organization)
          expect(response.body).to include(person.display_name)
          expect(response.body).to include(employment_tenure.position.display_name)
        end
      end

      context 'with manager-employee hierarchy' do
        let(:manager) { create(:person) }
        let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
        let(:employee) { create(:person) }
        let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }

        before do
          # Create manager employment
          create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 2.years.ago, ended_at: nil)
          manager_teammate.update!(first_employed_at: 2.years.ago)

          # Create employee employment with manager
          create(:employment_tenure, 
                 teammate: employee_teammate, 
                 company: organization, 
                 manager: manager,
                 started_at: 1.year.ago, 
                 ended_at: nil)
          employee_teammate.update!(first_employed_at: 1.year.ago)
        end

        it 'returns http success' do
          get vertical_accountability_chart_organization_path(organization)
          expect(response).to have_http_status(:success)
        end

        it 'assigns hierarchy tree with manager as root and employee as child' do
          get vertical_accountability_chart_organization_path(organization)
          tree = assigns(:hierarchy_tree)
          expect(tree).to be_an(Array)
          expect(tree.length).to eq(1)
          
          root = tree.first
          expect(root[:person]).to eq(manager)
          expect(root[:children]).to be_an(Array)
          expect(root[:children].length).to eq(1)
          expect(root[:children].first[:person]).to eq(employee)
          expect(root[:children].first[:children]).to eq([])
        end

        it 'displays both manager and employee' do
          get vertical_accountability_chart_organization_path(organization)
          expect(response.body).to include(manager.display_name)
          expect(response.body).to include(employee.display_name)
        end
      end

      context 'with multi-level hierarchy' do
        let(:ceo) { create(:person) }
        let(:ceo_teammate) { create(:teammate, person: ceo, organization: organization) }
        let(:vp) { create(:person) }
        let(:vp_teammate) { create(:teammate, person: vp, organization: organization) }
        let(:director) { create(:person) }
        let(:director_teammate) { create(:teammate, person: director, organization: organization) }
        let(:manager) { create(:person) }
        let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
        let(:employee) { create(:person) }
        let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }

        before do
          # CEO (root)
          create(:employment_tenure, teammate: ceo_teammate, company: organization, started_at: 3.years.ago, ended_at: nil)
          ceo_teammate.update!(first_employed_at: 3.years.ago)

          # VP reports to CEO
          create(:employment_tenure, 
                 teammate: vp_teammate, 
                 company: organization, 
                 manager: ceo,
                 started_at: 2.years.ago, 
                 ended_at: nil)
          vp_teammate.update!(first_employed_at: 2.years.ago)

          # Director reports to VP
          create(:employment_tenure, 
                 teammate: director_teammate, 
                 company: organization, 
                 manager: vp,
                 started_at: 1.5.years.ago, 
                 ended_at: nil)
          director_teammate.update!(first_employed_at: 1.5.years.ago)

          # Manager reports to Director
          create(:employment_tenure, 
                 teammate: manager_teammate, 
                 company: organization, 
                 manager: director,
                 started_at: 1.year.ago, 
                 ended_at: nil)
          manager_teammate.update!(first_employed_at: 1.year.ago)

          # Employee reports to Manager
          create(:employment_tenure, 
                 teammate: employee_teammate, 
                 company: organization, 
                 manager: manager,
                 started_at: 6.months.ago, 
                 ended_at: nil)
          employee_teammate.update!(first_employed_at: 6.months.ago)
        end

        it 'returns http success' do
          get vertical_accountability_chart_organization_path(organization)
          expect(response).to have_http_status(:success)
        end

        it 'builds correct multi-level hierarchy' do
          get vertical_accountability_chart_organization_path(organization)
          tree = assigns(:hierarchy_tree)
          
          expect(tree.length).to eq(1)
          root = tree.first
          expect(root[:person]).to eq(ceo)
          
          # Check VP level
          expect(root[:children].length).to eq(1)
          vp_node = root[:children].first
          expect(vp_node[:person]).to eq(vp)
          
          # Check Director level
          expect(vp_node[:children].length).to eq(1)
          director_node = vp_node[:children].first
          expect(director_node[:person]).to eq(director)
          
          # Check Manager level
          expect(director_node[:children].length).to eq(1)
          manager_node = director_node[:children].first
          expect(manager_node[:person]).to eq(manager)
          
          # Check Employee level
          expect(manager_node[:children].length).to eq(1)
          employee_node = manager_node[:children].first
          expect(employee_node[:person]).to eq(employee)
          expect(employee_node[:children]).to eq([])
        end

        it 'displays all employees in hierarchy' do
          get vertical_accountability_chart_organization_path(organization)
          expect(response.body).to include(ceo.display_name)
          expect(response.body).to include(vp.display_name)
          expect(response.body).to include(director.display_name)
          expect(response.body).to include(manager.display_name)
          expect(response.body).to include(employee.display_name)
        end
      end

      context 'with multiple root employees' do
        let(:person1) { create(:person) }
        let(:teammate1) { create(:teammate, person: person1, organization: organization) }
        let(:person2) { create(:person) }
        let(:teammate2) { create(:teammate, person: person2, organization: organization) }
        let(:person3) { create(:person) }
        let(:teammate3) { create(:teammate, person: person3, organization: organization) }

        before do
          create(:employment_tenure, teammate: teammate1, company: organization, started_at: 1.year.ago, ended_at: nil)
          teammate1.update!(first_employed_at: 1.year.ago)
          
          create(:employment_tenure, teammate: teammate2, company: organization, started_at: 1.year.ago, ended_at: nil)
          teammate2.update!(first_employed_at: 1.year.ago)
          
          create(:employment_tenure, teammate: teammate3, company: organization, started_at: 1.year.ago, ended_at: nil)
          teammate3.update!(first_employed_at: 1.year.ago)
        end

        it 'assigns all root employees' do
          get vertical_accountability_chart_organization_path(organization)
          tree = assigns(:hierarchy_tree)
          expect(tree.length).to eq(3)
          person_ids = tree.map { |node| node[:person].id }
          expect(person_ids).to contain_exactly(person1.id, person2.id, person3.id)
        end
      end

      context 'with employees having multiple direct reports' do
        let(:manager) { create(:person) }
        let(:manager_teammate) { create(:teammate, person: manager, organization: organization) }
        let(:employee1) { create(:person) }
        let(:teammate1) { create(:teammate, person: employee1, organization: organization) }
        let(:employee2) { create(:person) }
        let(:teammate2) { create(:teammate, person: employee2, organization: organization) }
        let(:employee3) { create(:person) }
        let(:teammate3) { create(:teammate, person: employee3, organization: organization) }

        before do
          create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 2.years.ago, ended_at: nil)
          manager_teammate.update!(first_employed_at: 2.years.ago)

          create(:employment_tenure, 
                 teammate: teammate1, 
                 company: organization, 
                 manager: manager,
                 started_at: 1.year.ago, 
                 ended_at: nil)
          teammate1.update!(first_employed_at: 1.year.ago)

          create(:employment_tenure, 
                 teammate: teammate2, 
                 company: organization, 
                 manager: manager,
                 started_at: 1.year.ago, 
                 ended_at: nil)
          teammate2.update!(first_employed_at: 1.year.ago)

          create(:employment_tenure, 
                 teammate: teammate3, 
                 company: organization, 
                 manager: manager,
                 started_at: 1.year.ago, 
                 ended_at: nil)
          teammate3.update!(first_employed_at: 1.year.ago)
        end

        it 'assigns all direct reports to manager' do
          get vertical_accountability_chart_organization_path(organization)
          tree = assigns(:hierarchy_tree)
          root = tree.first
          expect(root[:person]).to eq(manager)
          expect(root[:children].length).to eq(3)
          employee_ids = root[:children].map { |node| node[:person].id }
          expect(employee_ids).to contain_exactly(employee1.id, employee2.id, employee3.id)
        end
      end

      context 'with inactive employees' do
        let(:active_employee) { create(:person) }
        let(:active_teammate) { create(:teammate, person: active_employee, organization: organization) }
        let(:inactive_employee) { create(:person) }
        let(:inactive_teammate) { create(:teammate, person: inactive_employee, organization: organization) }

        before do
          create(:employment_tenure, teammate: active_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
          active_teammate.update!(first_employed_at: 1.year.ago)

          create(:employment_tenure, 
                 teammate: inactive_teammate, 
                 company: organization, 
                 started_at: 2.years.ago, 
                 ended_at: 1.year.ago)
          inactive_teammate.update!(first_employed_at: 2.years.ago, last_terminated_at: 1.year.ago)
        end

        it 'only includes active employees' do
          get vertical_accountability_chart_organization_path(organization)
          tree = assigns(:hierarchy_tree)
          person_ids = tree.map { |node| node[:person].id }
          expect(person_ids).to include(active_employee.id)
          expect(person_ids).not_to include(inactive_employee.id)
        end
      end

      context 'with company and descendant organizations' do
        let(:department) { create(:organization, :department, parent: organization) }
        let(:company_employee) { create(:person) }
        let(:company_teammate) { create(:teammate, person: company_employee, organization: organization) }
        let(:dept_employee) { create(:person) }
        let(:dept_teammate) { create(:teammate, person: dept_employee, organization: department) }

        before do
          create(:employment_tenure, teammate: company_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
          company_teammate.update!(first_employed_at: 1.year.ago)

          create(:employment_tenure, teammate: dept_teammate, company: department, started_at: 1.year.ago, ended_at: nil)
          dept_teammate.update!(first_employed_at: 1.year.ago)
        end

        it 'includes employees from descendant organizations' do
          get vertical_accountability_chart_organization_path(organization)
          tree = assigns(:hierarchy_tree)
          person_ids = tree.map { |node| node[:person].id }
          expect(person_ids).to include(company_employee.id)
          expect(person_ids).to include(dept_employee.id)
        end
      end
    end

    context 'when user is not authorized' do
      let(:other_organization) { create(:organization, :company) }
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: other_organization) }

      before do
        create(:employment_tenure, teammate: other_teammate, company: other_organization, started_at: 1.year.ago, ended_at: nil)
        other_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(other_person, other_organization)
      end

      it 'redirects with authorization error' do
        get vertical_accountability_chart_organization_path(organization)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organizations_path)
        expect(flash[:alert]).to include("You don't have access to that organization")
      end
    end

    context 'when user is unauthenticated' do
      it 'redirects to login' do
        get vertical_accountability_chart_organization_path(organization)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end

