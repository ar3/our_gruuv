# PostgreSQL Troubleshooting Checklist

## Quick Diagnosis Commands

### 1. Check PostgreSQL Service Status
```bash
brew services list | grep postgresql
```

### 2. Check if PostgreSQL Processes are Running
```bash
ps aux | grep postgres
```

### 3. Check for Stale PID File
```bash
ls -la /usr/local/var/postgresql@17/postmaster.pid
```

## Common Fixes

### Fix 1: Remove Stale PID File (Most Common)
If you see a `postmaster.pid` file but no PostgreSQL processes are running:
```bash
rm /usr/local/var/postgresql@17/postmaster.pid
brew services start postgresql@17
```

### Fix 2: Restart PostgreSQL Service
```bash
brew services restart postgresql@17
```

### Fix 3: Stop and Start Fresh
```bash
brew services stop postgresql@17
brew services start postgresql@17
```

## Verification Commands

### Test Direct Database Connection
```bash
psql -d postgres -c "SELECT version();"
```

### Test Rails Database Connection
```bash
rails db:version
```

## Advanced Troubleshooting

### Check PostgreSQL Logs
```bash
tail -f /usr/local/var/log/postgresql@17.log
```

### Check System Logs for PostgreSQL Errors
```bash
log show --predicate 'process == "postgres"' --last 1h | tail -20
```

### Check Data Directory Permissions
```bash
ls -la /usr/local/var/postgresql@17/
```

## Emergency Recovery

If PostgreSQL data directory is corrupted or missing:
```bash
# Stop PostgreSQL
brew services stop postgresql@17

# Reinitialize database (WARNING: This will delete all data!)
rm -rf /usr/local/var/postgresql@17
initdb /usr/local/var/postgresql@17

# Start PostgreSQL
brew services start postgresql@17

# Recreate your Rails database
rails db:create
rails db:migrate
rails db:seed
```

## Quick One-Liner for Most Cases
```bash
rm -f /usr/local/var/postgresql@17/postmaster.pid && brew services start postgresql@17
```

---
*Save this file for future reference!*
