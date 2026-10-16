# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Milestone awards cosign", type: :request do
  let(:organization) { create(:organization) }
  let(:recipient) { create(:teammate, :assigned_employee, organization: organization) }
  let(:awarder) { create(:teammate, :assigned_employee, :employment_manager, organization: organization) }
  let(:cosigner) { create(:teammate, :assigned_employee, organization: organization) }
  let(:other_invitee) { create(:teammate, :assigned_employee, organization: organization) }
  let(:ability) { create(:ability, company: organization) }

  before do
    create(:employment_tenure, teammate: recipient, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: awarder, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: cosigner, company: organization, started_at: 1.year.ago, ended_at: nil)
    create(:employment_tenure, teammate: other_invitee, company: organization, started_at: 1.year.ago, ended_at: nil)
    sign_in_as_teammate_for_request(awarder.person, organization)
  end

  def create_pending_award(invitee_ids: [cosigner.id])
    MilestoneAwards::CreateService.call(
      teammate: recipient,
      ability: ability,
      official_level: 1,
      certifying_teammate: awarder,
      created_by_person: awarder.person,
      organization: organization,
      source: :normal,
      awarder_typed_name: awarder.person.all_names_display_name,
      skip_cosign: false,
      cosign_invitee_ids: invitee_ids,
      privacy_level: "company"
    ).value
  end

  def nested_award_path(award)
    organization_teammate_ability_milestone_award_path(
      organization, award.teammate, award.ability, award
    )
  end

  it "shows a pending award under teammate + ability with switchers and breadcrumb" do
    award = create_pending_award
    get nested_award_path(award)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Awaiting co-sign")
    expect(response.body).to include(ability.display_name)
    expect(response.body).to include("hereby certify that")
    expect(response.body).to include("And they have done so")
    expect(response.body).to include("Consciously")
    expect(response.body).to include("Competently")
    expect(response.body).to include("Awarder signature")
    expect(response.body).to include(award.awarder_typed_name)
    expect(response.body).to include("Co-signer signature")
    expect(response.body).to include("Your signature here")
    expect(response.body).to include("is defined as...")
    expect(response.body).to include("markdown-content--bordered")
    expect(response.body).to include("Evidence (visible to you)")
    expect(response.body).to include("OGOs")
    expect(response.body).to include("Active assignments that require this ability")
    expect(response.body).to include("View all matching OGOs")
    expect(response.body).to include("Switch teammate for ability milestones")
    expect(response.body).to include(organization_teammate_ability_path(organization, recipient, ability))
  end

  it "disables co-sign for the awarder and lists expected co-signers in the warning" do
    award = create_pending_award
    get nested_award_path(award)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Co-sign this award")
    expect(response.body).to include("Yes, I will co-sign")
    expect(response.body).to include("disabled")
    expect(response.body).to include("bi-exclamation-triangle")
    expect(response.body).to include("co-sign an award you created")
    expect(response.body).to include("Expected co-signers")
    expect(response.body).to include(cosigner.person.display_name)
    expect(response.body).to include("Send the following to")
    expect(response.body).to include(cosigner.person.casual_name)
    expect(response.body).to include("named you as a potential co-signer")
    expect(response.body).to include(nested_award_path(award))
    expect(response.body).to include("Copy message")
    expect(response.body).not_to include(
      cosign_organization_teammate_ability_milestone_award_path(
        organization, award.teammate, award.ability, award
      )
    )
  end

  it "redirects the legacy flat award URL to the nested path" do
    award = create_pending_award
    get organization_milestone_award_path(organization, award)
    expect(response).to redirect_to(nested_award_path(award))
  end

  it "lets an invitee cosign" do
    award = create_pending_award
    sign_in_as_teammate_for_request(cosigner.person, organization)

    get nested_award_path(award)
    expect(response.body).to include("I,")
    expect(response.body).to include(cosigner.person.all_names_display_name)
    expect(response.body).to include("agree with")
    expect(response.body).to include(awarder.person.all_names_display_name)
    expect(response.body).to include("(M1)")
    expect(response.body).not_to include("Co-sign responses")

    post cosign_organization_teammate_ability_milestone_award_path(
      organization, award.teammate, award.ability, award
    ), params: {
      typed_name: cosigner.person.all_names_display_name,
      reason: "Yes — strong evidence"
    }

    expect(response).to redirect_to(organization_teammate_milestone_path(organization, award.reload.primary_teammate_milestone))
    expect(award.reload.cosigned?).to eq(true)
  end

  it "shows co-sign responses to the awarder after a yes, including leftover conversion" do
    award = create_pending_award(invitee_ids: [cosigner.id, other_invitee.id])
    MilestoneAwards::CosignService.call(
      milestone_award: award,
      cosigning_teammate: cosigner,
      typed_name: cosigner.person.all_names_display_name,
      reason: "Yes — strong evidence"
    )

    get nested_award_path(award.reload)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Co-sign responses")
    expect(response.body).to include(cosigner.person.display_name)
    expect(response.body).to include("Co-signed")
    expect(response.body).to include("Yes — strong evidence")
    expect(response.body).to include(other_invitee.person.display_name)
    expect(response.body).to include("Converted to feedback")
  end

  it "shows declined co-sign responses to the awarder" do
    award = create_pending_award
    MilestoneAwards::DeclineCosignService.call(
      milestone_award: award,
      invitee_teammate: cosigner,
      reason: "Not enough recent evidence"
    )

    get nested_award_path(award.reload)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Co-sign this award")
    expect(response.body).to include("Co-sign responses")
    expect(response.body).to include(cosigner.person.display_name)
    expect(response.body).to include("Declined")
    expect(response.body).to include("Not enough recent evidence")
    expect(response.body).to include("You need another co-signer")
    expect(response.body).to include("Choose other co-signers")
    expect(response.body).to include("#request-a-cosigner")
    expect(response.body).to include("Request a co-signer")
    expect(response.body).to include("All invited co-signers declined")
  end

  it "lets the awarder invite another co-signer after everyone declines" do
    award = create_pending_award
    MilestoneAwards::DeclineCosignService.call(
      milestone_award: award,
      invitee_teammate: cosigner,
      reason: "Not enough recent evidence"
    )

    post request_cosign_organization_teammate_ability_milestone_award_path(
      organization, award.teammate, award.ability, award
    ), params: { cosign_invitee_ids: [other_invitee.id] }

    expect(response).to redirect_to(nested_award_path(award))
    follow_redirect!
    expect(response.body).to include("Co-sign requested")
    expect(award.reload.cosign_invites.open.pluck(:invitee_teammate_id)).to include(other_invitee.id)
    expect(response.body).not_to include("You need another co-signer")
  end

  it "hides co-sign responses from invitees who are not the awarder or employment managers" do
    award = create_pending_award
    MilestoneAwards::DeclineCosignService.call(
      milestone_award: award,
      invitee_teammate: cosigner,
      reason: "Not enough recent evidence"
    )

    sign_in_as_teammate_for_request(cosigner.person, organization)
    get nested_award_path(award.reload)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Co-sign responses")
    expect(response.body).not_to include("Not enough recent evidence")
  end

  it "shows the milestone integrity inbox for manage employment" do
    get organization_milestone_integrity_inbox_path(organization)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Milestone integrity")
    expect(response.body).to include("Skipped without co-sign")
  end

  it "removes teammate milestones when a moderator requires co-sign after skip" do
    award = MilestoneAwards::CreateService.call(
      teammate: recipient,
      ability: ability,
      official_level: 1,
      certifying_teammate: awarder,
      created_by_person: awarder.person,
      organization: organization,
      source: :normal,
      awarder_typed_name: awarder.person.all_names_display_name,
      skip_cosign: true,
      privacy_level: "company"
    ).value

    expect(recipient.teammate_milestones.where(ability: ability)).to be_present
    moment_ids = award.teammate_milestones.filter_map { |tm| tm.observable_moment&.id }

    post require_cosign_organization_teammate_ability_milestone_award_path(
      organization, award.teammate, award.ability, award
    )

    expect(response).to redirect_to(organization_milestone_integrity_inbox_path(organization))
    expect(award.reload.requires_cosign_after_moderation?).to eq(true)
    expect(recipient.teammate_milestones.where(ability: ability)).to be_empty
    expect(ObservableMoment.where(id: moment_ids)).to be_empty

    get organization_teammate_ability_path(organization, recipient, ability)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No milestones attained for this ability yet.")
  end
end
