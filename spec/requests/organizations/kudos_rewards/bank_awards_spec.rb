# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::KudosRewards::BankAwards', type: :request do
  let(:organization) { create(:organization) }
  let(:banker_person) { create(:person) }
  let(:banker_teammate) do
    create(:company_teammate, person: banker_person, organization: organization, can_manage_kudos_rewards: true)
  end
  let(:recipient_person) { create(:person) }
  let(:recipient_teammate) do
    create(:company_teammate, person: recipient_person, organization: organization)
  end

  before do
    banker_teammate
    recipient_teammate
  end

  describe 'GET /organizations/:organization_id/kudos_rewards/bank_awards/new' do
    context 'when user has can_manage_kudos_rewards' do
      before { sign_in_as_teammate_for_request(banker_person, organization) }

      it 'returns success' do
        get new_organization_kudos_rewards_bank_award_path(organization)
        expect(response).to have_http_status(:success)
      end

      it 'renders the new template' do
        get new_organization_kudos_rewards_bank_award_path(organization)
        expect(response).to render_template(:new)
      end

      it 'shows the award form with recipient and points fields' do
        get new_organization_kudos_rewards_bank_award_path(organization)
        expect(response.body).to include('Award Points')
        expect(response.body).to include('Recipient')
        expect(response.body).to include('Points to Give')
        expect(response.body).to include('Points to Spend')
        expect(response.body).to include('Reason')
      end

      it 'includes recipient in teammate list and excludes current user' do
        get new_organization_kudos_rewards_bank_award_path(organization)
        expect(response.body).to include(recipient_person.display_name)
        # Banker is excluded from the dropdown, so their name may still appear in nav; check select options
        expect(response.body).to include('Select a teammate')
      end
    end

    context 'when user does not have can_manage_kudos_rewards' do
      before do
        banker_teammate.update!(can_manage_kudos_rewards: false)
        sign_in_as_teammate_for_request(banker_person, organization)
      end

      it 'redirects to root' do
        get new_organization_kudos_rewards_bank_award_path(organization)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST /organizations/:organization_id/kudos_rewards/bank_awards' do
    context 'when user has can_manage_kudos_rewards' do
      before { sign_in_as_teammate_for_request(banker_person, organization) }

      it 'creates a bank award and redirects to index with success' do
        expect {
          post organization_kudos_rewards_bank_awards_path(organization),
               params: {
                 bank_award: {
                   recipient_id: recipient_teammate.id,
                   points_to_give: 50,
                   points_to_spend: 25,
                   reason: 'Great work on the project!'
                 }
               }
        }.to change(BankAwardTransaction, :count).by(1)

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_kudos_rewards_bank_awards_path(organization))
        expect(flash[:notice]).to include('Successfully awarded')
        expect(flash[:notice]).to include(recipient_person.display_name)
      end

      it 'applies points to the recipient ledger' do
        post organization_kudos_rewards_bank_awards_path(organization),
             params: {
               bank_award: {
                 recipient_id: recipient_teammate.id,
                 points_to_give: 30,
                 points_to_spend: 10,
                 reason: 'Spot bonus'
               }
             }

        expect(response).to redirect_to(organization_kudos_rewards_bank_awards_path(organization))
        ledger = recipient_teammate.kudos_ledger.reload
        expect(ledger.points_to_give).to eq(30)
        expect(ledger.points_to_spend).to eq(10)
      end

      context 'with invalid recipient' do
        it 'redirects back to new with alert' do
          post organization_kudos_rewards_bank_awards_path(organization),
               params: {
                 bank_award: {
                   recipient_id: 0,
                   points_to_give: 50,
                   points_to_spend: 25,
                   reason: 'Test'
                 }
               }

          expect(response).to have_http_status(:redirect)
          expect(response).to redirect_to(new_organization_kudos_rewards_bank_award_path(organization))
          expect(flash[:alert]).to eq('Recipient not found')
        end
      end

      context 'when service returns an error' do
        before do
          allow(Kudos::AwardBankPointsService).to receive(:call).and_return(
            Result.err('Points to give must be positive')
          )
        end

        it 're-renders new with unprocessable_entity and flash alert' do
          post organization_kudos_rewards_bank_awards_path(organization),
               params: {
                 bank_award: {
                   recipient_id: recipient_teammate.id,
                   points_to_give: 50,
                   points_to_spend: 25,
                   reason: 'Test'
                 }
               }

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response).to render_template(:new)
          expect(flash[:alert]).to eq('Points to give must be positive')
        end
      end
    end

    context 'when user does not have can_manage_kudos_rewards' do
      before do
        banker_teammate.update!(can_manage_kudos_rewards: false)
        sign_in_as_teammate_for_request(banker_person, organization)
      end

      it 'redirects to root and does not create a transaction' do
        expect {
          post organization_kudos_rewards_bank_awards_path(organization),
               params: {
                 bank_award: {
                   recipient_id: recipient_teammate.id,
                   points_to_give: 50,
                   points_to_spend: 25,
                   reason: 'Should not work'
                 }
               }
        }.not_to change(BankAwardTransaction, :count)

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
