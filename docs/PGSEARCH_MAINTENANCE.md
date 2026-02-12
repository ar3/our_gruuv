# PgSearch Index Maintenance

## Overview

This application uses PgSearch for full-text search across multiple models. The search indexes can get out of sync with the actual data, especially after:
- Bulk updates via SQL (bypassing ActiveRecord callbacks)
- Data imports or migrations
- Direct database operations
- Failed callbacks during record updates

## Monitoring Search Index Health

### Health Check Endpoint

The health check endpoint (`/healthcheck`) now includes search index health status. Visit the health check page to see:
- Overall search health status
- Per-model statistics (record counts vs search document counts)
- Orphaned document counts
- Missing document estimates

### Rake Tasks

#### Check Index Health

```bash
bundle exec rake pg_search:check
```

This command checks if all search indexes are in sync. It reports:
- ✅ Healthy: All indexes match their source data
- ❌ Unhealthy: Indexes are out of sync (shows differences)

**Exit codes:**
- `0` = All healthy
- `1` = Issues detected

#### Rebuild All Indexes

```bash
bundle exec rake pg_search:rebuild
```

Rebuilds search indexes for all models:
- Person
- Organization
- Observation
- Assignment
- Ability

**Note:** This can take time for large datasets. Each model is rebuilt sequentially.

#### Check and Auto-Rebuild

```bash
bundle exec rake pg_search:check_and_rebuild
```

Checks index health first. If issues are found, automatically rebuilds all indexes.

## When to Rebuild

You should rebuild indexes when:

1. **After bulk data imports** - If you import data via SQL or bulk operations
2. **After migrations that modify searchable fields** - If you change columns used in `multisearchable`
3. **When search results are incomplete** - If users report missing results
4. **After manual database operations** - If you run SQL updates directly
5. **Periodically in production** - Consider scheduling a weekly check

## Production Monitoring

### Recommended Setup

1. **Add to deployment checklist**: Check search health after deployments
2. **Schedule periodic checks**: Run `rake pg_search:check` weekly via cron or scheduled job
3. **Monitor health endpoint**: Add search health to your monitoring dashboard
4. **Set up alerts**: Alert when search health check fails

### Example Scheduled Job

You could add this to your recurring jobs configuration:

```ruby
# config/recurring.yml (if using recurring jobs)
search_health_check:
  cron: "0 2 * * 0"  # Every Sunday at 2 AM
  class: "SearchHealthCheckJob"
```

Or use a simple cron job:

```bash
# Run every Sunday at 2 AM
0 2 * * 0 cd /path/to/app && bundle exec rake pg_search:check_and_rebuild
```

## Manual Rebuild Commands

If you need to rebuild specific models manually:

```ruby
# In Rails console
PgSearch::Multisearch.rebuild(Person)
PgSearch::Multisearch.rebuild(Organization)
PgSearch::Multisearch.rebuild(Observation)
PgSearch::Multisearch.rebuild(Assignment)
PgSearch::Multisearch.rebuild(Ability)
```

## Troubleshooting

### Search Returns No Results

1. Check index health: `rake pg_search:check`
2. If unhealthy, rebuild: `rake pg_search:rebuild`
3. Test search again

### Search Returns Stale Data

1. Check for orphaned documents in health check
2. Rebuild affected model: `PgSearch::Multisearch.rebuild(ModelName)`

### Performance Issues

If rebuilding takes too long:
- Rebuild during off-peak hours
- Consider rebuilding models individually
- Check database performance during rebuild

## Models Using Search

The following models use `multisearchable`:

- **Person**: `first_name`, `last_name`, `email`
- **Organization**: `name`, `type`
- **Observation**: `story`, `primary_feeling`, `secondary_feeling`
- **Assignment**: `title`, `tagline`, `required_activities`, `handbook`
- **Ability**: `name`, `description`
- **Title**: `external_title`

## Implementation Details

- **Service**: `PgSearchHealthService` - Checks and rebuilds indexes
- **Health Check**: Integrated into `HealthcheckController`
- **Rake Tasks**: `lib/tasks/pg_search.rake`

## Related Files

- `app/services/pg_search_health_service.rb` - Health check service
- `app/controllers/healthcheck_controller.rb` - Health check endpoint
- `lib/tasks/pg_search.rake` - Maintenance rake tasks
- `app/queries/global_search_query.rb` - Search query implementation


