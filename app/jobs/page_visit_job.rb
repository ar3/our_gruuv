class PageVisitJob < ApplicationJob
  queue_as :default

  def perform(person_id, url, page_title, user_agent)
    Rails.logger.info "🔍 PageVisitJob: perform method called - person_id: #{person_id}, url: #{url}"
    person = Person.find(person_id)
    
    # Find or initialize PageVisit by person_id + url
    page_visit = PageVisit.find_or_initialize_by(person: person, url: url)
    
    # For new records, set visit_count to 1; for existing, increment it
    if page_visit.new_record?
      page_visit.visit_count = 1
    else
      page_visit.visit_count += 1
    end
    
    # Always update visited_at, page_title, and user_agent
    page_visit.visited_at = Time.current
    page_visit.page_title = page_title
    page_visit.user_agent = user_agent
    page_visit.save!
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "PageVisitJob: Person with ID #{person_id} not found: #{e.message}"
  rescue => e
    Rails.logger.error "PageVisitJob: Unexpected error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    raise e
  end
end

