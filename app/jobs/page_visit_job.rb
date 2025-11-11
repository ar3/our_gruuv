class PageVisitJob < ApplicationJob
  queue_as :default

  def perform(person_id, url, page_title, user_agent)
    Rails.logger.info "🔍 PageVisitJob: perform method called - person_id: #{person_id}, url: #{url}"
    person = Person.find(person_id)
    
    # Find or initialize PageVisit by person_id + url
    page_visit = PageVisit.find_or_initialize_by(person: person, url: url)
    
    # Update visited_at to current time (moves to top)
    page_visit.visited_at = Time.current
    page_visit.page_title = page_title
    page_visit.user_agent = user_agent
    page_visit.save!
    
    # Clean up: delete visits beyond the 30th most recent for this person
    # Get all visits after the 30th (offset 30) and delete them
    visits_to_delete = PageVisit.for_person(person)
                                 .ordered_by_visited_at
                                 .offset(30)
    visits_to_delete.delete_all
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "PageVisitJob: Person with ID #{person_id} not found: #{e.message}"
  rescue => e
    Rails.logger.error "PageVisitJob: Unexpected error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    raise e
  end
end

