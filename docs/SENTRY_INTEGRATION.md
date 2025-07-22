# Sentry Error Tracking Integration

This document describes the Sentry error tracking integration implemented in the Our Gruuv application.

## Overview

Sentry is configured to capture and track errors across the application, providing detailed context about errors, user information, and request data to help with debugging and monitoring.

## Configuration

### Environment Variables

- `SENTRY_DSN`: The Sentry project DSN (required for production/staging)
- `RAILWAY_GIT_COMMIT_SHA`: Used for release tracking (automatically set by Railway)

### Initializer

The Sentry configuration is in `config/initializers/sentry.rb` and includes:

- Environment-specific activation (only production/staging)
- Release tracking
- Breadcrumb logging
- User context injection
- Request context injection
- Performance monitoring
- Exception filtering

## Error Tracking Implementation

### Controllers

All controllers inherit error tracking capabilities from `ApplicationController`:

- **Global Error Handler**: Captures unhandled exceptions with context
- **Helper Method**: `capture_error_in_sentry(error, context)` for manual error tracking
- **User Context**: Automatically includes current user information
- **Request Context**: Includes controller, action, and filtered parameters

### Models

- **Validation Tracking**: Automatically tracks model validation failures
- **Context**: Includes model class, ID, errors, and attributes

### Jobs

- **Job Error Tracking**: Captures errors in background jobs
- **Context**: Includes job class, ID, and arguments

### Specific Error Handling

#### ApplicationController
- Session management errors
- Person creation/validation errors
- Authorization errors (via Pundit)

#### HuddlesController
- Huddle creation errors
- Join process errors
- Feedback submission errors
- Organization creation errors

#### PeopleController
- Profile update errors
- Validation errors

#### HealthcheckController
- Database connection errors

## Error Context

Each error captured includes:

### User Context
- User ID
- Email
- Display name

### Request Context
- Controller name
- Action name
- Filtered parameters (excludes sensitive data)
- URL
- HTTP method
- User agent
- IP address

### Custom Context
- Method name
- Related record IDs
- Validation errors
- Component information

## Testing

### Test Task
Run `rails sentry:test` to generate test events in Sentry.

### Test Suite
The integration includes comprehensive tests in `spec/services/sentry_integration_spec.rb` that verify:

- Error capture with context
- Model validation tracking
- Job error handling
- Global error handling

## Error Filtering

The following exceptions are excluded from Sentry tracking:

- `ActionController::RoutingError`
- `ActionController::UnknownFormat`
- `ActionController::BadRequest`
- `ActionController::ParameterMissing`

## Performance Monitoring

- **Traces**: 10% sampling rate for performance traces
- **Errors**: 100% sampling rate for error events
- **Breadcrumbs**: Automatic logging of user actions and HTTP requests

## Development vs Production

- **Development**: Errors are logged but not sent to Sentry
- **Production/Staging**: Errors are sent to Sentry with full context
- **Test**: Sentry is mocked to avoid sending test events

## Best Practices

1. **Use Context**: Always provide relevant context when capturing errors
2. **Filter Sensitive Data**: Parameters are automatically filtered
3. **User Context**: User information is automatically included when available
4. **Specific Errors**: Use specific error types rather than generic exceptions
5. **Validation Errors**: Model validation errors are automatically tracked

## Monitoring

Monitor the following in Sentry:

- Error frequency and trends
- User impact (affected users)
- Performance issues
- Validation failures
- Authorization errors

## Troubleshooting

### Common Issues

1. **No Events in Sentry**: Check `SENTRY_DSN` environment variable
2. **Missing Context**: Ensure user is logged in for user context
3. **Test Failures**: Sentry is mocked in tests, check test configuration
4. **Performance Impact**: Adjust sampling rates if needed

### Debugging

- Check Rails logs for Sentry initialization messages
- Verify environment variables are set correctly
- Test with `rails sentry:test` task
- Review Sentry dashboard for configuration issues 