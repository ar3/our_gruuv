# AGENTS.md

## Cursor Cloud specific instructions

### Overview
OurGruuv is a Rails 8 monolith (Ruby 3.4.4, PostgreSQL, Node 24 + Yarn for CSS) for team management, huddles, and organizational development. No microservices or Redis required — Solid Queue/Cache/Cable are all database-backed.

### Prerequisites (already installed in snapshot)
- Ruby 3.4.4 at `/usr/local/ruby-3.4.4/bin`
- Node.js 24 via nvm
- Yarn 1.22.22
- PostgreSQL 16
- User gem binaries at `~/.local/share/gem/ruby/3.4.0/bin`
- All three paths are in `~/.bashrc`

### Starting PostgreSQL
PostgreSQL does not auto-start. Before running the app or tests:
```bash
sudo pg_ctlcluster 16 main start
```

### Credentials
There is no production `config/master.key` in the repo. A dev-only master key was generated during setup. If `config/master.key` is missing, regenerate with:
```bash
rm -f config/credentials.yml.enc
EDITOR="echo" bundle exec rails credentials:edit
```

### Running the app
See `README.md` and `Procfile.dev`. Standard commands:
```bash
bin/dev          # starts Puma + CSS watcher via foreman on port 3000
```

### Testing
See `README.md` for the three test groups (unit, system, ENM). Key notes:
- The README warns about spec leaks when running the full suite at once; run test groups in segments.
- Unit/model/service specs: `bundle exec rspec --exclude-pattern "spec/system/**/*_spec.rb"` (~2000+ examples, ~20 min)
- Quick verification: `bundle exec rspec spec/models/person_spec.rb` (~80 examples, ~10s)
- ENM specs: `bundle exec rspec spec/enm/`
- System specs require Chrome/Selenium (not installed in snapshot by default).

### Lint
```bash
bundle exec rubocop          # Ruby style (many pre-existing offenses)
bundle exec brakeman --no-pager  # Security analysis
```

### Authentication
The main app uses Google OAuth for login. Without `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in `.env`, you cannot log in to the main app. The ENM module at `/enm` is fully functional without authentication.

### Database seeding
```bash
bundle exec rake "seed:scenario[basic]"   # creates sample data
```
See `docs/SEEDING.md` for all scenarios.
