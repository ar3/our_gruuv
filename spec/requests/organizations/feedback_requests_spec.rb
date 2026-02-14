require 'rails_helper'

RSpec.describe 'Organizations::FeedbackRequests', type: :request do
  let(:company) { create(:organization) }
  let(:requestor_person) { create(:person) }
  let(:requestor_teammate) do
    CompanyTeammate.find_or_create_by!(person: requestor_person, organization: company) do |t|
      t.organization = company
    end
  end
  let(:subject_person) { create(:person) }
  let(:subject_teammate) do
    CompanyTeammate.find_or_create_by!(person: subject_person, organization: company) do |t|
      t.organization = company
    end
  end
  let(:responder_person) { create(:person) }
  let(:responder_teammate) do
    CompanyTeammate.find_or_create_by!(person: responder_person, organization: company) do |t|
      t.organization = company
    end
  end

  before do
    # Ensure all teammates are in the same company
    requestor_teammate.update!(organization: company) if requestor_teammate.organization != company
    subject_teammate.update!(organization: company) if subject_teammate.organization != company
    responder_teammate.update!(organization: company) if responder_teammate.organization != company
    sign_in_as_teammate_for_request(requestor_person, company)
  end

  describe 'GET /organizations/:organization_id/feedback_requests' do
    let!(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    it 'renders the index page' do
      get organization_feedback_requests_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Feedback Requests')
    end

    it 'excludes archived requests by default' do
      # Create archived request with a different subject so we can distinguish it
      archived_subject_person = create(:person)
      archived_subject_teammate = CompanyTeammate.find_or_create_by!(person: archived_subject_person, organization: company)
      archived_request = create(:feedback_request, :archived,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: archived_subject_teammate
      )

      get organization_feedback_requests_path(company)
      expect(response.body).to include(feedback_request.subject_of_feedback_teammate.person.display_name)
      expect(response.body).not_to include(archived_request.subject_of_feedback_teammate.person.display_name)
    end

    it 'includes archived requests when show_archived=1' do
      archived_request = create(:feedback_request, :archived,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Archived request'
      )

      get organization_feedback_requests_path(company, show_archived: '1')
      expect(response.body).to include(feedback_request.subject_of_feedback_teammate.person.display_name)
      expect(response.body).to include(archived_request.subject_of_feedback_teammate.person.display_name)
    end

    it 'requires authorization' do
      other_company = create(:organization)
      other_person = create(:person)
      sign_in_as_teammate_for_request(other_person, other_company)

      get organization_feedback_requests_path(company)
      expect(response).to have_http_status(:redirect)
    end

    it 'displays empty state when there are no feedback requests' do
      # Delete the feedback request created in let! to test empty state
      feedback_request.destroy
      
      get organization_feedback_requests_path(company)
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('No Feedback Requests')
      expect(response.body).to include('Create your first feedback request to gather structured feedback from teammates.')
      expect(response.body).to include('Create First Feedback Request')
      # Table should not be rendered when empty
      expect(response.body).not_to match(/<table[^>]*>/)
    end

    it 'displays empty state for archived when all requests are active and show_archived=1' do
      # Delete the active request created in let!
      feedback_request.destroy
      
      get organization_feedback_requests_path(company, show_archived: '1')
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('No Feedback Requests')
      expect(response.body).to include('There are no archived feedback requests that you created.')
    end

    context 'when a request has one question answered (one observation created)' do
      before do
        feedback_request.feedback_request_questions.destroy_all
        question = create(:feedback_request_question, feedback_request: feedback_request, question_text: 'How did it go?', position: 1)
        feedback_request.feedback_request_responders.create!(teammate: responder_teammate)
        observation = create(:observation,
          observer: responder_person,
          company: company,
          story: 'One answered question.',
          feedback_request_question: question,
          privacy_level: :observed_and_managers
        )
        observation.observees.destroy_all
        observation.observees.build(teammate: subject_teammate)
        observation.save!
      end

      it 'renders the index and shows the request with one observation in the Observations column' do
        get organization_feedback_requests_path(company)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(feedback_request.subject_of_feedback_teammate.person.display_name)
        expect(response.body).to include('Observations')
        # Table row for this request shows observation count 1 (badge)
        expect(response.body).to include('>1</span>')
      end
    end

    describe 'Requests of me toggle' do
      let(:other_requestor) { create(:company_teammate, organization: company) }
      let(:open_subject) { create(:company_teammate, organization: company) }
      let(:completed_subject) { create(:company_teammate, organization: company) }
      let(:open_request) do
        create(:feedback_request,
          company: company,
          requestor_teammate: other_requestor,
          subject_of_feedback_teammate: open_subject,
          subject_line: 'Open request'
        ).tap do |fr|
          fr.feedback_request_responders.create!(teammate: requestor_teammate)
        end
      end
      let(:completed_request) do
        create(:feedback_request,
          company: company,
          requestor_teammate: other_requestor,
          subject_of_feedback_teammate: completed_subject,
          subject_line: 'Completed request'
        ).tap do |fr|
          fr.feedback_request_responders.create!(teammate: requestor_teammate, completed_at: 1.day.ago)
        end
      end

      before do
        open_request
        completed_request
        sign_in_as_teammate_for_request(requestor_person, company)
      end

      it 'View open requests of me shows only requests where completed_at is nil' do
        get organization_feedback_requests_path(company, requests_of_me: 'open')
        expect(response).to have_http_status(:success)
        expect(response.body).to include(open_subject.person.display_name)
        expect(response.body).not_to include(completed_subject.person.display_name)
        expect(response.body).to include('View open requests of me')
        expect(response.body).to include('View all requests of me')
      end

      it 'View all requests of me shows all requests where user is responder' do
        get organization_feedback_requests_path(company, requests_of_me: 'all')
        expect(response).to have_http_status(:success)
        expect(response.body).to include(open_subject.person.display_name)
        expect(response.body).to include(completed_subject.person.display_name)
      end
    end
  end

  describe 'GET /organizations/:organization_id/feedback_requests/new' do
    it 'renders the new page' do
      get new_organization_feedback_request_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Subject')
    end

    it 'requires authorization' do
      # Create a request with subject as the current user (should be allowed)
      get new_organization_feedback_request_path(company)
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST /organizations/:organization_id/feedback_requests' do
    let(:assignment) { create(:assignment, company: company) }
    # Make requestor the subject so authorization passes (subject can create requests about themselves)
    # Ensure both teammates are in the same company
    before do
      requestor_teammate.update!(organization: company)
      subject_teammate.update!(organization: company)
      responder_teammate.update!(organization: company)
    end
    
    let(:valid_params) do
      {
        feedback_request: {
          subject_of_feedback_teammate_id: requestor_teammate.id,
          subject_line: 'Test feedback request'
        }
      }
    end

    it 'creates a new feedback request' do
      expect {
        post organization_feedback_requests_path(company), params: valid_params
      }.to change { FeedbackRequest.count }.by(1)
      
      expect(response).to have_http_status(:redirect)
      feedback_request = FeedbackRequest.last
      expect(feedback_request.state).to eq('invalid') # State is now computed
      expect(feedback_request.subject_line).to eq('Test feedback request')
    end

    it 'redirects to select_focus after creation' do
      post organization_feedback_requests_path(company), params: valid_params
      feedback_request = FeedbackRequest.last
      expect(response).to redirect_to(select_focus_organization_feedback_request_path(company, feedback_request))
    end

  end

  describe 'GET /organizations/:organization_id/feedback_requests/:id' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    it 'renders the show page' do
      get organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:success)
      expect(response.body).to match(/Feedback Request|Subject/)
    end

    it 'requires authorization' do
      other_company = create(:organization)
      other_person = create(:person)
      sign_in_as_teammate_for_request(other_person, other_company)

      get organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:redirect)
    end

    it 'allows subject to view show page' do
      sign_in_as_teammate_for_request(subject_person, company)
      get organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:success)
      expect(response.body).to match(/Feedback Request|Subject/)
    end

    it 'denies responder from viewing show page (responders only see answer page)' do
      feedback_request.feedback_request_responders.create!(teammate: responder_teammate)
      sign_in_as_teammate_for_request(responder_person, company)
      get organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'GET /organizations/:organization_id/feedback_requests/:id/select_focus' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    it 'renders the select focus page' do
      get select_focus_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Select Focus')
    end

    it 'renders the wizard header' do
      get select_focus_organization_feedback_request_path(company, feedback_request)
      expect(response.body).to include('Step 1: Who & Why'.gsub('&', '&amp;'))
      expect(response.body).to include('Step 2: Select Focus')
      expect(response.body).to include('Step 4: Select Respondents')
    end
  end

  describe 'PATCH /organizations/:organization_id/feedback_requests/:id/update_focus' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end
    let(:assignment) { create(:assignment, company: company) }

    before do
      feedback_request.feedback_request_questions.destroy_all
    end

    it 'creates placeholder questions with blank question_text and redirects to feedback_prompt' do
      patch update_focus_organization_feedback_request_path(company, feedback_request), params: {
        assignment_ids: [assignment.id]
      }

      expect(response).to redirect_to(feedback_prompt_organization_feedback_request_path(company, feedback_request))
      feedback_request.reload
      expect(feedback_request.feedback_request_questions.count).to eq(1)
      expect(feedback_request.feedback_request_questions.first.question_text).to eq('')
      expect(feedback_request.feedback_request_questions.first.rateable).to eq(assignment)
    end

    it 'redirects back to select_focus with alert when no focus items selected' do
      patch update_focus_organization_feedback_request_path(company, feedback_request), params: {
        assignment_ids: [],
        ability_ids: [],
        aspiration_ids: []
      }

      expect(response).to redirect_to(select_focus_organization_feedback_request_path(company, feedback_request))
      expect(flash[:alert]).to eq('Please select at least one focus item.')
      feedback_request.reload
      expect(feedback_request.feedback_request_questions.count).to eq(0)
    end
  end

  describe 'GET /organizations/:organization_id/feedback_requests/:id/edit' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    it 'renders the edit page or redirects to wizard step' do
      get edit_organization_feedback_request_path(company, feedback_request)
      # Edit page may redirect to wizard steps if incomplete, or render if complete
      expect(response.status).to be_between(200, 399).inclusive
    end

    it 'renders the wizard header with steps' do
      get edit_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Step 1: Who & Why'.gsub('&', '&amp;'))
      expect(response.body).to include('Step 2: Select Focus')
      expect(response.body).to include('Step 3: Edit Questions')
      expect(response.body).to include('Step 4: Select Respondents')
    end

    it 'requires authorization' do
      # Sign in as someone else (not the requestor)
      other_person = create(:person)
      other_teammate = create(:company_teammate, person: other_person, organization: company)
      sign_in_as_teammate_for_request(other_person, company)

      get edit_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:redirect)
    end
  end

  describe 'PATCH /organizations/:organization_id/feedback_requests/:id' do
    let(:feedback_request) do
      create(:feedback_request, :ready,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    before do
      # Clear any existing questions first
      feedback_request.feedback_request_questions.destroy_all
      # Create questions and responders so request is ready
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question?', position: 1)
      feedback_request.feedback_request_responders.create!(teammate: responder_teammate)
    end

    it 'updates the feedback request subject and subject_line' do
      new_subject = create(:company_teammate, organization: company)
      patch organization_feedback_request_path(company, feedback_request), params: {
        feedback_request: {
          subject_of_feedback_teammate_id: new_subject.id,
          subject_line: 'Updated subject line'
        }
      }
      feedback_request.reload
      expect(feedback_request.subject_of_feedback_teammate).to eq(new_subject)
      expect(feedback_request.subject_line).to eq('Updated subject line')
    end

    it 'redirects to show page on success' do
      patch organization_feedback_request_path(company, feedback_request), params: {
        feedback_request: {
          subject_of_feedback_teammate_id: subject_teammate.id,
          subject_line: 'Test feedback request'
        }
      }
      expect(response).to redirect_to(organization_feedback_request_path(company, feedback_request))
    end
  end

  describe 'DELETE /organizations/:organization_id/feedback_requests/:id' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    it 'archives the feedback request (soft delete and state change)' do
      delete organization_feedback_request_path(company, feedback_request)
      feedback_request.reload
      expect(feedback_request.deleted_at).to be_present
      expect(feedback_request.state).to eq('archived')
      expect(feedback_request.archived?).to be true
    end

    it 'redirects to index on success' do
      delete organization_feedback_request_path(company, feedback_request)
      expect(response).to redirect_to(organization_feedback_requests_path(company))
    end
  end

  describe 'GET /organizations/:organization_id/feedback_requests/:id/answer' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    before do
      # Clear any existing questions first
      feedback_request.feedback_request_questions.destroy_all
      # Add questions and responders
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question?', position: 1)
      feedback_request.feedback_request_responders.create!(teammate: requestor_teammate)
      sign_in_as_teammate_for_request(requestor_person, company)
    end

    it 'renders the answer page' do
      get answer_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:success)
      expect(response.body).to match(/Answer|Question/)
    end

    it 'requires authorization (must be a responder)' do
      other_person = create(:person)
      other_teammate = create(:company_teammate, person: other_person, organization: company)
      sign_in_as_teammate_for_request(other_person, company)

      get answer_organization_feedback_request_path(company, feedback_request)
      expect(response).to have_http_status(:redirect)
    end

    context 'with assignment, aspiration, and ability questions' do
      let(:assignment) { create(:assignment, company: company) }
      let(:ability) { create(:ability, company: company) }
      let(:aspiration) { create(:aspiration, company: company) }

      before do
        FeedbackRequestQuestion.where(feedback_request: feedback_request).destroy_all
        create(:feedback_request_question, feedback_request: feedback_request, question_text: 'How did they do on this assignment?', position: 1, rateable: assignment)
        create(:feedback_request_question, feedback_request: feedback_request, question_text: 'How did they demonstrate this value?', position: 2, rateable: aspiration)
        create(:feedback_request_question, feedback_request: feedback_request, question_text: 'How did they demonstrate this ability?', position: 3, rateable: ability)
        feedback_request.reload
      end

      it 'renders one section per object with 4-column left (object link, divider, question) and 8-column right (rating)' do
        get answer_organization_feedback_request_path(company, feedback_request)
        expect(response).to have_http_status(:success)

        # Object names linked to show pages in new window
        expect(response.body).to include(assignment.title)
        expect(response.body).to include(ability.name)
        expect(response.body).to include(aspiration.name)
        expect(response.body).to include('target="_blank"')
        expect(response.body).to include(organization_assignment_path(company, assignment))
        expect(response.body).to include(organization_ability_path(company, ability))
        expect(response.body).to include(organization_aspiration_path(company, aspiration))

        # Question text in each section
        expect(response.body).to include('How did they do on this assignment?')
        expect(response.body).to include('How did they demonstrate this value?')
        expect(response.body).to include('How did they demonstrate this ability?')

        # Rating UI (from rating_button_group partial)
        expect(response.body).to include('Exceptional')
        expect(response.body).to include('Solid')
        expect(response.body).to include('N/A')

        # 4/8 column layout and vertical border
        expect(response.body).to include('col-md-4')
        expect(response.body).to include('col-md-8')
        expect(response.body).to include('border-end')
      end

      it 'shows Save and Keep Incomplete and Save and Complete buttons' do
        get answer_organization_feedback_request_path(company, feedback_request)
        expect(response.body).to include('Save and Keep Incomplete')
        expect(response.body).to include('Save and Complete')
        expect(response.body).to include('submit')
      end
    end

    context 'when the responder has a previously saved observation for a question' do
      before do
        FeedbackRequestQuestion.where(feedback_request: feedback_request).destroy_all
      end
      let!(:existing_observation) do
        assignment = create(:assignment, company: company)
        question = create(:feedback_request_question,
          feedback_request: feedback_request,
          question_text: 'How did they do?',
          position: 1,
          rateable: assignment
        )
        feedback_request.feedback_request_responders.find_or_create_by!(teammate_id: requestor_teammate.id)
        obs = create(:observation,
          observer: requestor_person,
          company: company,
          story: 'My previous saved story.',
          feedback_request_question: question,
          privacy_level: :observed_and_managers
        )
        obs.observees.destroy_all
        obs.observees.build(teammate: subject_teammate)
        obs.save!
        obs.observation_ratings.create!(rateable: assignment, rating: 'agree')
        obs
      end

      it 'defaults story and rating from the observation and shows link to the observation' do
        get answer_organization_feedback_request_path(company, feedback_request)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('My previous saved story.')
        expect(response.body).to include('the observation itself')
        expect(response.body).to include(organization_observation_path(company, existing_observation))
        expect(response.body).to include('created from your answer')
      end
    end
  end

  describe 'POST /organizations/:organization_id/feedback_requests/:id/submit_answers' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    before do
      # Clear any existing questions first
      feedback_request.feedback_request_questions.destroy_all
      # Create questions with text so request can be ready
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question 1?', position: 1)
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question 2?', position: 2)
      # Add current user as responder
      feedback_request.feedback_request_responders.create!(teammate: requestor_teammate)
      feedback_request.reload # Reload to ensure questions are loaded
      sign_in_as_teammate_for_request(requestor_person, company)
    end

    it 'creates observations from answers' do
      feedback_request.reload # Ensure questions are loaded
      question = feedback_request.feedback_request_questions.first
      expect {
        post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
          answers: {
            question.id.to_s => {
              story: 'This is my answer to the question',
              privacy_level: 'observed_and_managers'
            }
          },
          privacy_level: 'observed_and_managers'
        }
      }.to change { Observation.count }.by(1)
    end

    it 'creates one observation per answered question' do
      feedback_request.reload # Ensure questions are loaded
      questions = feedback_request.feedback_request_questions
      expect {
        post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
          answers: {
            questions[0].id.to_s => { story: 'Answer 1', privacy_level: 'observed_and_managers' },
            questions[1].id.to_s => { story: 'Answer 2', privacy_level: 'observed_and_managers' }
          },
          privacy_level: 'observed_and_managers'
        }
      }.to change { Observation.count }.by(2)
    end

    it 'redirects to show page on success' do
      feedback_request.reload # Ensure questions are loaded
      question = feedback_request.feedback_request_questions.first
      post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
        answers: {
          question.id.to_s => {
            story: 'This is my answer',
            privacy_level: 'observed_and_managers'
          }
        },
        privacy_level: 'observed_and_managers',
        save_and_complete: 'Save and Complete'
      }
      expect(response).to redirect_to(organization_feedback_request_path(company, feedback_request))
    end

    it 'sets completed_at when Save and Complete is clicked' do
      feedback_request.reload
      question = feedback_request.feedback_request_questions.first
      responder_record = feedback_request.feedback_request_responders.find_by(teammate_id: requestor_teammate.id)
      expect(responder_record.completed_at).to be_nil

      post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
        answers: {
          question.id.to_s => { story: 'Done', privacy_level: 'observed_and_managers' }
        },
        privacy_level: 'observed_and_managers',
        save_and_complete: 'Save and Complete'
      }
      expect(response).to have_http_status(:redirect)
      responder_record.reload
      expect(responder_record.completed_at).to be_within(5.seconds).of(Time.current)
    end

    it 'sets completed_at to nil when Save and Keep Incomplete is clicked' do
      feedback_request.reload
      responder_record = feedback_request.feedback_request_responders.find_by(teammate_id: requestor_teammate.id)
      responder_record.update!(completed_at: 1.day.ago)

      question = feedback_request.feedback_request_questions.first
      post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
        answers: {
          question.id.to_s => { story: 'WIP', privacy_level: 'observed_and_managers' }
        },
        privacy_level: 'observed_and_managers',
        save_and_keep_incomplete: 'Save and Keep Incomplete'
      }
      expect(response).to have_http_status(:redirect)
      responder_record.reload
      expect(responder_record.completed_at).to be_nil
    end

    it 'keeps observations as drafts when Save and Keep Incomplete is clicked' do
      feedback_request.reload
      question = feedback_request.feedback_request_questions.first
      post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
        answers: {
          question.id.to_s => {
            story: 'Draft story.',
            privacy_level: 'observed_and_managers'
          }
        },
        privacy_level: 'observed_and_managers',
        save_and_keep_incomplete: 'Save and Keep Incomplete'
      }
      expect(response).to have_http_status(:redirect)
      observation = Observation.find_by(feedback_request_question_id: question.id, observer_id: requestor_person.id)
      expect(observation).to be_present
      expect(observation).not_to be_published
    end

    it 'publishes observations when Save and Complete is clicked' do
      feedback_request.reload
      question = feedback_request.feedback_request_questions.first
      post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
        answers: {
          question.id.to_s => {
            story: 'Final story.',
            privacy_level: 'observed_and_managers'
          }
        },
        privacy_level: 'observed_and_managers',
        save_and_complete: 'Save and Complete'
      }
      expect(response).to have_http_status(:redirect)
      observation = Observation.find_by(feedback_request_question_id: question.id, observer_id: requestor_person.id)
      expect(observation).to be_present
      expect(observation).to be_published
    end

    it 'creates observation when only rating is present (no story)' do
      feedback_request.reload
      question = feedback_request.feedback_request_questions.first
      expect {
        post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
          answers: {
            question.id.to_s => {
              story: '',
              rating: 'agree',
              privacy_level: 'observed_and_managers'
            }
          },
          privacy_level: 'observed_and_managers',
          save_and_keep_incomplete: 'Save and Keep Incomplete'
        }
      }.to change { Observation.count }.by(1)
    end

    it 'does not create observation when both story and rating are blank/na' do
      feedback_request.reload
      question = feedback_request.feedback_request_questions.first
      expect {
        post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
          answers: {
            question.id.to_s => {
              story: '',
              rating: 'na',
              privacy_level: 'observed_and_managers'
            }
          },
          privacy_level: 'observed_and_managers',
          save_and_keep_incomplete: 'Save and Keep Incomplete'
        }
      }.not_to change { Observation.count }
    end

    it 'updates existing observation when saving again (does not create a second observation)' do
      feedback_request.reload
      feedback_request.feedback_request_questions.destroy_all
      assignment = create(:assignment, company: company)
      question = create(:feedback_request_question,
        feedback_request: feedback_request,
        question_text: 'How did they do?',
        position: 1,
        rateable: assignment
      )
      feedback_request.reload

      post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
        answers: {
          question.id.to_s => {
            story: 'First save.',
            rating: 'agree',
            privacy_level: 'observed_and_managers'
          }
        },
        privacy_level: 'observed_and_managers',
        save_and_keep_incomplete: 'Save and Keep Incomplete'
      }
      expect(response).to have_http_status(:redirect)
      observation = Observation.find_by(feedback_request_question_id: question.id, observer_id: requestor_person.id)
      expect(observation).to be_present
      expect(observation.story).to eq('First save.')
      expect(observation.observation_ratings.find_by(rateable: assignment).rating).to eq('agree')

      expect {
        post submit_answers_organization_feedback_request_path(company, feedback_request), params: {
          answers: {
            question.id.to_s => {
              story: 'Updated story.',
              rating: 'strongly_agree',
              privacy_level: 'observed_and_managers'
            }
          },
          privacy_level: 'observed_and_managers',
          save_and_keep_incomplete: 'Save and Keep Incomplete'
        }
      }.not_to change { Observation.count }

      observation.reload
      expect(observation.story).to eq('Updated story.')
      expect(observation.observation_ratings.find_by(rateable: assignment).rating).to eq('strongly_agree')
    end
  end

  describe 'POST /organizations/:organization_id/feedback_requests/:id/archive' do
    let(:feedback_request) do
      create(:feedback_request,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    it 'archives the feedback request' do
      post archive_organization_feedback_request_path(company, feedback_request)
      feedback_request.reload
      expect(feedback_request.deleted_at).to be_present
      expect(feedback_request.state).to eq('archived') # State is now computed
      expect(feedback_request.archived?).to be true
    end

    it 'redirects to show page' do
      post archive_organization_feedback_request_path(company, feedback_request)
      expect(response).to redirect_to(organization_feedback_request_path(company, feedback_request))
    end
  end

  describe 'POST /organizations/:organization_id/feedback_requests/:id/restore' do
    let(:feedback_request) do
      create(:feedback_request, :archived,
        company: company,
        requestor_teammate: requestor_teammate,
        subject_of_feedback_teammate: subject_teammate,
        subject_line: 'Test feedback request'
      )
    end

    before do
      # Create questions and responders so request can be restored to ready state
      create(:feedback_request_question, feedback_request: feedback_request, question_text: 'Test question?', position: 1)
      feedback_request.feedback_request_responders.create!(teammate: responder_teammate)
    end

    it 'restores the feedback request' do
      post restore_organization_feedback_request_path(company, feedback_request)
      feedback_request.reload
      expect(feedback_request.deleted_at).to be_nil
      # State should be ready after restore (if valid) or invalid
      expect(['ready', 'invalid']).to include(feedback_request.state)
    end

    it 'redirects to show page' do
      post restore_organization_feedback_request_path(company, feedback_request)
      expect(response).to redirect_to(organization_feedback_request_path(company, feedback_request))
    end
  end
end
