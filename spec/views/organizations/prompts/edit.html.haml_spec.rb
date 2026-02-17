require 'rails_helper'
require 'cgi'

RSpec.describe 'organizations/prompts/edit', type: :view do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, :company) }
  let(:teammate) do
    CompanyTeammate.find_or_create_by!(person: person, organization: organization)
  end
  let(:template) { create(:prompt_template, :available, company: organization) }
  let(:prompt) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }
  let(:goal1) { create(:goal, owner: teammate, creator: teammate, company: organization, goal_type: 'stepping_stone_activity') }
  let(:goal2) { create(:goal, owner: teammate, creator: teammate, company: organization, goal_type: 'quantitative_key_result') }
  let(:prompt_goal1) { PromptGoal.create!(prompt: prompt, goal: goal1) }
  let(:prompt_goal2) { PromptGoal.create!(prompt: prompt, goal: goal2) }

  before do
    assign(:organization, organization)
    assign(:prompt, prompt)
    assign(:prompt_template, template)
    assign(:prompt_questions, [])
    assign(:archived_questions, [])
    assign(:prompt_answers, {})
    assign(:archived_answers, {})
    assign(:can_edit, true)
    assign(:prompt_goals, [prompt_goal1, prompt_goal2])
    assign(:linked_goals, { goal1.id => goal1, goal2.id => goal2 })
    assign(:linked_goal_check_ins, {})
    
    # Mock policy
    allow(view).to receive(:policy) do |obj|
      if obj.is_a?(PromptGoal)
        double(destroy?: true)
      elsif obj == prompt
        double(update?: true, show?: true)
      else
        double(update?: true, show?: true, destroy?: true)
      end
    end
    
    # Mock route helpers
    allow(view).to receive(:organization_prompts_path).and_return("/organizations/#{organization.id}/prompts")
    allow(view).to receive(:edit_organization_prompt_path).and_return("/organizations/#{organization.id}/prompts/#{prompt.id}/edit")
    allow(view).to receive(:organization_prompt_path).and_return("/organizations/#{organization.id}/prompts/#{prompt.id}")
    allow(view).to receive(:choose_manage_goals_organization_prompt_path) do |org, prompt_obj, options = {}|
      base_path = "/organizations/#{org.id}/prompts/#{prompt_obj.id}/choose_manage_goals"
      if options.present?
        query_params = options.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
        "#{base_path}?#{query_params}"
      else
        base_path
      end
    end
    allow(view).to receive(:close_tab_path) do |options = {}|
      base_path = "/close_tab"
      if options.present?
        query_params = options.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
        "#{base_path}?#{query_params}"
      else
        base_path
      end
    end
    allow(view).to receive(:organization_goal_path).and_wrap_original do |method, *args|
      "/organizations/#{args[0].id}/goals/#{args[1].id}"
    end
    allow(view).to receive(:organization_prompt_prompt_goal_path).and_wrap_original do |method, *args|
      "/organizations/#{args[0].id}/prompts/#{args[1].id}/prompt_goals/#{args[2].id}"
    end
    
    # Define helper methods that are available in views
    def view.current_organization
      @current_organization
    end
    
    view.instance_variable_set(:@current_organization, organization)
    
    # Mock helper methods
    allow(view).to receive(:format_time_in_user_timezone).and_return("Jan 1, 2024 12:00 PM")
    allow(view).to receive(:goal_category_badge_class).and_return("bg-primary")
    allow(view).to receive(:goal_category_label).and_return("Category")
    allow(view).to receive(:goal_privacy_tooltip_text).and_return("Privacy tooltip")
    allow(view).to receive(:goal_privacy_rings_with_label).and_return("🔒 Private")
    allow(view).to receive(:goal_badge_class).and_return("bg-primary")
    allow(view).to receive(:goal_status_icon).and_return("bi-circle")
    allow(view).to receive(:goal_should_be_struck_through?).and_return(false)
    allow(view).to receive(:request).and_return(double(url: "/organizations/#{organization.id}/prompts/#{prompt.id}/edit"))
    
    # Mock prompt associations (use relation so .pluck, .any?, .group_by work in view)
    allow(prompt).to receive(:goals).and_return(Goal.where(id: [goal1.id, goal2.id]))
    allow(prompt).to receive(:prompt_goals).and_return([prompt_goal1, prompt_goal2])
  end

  it 'renders the edit form' do
    render
    expect(rendered).to have_content('Reflection Details')
    expect(rendered).to have_content('Answer Questions')
  end

  context 'when prompt has associated goals' do
    before do
      prompt_goal1
      prompt_goal2
      prompt.reload
    end

    it 'displays associated goals grouped by type' do
      render
      expect(rendered).to have_content('Associated Goals')
      expect(rendered).to have_content('Stepping Stones/Activities')
      expect(rendered).to have_content('Measurable Outcomes')
    end

    it 'displays goals in hierarchy' do
      render
      expect(rendered).to have_content(goal1.title)
      expect(rendered).to have_content(goal2.title)
    end
    
    it 'does not display archived goals' do
      archived_goal = create(:goal, owner: teammate, creator: teammate, company: organization, goal_type: 'stepping_stone_activity', title: 'Archived Goal', deleted_at: 1.day.ago)
      archived_prompt_goal = PromptGoal.create!(prompt: prompt, goal: archived_goal)
      
      # Reload to ensure deleted_at is set
      archived_goal.reload
      
      # Update the mocked associations to include the archived goal
      # The view filters archived goals, so we need to ensure the relation includes it
      goals_relation = Goal.where(id: [goal1.id, goal2.id, archived_goal.id])
      allow(prompt).to receive(:goals).and_return(goals_relation)
      allow(prompt).to receive(:prompt_goals).and_return([prompt_goal1, prompt_goal2, archived_prompt_goal])
      assign(:prompt_goals, [prompt_goal1, prompt_goal2, archived_prompt_goal])
      # linked_goals should include all descendant goals, but archived ones should be filtered in the view
      assign(:linked_goals, { goal1.id => goal1, goal2.id => goal2, archived_goal.id => archived_goal })
      
      render
      
      expect(rendered).to have_content(goal1.title)
      expect(rendered).to have_content(goal2.title)
      expect(rendered).not_to have_content('Archived Goal')
    end
  end

  context 'when prompt has no associated goals' do
    before do
      PromptGoal.where(prompt: prompt).destroy_all
      prompt.reload
      allow(prompt).to receive(:goals).and_return([])
      allow(prompt).to receive(:prompt_goals).and_return([])
    end

    it 'shows message about no goals' do
      render
      expect(rendered).to have_content('No goals associated with this prompt.')
    end

    it 'does not show Check-in on / Edit all goals button' do
      render
      expect(rendered).not_to have_css('button[name="save_and_edit_goals"]')
    end

    it 'shows link to associate goals when can_edit is true' do
      render
      expect(rendered).to have_link('Associate goals')
    end

    it 'opens associate goals link in new window with return_url=edit and return_text=template title' do
      render
      link = Capybara.string(rendered).find_link('Associate goals')
      expect(link[:target]).to eq('_blank')
      expect(link[:href]).to include('return_url')
      expect(link[:href]).to include('return_text')
      expect(CGI.unescape(link[:href])).to include(template.title)
    end
  end

  context 'when can_edit is true' do
    it 'shows Add New / Associate Goals as submit button (name=save_and_manage_goals) that saves and redirects to choose_manage_goals' do
      render
      button = Capybara.string(rendered).find('button[name="save_and_manage_goals"]')
      expect(button[:form]).to eq('prompt-edit-form')
      expect(button).to have_content('Add New / Associate Goals')
    end

    it 'shows Close and Start Fresh submit button with confirm message' do
      render
      button = Capybara.string(rendered).find('button[name="save_and_close_and_start_new"]')
      expect(button[:form]).to eq('prompt-edit-form')
      expect(button).to have_content('Close and Start Fresh')
      expect(button[:'data-turbo-confirm']).to include('You will not lose any data')
      expect(button[:'data-turbo-confirm']).to include('form will clear')
    end
  end

  context 'when can_edit is true and prompt has associated goals' do
    before do
      prompt_goal1
      prompt_goal2
      prompt.reload
      allow(prompt).to receive(:goals).and_return(Goal.where(id: [goal1.id, goal2.id]))
      allow(prompt).to receive(:prompt_goals).and_return([prompt_goal1, prompt_goal2])
    end

    it 'shows Check-in on / Edit all goals button with save_and_edit_goals and outline secondary style' do
      render
      button = Capybara.string(rendered).find('button[name="save_and_edit_goals"]')
      expect(button[:form]).to eq('prompt-edit-form')
      expect(button).to have_content('Check-in on / Edit all goals')
      expect(button[:class]).to include('btn-outline-secondary')
    end
  end

  context 'when can_edit is false' do
    before { assign(:can_edit, false) }

    it 'disables form fields and shows disabled buttons' do
      render
      # Submit buttons are replaced with disabled spans/buttons
      expect(rendered).to include('Save and continue editing')
      expect(rendered).to include('disabled')
      # Add New / Associate Goals button and Associate goals link are hidden when cannot edit
      expect(rendered).not_to have_css('button[name="save_and_manage_goals"]')
      expect(rendered).not_to have_link('Associate goals')
      expect(rendered).not_to have_css('button[name="save_and_close_and_start_new"]')
    end
  end

  context 'page title' do
    it 'includes the template title (casual name is in content_for :header, not in default rendered body)' do
      render
      expect(rendered).to have_content(template.title)
    end
  end
end

