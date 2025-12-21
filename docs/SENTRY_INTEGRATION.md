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

- Release tracking
- Breadcrumb logging
- User context injection (safe for all contexts: controllers, jobs, rake tasks)
- Request context injection (only when available)
- Performance monitoring
- Stack trace filtering to highlight original exception locations
- 100% exception capture rate (no exceptions are filtered or swallowed)

## Error Tracking Implementation

### Controllers

All controllers inherit error tracking capabilities from `ApplicationController`:

- **Global Error Handler**: `handle_unexpected_error` captures ALL unhandled exceptions in Sentry before handling them - exceptions are NEVER swallowed
- **Helper Method**: `capture_error_in_sentry(error, context)` for manual error tracking
- **User Context**: Automatically includes current user information when available
- **Request Context**: Includes controller, action, and filtered parameters
- **Stack Trace Filtering**: Exception handlers are filtered from stack traces, so the original exception location is highlighted in Sentry

### Models

- **Validation Tracking**: Automatically tracks model validation failures
- **Context**: Includes model class, ID, errors, and attributes

### Jobs

- **Job Error Tracking**: `ApplicationJob` automatically captures all exceptions in Sentry
- **Context**: Includes job class, ID, and arguments
- **Re-raise**: Exceptions are re-raised after capture to maintain job retry behavior

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

## Exception Capture Guarantee

**All exceptions are captured in Sentry - none are filtered or swallowed.**

- `sample_rate = 1.0` ensures 100% of exceptions are captured
- No exceptions are excluded from tracking
- The global error handler (`handle_unexpected_error`) always captures exceptions before handling them
- Jobs capture exceptions and re-raise them to maintain retry behavior

## Stack Trace Filtering

Stack traces are filtered to highlight the **original exception location**, not the exception handler:

- Exception handler methods are filtered from stack traces:
  - `ApplicationController#handle_unexpected_error`
  - `ApplicationController#handle_standard_error`
  - `ApplicationController#capture_error_in_sentry`
  - `ApplicationJob` rescue handlers
- This makes it easy to find where the exception actually occurred in Sentry's UI

## Performance Monitoring

- **Traces**: 10% sampling rate for performance traces
- **Errors**: 100% sampling rate for error events
- **Breadcrumbs**: Automatic logging of user actions and HTTP requests

## Development vs Production

- **Development**: Errors are logged and sent to Sentry (if DSN is configured), but exceptions are re-raised for debugging
- **Production/Staging**: Errors are sent to Sentry with full context, and user-friendly error pages are shown
- **Test**: Sentry is mocked to avoid sending test events

## Best Practices

1. **Exceptions Are Never Swallowed**: All exceptions are captured in Sentry before being handled
2. **Use Context**: Always provide relevant context when capturing errors
3. **Filter Sensitive Data**: Parameters are automatically filtered (passwords, etc.)
4. **User Context**: User information is automatically included when available (controllers only)
5. **Safe for All Contexts**: The `before_send` hook safely handles controllers, jobs, and rake tasks
6. **Stack Traces**: Original exception locations are highlighted, not exception handlers
7. **Validation Errors**: Model validation errors are automatically tracked
8. **Error Messages**: The SentryLogger captures ERROR level log messages (not exceptions) to catch error messages that aren't exceptions

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