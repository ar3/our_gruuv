class PgSearchHealthService
  # Models that use multisearchable
  SEARCHABLE_MODELS = [Person, Organization, Observation, Assignment, Ability].freeze

  def self.check
    new.check
  end

  def self.rebuild_all
    new.rebuild_all
  end

  def check
    results = {}
    overall_healthy = true

    SEARCHABLE_MODELS.each do |model|
      model_result = check_model(model)
      results[model.name] = model_result
      overall_healthy = false unless model_result[:healthy]
    end

    {
      healthy: overall_healthy,
      models: results,
      timestamp: Time.current
    }
  end

  def rebuild_all
    results = {}

    SEARCHABLE_MODELS.each do |model|
      start_time = Time.current
      PgSearch::Multisearch.rebuild(model)
      duration = Time.current - start_time
      record_count = model.count

      results[model.name] = {
        rebuilt: true,
        record_count: record_count,
        duration_seconds: duration.round(2)
      }
    end

    {
      rebuilt: true,
      models: results,
      timestamp: Time.current
    }
  end

  private

  def check_model(model)
    # Count actual records
    actual_count = model.count

    # Count search documents for this model
    search_doc_count = PgSearch::Document.where(searchable_type: model.name).count

    # Check for orphaned documents (documents pointing to non-existent records)
    orphaned_count = PgSearch::Document
      .where(searchable_type: model.name)
      .where.not(searchable_id: model.select(:id))
      .count

    # Check for missing documents (records without search documents)
    # This is more expensive, so we'll do a sample check
    missing_sample = check_missing_documents(model, actual_count)

    healthy = (actual_count == search_doc_count) && orphaned_count == 0 && missing_sample[:count] == 0

    {
      healthy: healthy,
      actual_count: actual_count,
      search_doc_count: search_doc_count,
      difference: actual_count - search_doc_count,
      orphaned_count: orphaned_count,
      missing_sample: missing_sample
    }
  end

  def check_missing_documents(model, total_count)
    # For large datasets, sample a subset to check
    sample_size = [100, total_count].min
    return { count: 0, sample_size: 0 } if sample_size == 0

    # Get a random sample of records
    sample_ids = model.order("RANDOM()").limit(sample_size).pluck(:id)

    # Check which ones are missing from search documents
    existing_search_ids = PgSearch::Document
      .where(searchable_type: model.name, searchable_id: sample_ids)
      .pluck(:searchable_id)

    missing_ids = sample_ids - existing_search_ids
    missing_count = missing_ids.size

    # Extrapolate to estimate total missing (rough estimate)
    estimated_missing = if sample_size > 0
      (missing_count.to_f / sample_size) * total_count
    else
      0
    end

    {
      count: missing_count,
      sample_size: sample_size,
      estimated_total_missing: estimated_missing.round,
      sample_missing_ids: missing_ids.first(10) # First 10 for debugging
    }
  end
end

