# Deployment Checklist

## Pre-Deployment Checks

Before deploying to production, run these checks:

### 1. System Specs
```bash
./bin/system-specs
```
Runs all system specs to ensure UI functionality works.

### 2. Full Pre-Deployment Check
```bash
./bin/pre-deploy-check
```
Runs:
- System specs
- Security scan (Brakeman)
- Code quality check (RuboCop)
- Migration status check

### 3. Manual Checks
- [ ] All system specs pass
- [ ] No pending migrations
- [ ] Environment variables are set correctly
- [ ] Database backups are current
- [ ] Feature flags are configured properly

## Deployment Process

### Railway Deployment
1. Push to main branch
2. Railway automatically deploys
3. Monitor deployment logs
4. Verify health check endpoint

### Manual Deployment
1. Run pre-deployment checks
2. Deploy to staging first
3. Run smoke tests on staging
4. Deploy to production
5. Monitor application logs

## Post-Deployment Verification

### Health Checks
- [ ] Application responds to health check
- [ ] Database connections work
- [ ] External services are accessible
- [ ] Background jobs are processing

### Critical Functionality
- [ ] User authentication works
- [ ] Core features are accessible
- [ ] Data integrity is maintained
- [ ] Performance is acceptable

## Rollback Plan

If deployment fails:
1. Check deployment logs
2. Identify the issue
3. Rollback to previous version
4. Investigate and fix
5. Re-deploy when ready

## Emergency Procedures

### Database Issues
1. Stop application
2. Restore from backup
3. Fix data issues
4. Restart application

### Performance Issues
1. Check resource usage
2. Scale resources if needed
3. Optimize problematic queries
4. Monitor improvements

## Monitoring

### Key Metrics
- Response time
- Error rate
- Database performance
- Background job processing
- User activity

### Alerts
- High error rate
- Slow response times
- Database connection issues
- Failed background jobs
- Resource exhaustion
