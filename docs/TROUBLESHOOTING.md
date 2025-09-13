# Troubleshooting Guide

## PostgreSQL Connection Issues

### Symptoms
```
ActiveRecord::ConnectionNotEstablished
connection to server on socket "/tmp/.s.PGSQL.5432" failed: No such file or directory
Is the server running locally and accepting connections on that socket?
```

### Diagnosis Steps
1. Check if PostgreSQL is installed: `which psql`
2. Check service status: `brew services list | grep postgres`
3. Check if server is actually running: `pg_ctl status -D /usr/local/var/postgresql@17`

### Solutions (in order)

#### 1. Restart PostgreSQL Service
```bash
brew services restart postgresql@17
```

#### 2. If restart fails, clean up stale processes
```bash
# Stop the service
brew services stop postgresql@17

# Kill any remaining processes
pg_ctl stop -D /usr/local/var/postgresql@17

# Remove stale lock file
rm -f /usr/local/var/postgresql@17/postmaster.pid

# Start fresh
brew services start postgresql@17
```

#### 3. Verify connection
```bash
psql -l
# Should show your databases: our_gruuv_development, our_gruuv_test
```

## Ruby Environment Issues

### Symptoms
```
You must use Bundler 2 or greater with this lockfile.
Could not find 'bundler' (2.6.9) required by your Gemfile.lock
```

### Diagnosis
1. Check current Ruby: `ruby --version`
2. Check rbenv: `which rbenv`
3. Check local Ruby version: `rbenv local`

### Solution
```bash
# Initialize rbenv in current session
eval "$(rbenv init -)"

# Verify correct Ruby version
ruby --version
# Should show: ruby 3.4.4

# Test Rails connection
bin/rails db:version
```

## Gemfile Platform Issues

### Symptoms
```
`windows` is not a valid platform
```

### Solution
Replace `windows` platform references with:
```ruby
# Instead of:
platforms: %i[ windows jruby ]

# Use:
platforms: %i[ mswin mingw x64_mingw jruby ]
```

## Quick Recovery Commands

For a complete environment reset:
```bash
# 1. Fix Ruby environment
eval "$(rbenv init -)"

# 2. Restart PostgreSQL
brew services restart postgresql@17

# 3. Test database connection
bin/rails db:version

# 4. If still failing, run full setup
bin/setup
```

## Prevention

- Always run `eval "$(rbenv init -)"` in new terminal sessions
- Add rbenv initialization to your shell profile:
  ```bash
  echo 'eval "$(rbenv init -)"' >> ~/.zshrc
  ```
- Keep PostgreSQL service running: `brew services start postgresql@17`
