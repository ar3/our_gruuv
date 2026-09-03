require "rails_helper"

RSpec.describe PositionSuggestionsHelper, type: :helper do
  let(:organization) { create(:organization) }
  let(:assignment) do
    create(
      :assignment,
      company: organization,
      title: "Client Discovery",
      tagline: "Discover **client** needs",
      required_activities: "- Interview stakeholders\n- Write brief",
      handbook: "## How we do discovery"
    )
  end

  before do
    create(:assignment_outcome, assignment: assignment, description: "Capture top priorities")
  end

  describe "#position_suggestion_relative_time" do
    it "returns relative text with absolute title for hover" do
      time = 2.days.ago
      html = helper.position_suggestion_relative_time(time, viewer: create(:person))

      expect(html).to include("ago")
      expect(html).to include("title=")
    end
  end

  describe "#position_suggestion_assignment_popover_html" do
    it "includes tagline, outcomes, required activities, and a handbook visit note" do
      html = helper.position_suggestion_assignment_popover_html(assignment)

      expect(html).to include("Description")
      expect(html).to include("<strong>client</strong>")
      expect(html).to include("Outcomes")
      expect(html).to include("Capture top priorities")
      expect(html).to include("Required activities")
      expect(html).to include("Interview stakeholders")
      expect(html).to include("handbook content")
      expect(html).to include("Visit the assignment page")
      expect(html).not_to include("## How we do discovery")
    end

    it "omits the handbook note when handbook is blank" do
      assignment.update!(handbook: nil)
      html = helper.position_suggestion_assignment_popover_html(assignment)

      expect(html).not_to include("handbook content")
    end
  end

  describe "#position_suggestion_ability_description_popover_html" do
    it "renders markdown description" do
      ability = create(:ability, company: organization, name: "Communication", description: "Listen **carefully**")
      html = helper.position_suggestion_ability_description_popover_html(ability)

      expect(html).to include("<strong>carefully</strong>")
    end
  end

  describe "#assignments_grouped_options_for_select" do
    it "groups company-wide first, then departments by name" do
      dept = create(:department, company: organization, name: "Engineering")
      company_wide = create(:assignment, company: organization, title: "Zulu Work", department: nil)
      in_dept = create(:assignment, company: organization, title: "Alpha Work", department: dept)
      other = create(:assignment, company: organization, title: "Beta Work", department: dept)

      html = helper.assignments_grouped_options_for_select([in_dept, company_wide, other])

      expect(html).to include("Company-wide")
      expect(html).to include("optgroup")
      expect(html.index("Company-wide")).to be < html.index("Alpha Work")
      expect(html.index("Alpha Work")).to be < html.index("Beta Work")
    end
  end

  describe "#position_suggestion_collapse_toggle" do
    it "renders a link-styled disclosure with chevrons" do
      html = helper.position_suggestion_collapse_toggle(
        label: "Propose changes",
        collapse_id: "assignment-1-field-form",
        expanded: false
      )

      expect(html).to include("btn-link")
      expect(html).to include("bi-chevron-down")
      expect(html).to include("bi-chevron-up")
      expect(html).to include('aria-expanded="false"')
      expect(html).to include("Propose changes")
    end

    it "places the chevron on the right when requested" do
      html = helper.position_suggestion_collapse_toggle(
        label: "Show processed",
        collapse_id: "processed-1",
        expanded: false,
        chevron_position: :right,
        subtle: true
      )

      expect(html).to include("text-muted")
      expect(html.index("Show processed")).to be < html.index("bi-chevron-down")
    end
  end

  describe "#position_suggestion_process_row_outcome" do
    let(:organization) { create(:organization) }
    let(:comment) { instance_double(Comment, resolved?: true, resolved_at: 2.hours.ago) }
    let(:row) do
      PositionSuggestions::RoundSummaryBuilder::ProcessRow.new(
        kind: :free_text,
        label: "Comment",
        anchor: "assignment-1",
        comment: comment,
        resolved: true
      )
    end

    it "shows when the suggestion was resolved" do
      html = helper.position_suggestion_process_row_outcome(organization, row)

      expect(html).to include("Resolved")
      expect(html).to include("ago")
    end

    it "shows accepted milestone outcome with linked processor" do
      processor = create(:person, first_name: "Jordan", last_name: "Lee")
      processed_by = create(:company_teammate, organization: organization, person: processor)
      milestone = instance_double(
        PositionSuggestionMilestone,
        accepted?: true,
        rejected?: false,
        processed_at: 1.hour.ago,
        processed_by: processed_by
      )
      milestone_row = PositionSuggestions::RoundSummaryBuilder::ProcessRow.new(
        kind: :milestone,
        label: "Milestone",
        anchor: "assignment-ability-1",
        comment: nil,
        milestone: milestone,
        resolved: true
      )
      html = helper.position_suggestion_process_row_outcome(organization, milestone_row)

      expect(html).to include("Accepted and applied by")
      expect(html).to include("Jordan")
      expect(html).to include(internal_organization_company_teammate_path(organization, processed_by))
      expect(html).to include("ago")
    end

    it "shows rejected milestone outcome with linked processor" do
      processor = create(:person, first_name: "Sam", last_name: "Ng")
      processed_by = create(:company_teammate, organization: organization, person: processor)
      milestone = instance_double(
        PositionSuggestionMilestone,
        accepted?: false,
        rejected?: true,
        processed_at: 30.minutes.ago,
        processed_by: processed_by
      )
      milestone_row = PositionSuggestions::RoundSummaryBuilder::ProcessRow.new(
        kind: :milestone,
        label: "Milestone",
        anchor: "assignment-ability-1",
        comment: nil,
        milestone: milestone,
        resolved: true
      )

      html = helper.position_suggestion_process_row_outcome(organization, milestone_row)

      expect(html).to include("Rejected by")
      expect(html).to include("Sam")
      expect(html).to include(internal_organization_company_teammate_path(organization, processed_by))
      expect(html).to include("ago")
    end
  end

  describe "#position_suggestion_process_row_label" do
    let(:organization) { create(:organization) }
    let(:person) { create(:person, first_name: "Alex", last_name: "Kim") }
    let(:teammate) { create(:company_teammate, organization: organization, person: person) }
    let(:assignment) { create(:assignment, company: organization, title: "Client Discovery") }
    let(:ability) { create(:ability, company: organization, name: "Communication") }

    it "links teammate, ability, and assignment on milestone rows" do
      assignment_ability = create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
      milestone = instance_double(
        PositionSuggestionMilestone,
        last_modified_by: teammate,
        milestoneable: assignment_ability,
        suggested_milestone_level: 3
      )
      row = PositionSuggestions::RoundSummaryBuilder::ProcessRow.new(
        kind: :milestone,
        label: "plain",
        anchor: "x",
        comment: nil,
        milestone: milestone,
        resolved: false
      )

      html = helper.position_suggestion_process_row_label(organization, row)

      expect(html).to include(internal_organization_company_teammate_path(organization, teammate))
      expect(html).to include(organization_ability_path(organization, ability))
      expect(html).to include(organization_assignment_path(organization, assignment))
      expect(html).to include("Milestone 3")
    end

    it "links teammate and assignment on free-text rows" do
      teammate # ensure CompanyTeammate exists before person lookup
      comment = instance_double(
        Comment,
        creator: person,
        commentable: assignment
      )
      row = PositionSuggestions::RoundSummaryBuilder::ProcessRow.new(
        kind: :free_text,
        label: "plain",
        anchor: "x",
        comment: comment,
        resolved: false
      )

      html = helper.position_suggestion_process_row_label(organization, row)

      expect(html).to include("Comment by")
      expect(html).to include(internal_organization_company_teammate_path(organization, teammate))
      expect(html).to include(organization_assignment_path(organization, assignment))
    end
  end

  describe "#position_suggestion_processed_row_classes" do
    it "uses success border for accepted milestones" do
      milestone = instance_double(PositionSuggestionMilestone, accepted?: true, rejected?: false)
      row = PositionSuggestions::RoundSummaryBuilder::ProcessRow.new(
        kind: :milestone, label: "Milestone", anchor: "x", comment: nil, milestone: milestone, resolved: true
      )

      expect(helper.position_suggestion_processed_row_classes(row)).to eq("border-success bg-light")
    end

    it "uses danger border for rejected milestones" do
      milestone = instance_double(PositionSuggestionMilestone, accepted?: false, rejected?: true)
      row = PositionSuggestions::RoundSummaryBuilder::ProcessRow.new(
        kind: :milestone, label: "Milestone", anchor: "x", comment: nil, milestone: milestone, resolved: true
      )

      expect(helper.position_suggestion_processed_row_classes(row)).to eq("border-danger bg-light")
    end
  end
end
