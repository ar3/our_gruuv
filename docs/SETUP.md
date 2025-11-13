# Complete Machine Setup Instructions for OurGruuv

This guide will walk you through setting up a brand new macOS machine to run the OurGruuv Rails application. Follow these steps in order.

## Prerequisites

- A macOS machine (this guide assumes macOS 12+)
- An internet connection
- Administrator access to install software
- A GitHub account (for cloning the repository)
- A Railway account (for deployment - optional for local development)

---

## Step 1: Foundation Setup (macOS Development Tools)

### 1.1 Install Xcode Command Line Tools

Xcode Command Line Tools are required for compiling Ruby gems and other software. They include essential development tools like `git`, `gcc`, and `make`.

**Installation:**

```bash
xcode-select --install
```

A popup window will appear asking you to install the tools. Click "Install" and wait for the installation to complete (this may take 10-20 minutes).

**Verify installation:**

```bash
xcode-select -p
```

Expected output:
```
/Library/Developer/CommandLineTools
```

If you see an error or different path, the installation may not have completed. Try running the install command again.

### 1.2 Install Homebrew

Homebrew is a package manager for macOS that makes installing development tools much easier.

**Installation:**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Follow the on-screen prompts. You may be asked for your administrator password.

**After installation, add Homebrew to your PATH:**

If you're using Apple Silicon (M1/M2/M3 Mac), run:
```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

If you're using Intel Mac, run:
```bash
echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/usr/local/bin/brew shellenv)"
```

**Verify installation:**

```bash
brew --version
```

Expected output should show a version number like:
```
Homebrew 4.x.x
```

**Update Homebrew:**

```bash
brew update
```

---

## Step 2: Git Setup

### 2.1 Install Git

While macOS comes with Git, it's better to install the latest version via Homebrew:

```bash
brew install git
```

**Verify installation:**

```bash
git --version
```

Expected output:
```
git version 2.x.x
```

### 2.2 Configure Git

Set your name and email (use the same email associated with your GitHub account):

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

**Verify configuration:**

```bash
git config --global --list
```

You should see your name and email listed.

### 2.3 Set Up SSH Keys for GitHub (Optional but Recommended)

SSH keys allow you to authenticate with GitHub without entering your password each time.

**Check if you already have SSH keys:**

```bash
ls -al ~/.ssh
```

If you see files named `id_rsa` and `id_rsa.pub` (or `id_ed25519` and `id_ed25519.pub`), you already have SSH keys. Skip to step 2.3.3.

**Generate a new SSH key:**

```bash
ssh-keygen -t ed25519 -C "your.email@example.com"
```

Press Enter to accept the default file location. You can optionally set a passphrase for extra security.

**Add your SSH key to the ssh-agent:**

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

**Copy your public key:**

```bash
cat ~/.ssh/id_ed25519.pub
```

Copy the entire output (it starts with `ssh-ed25519`).

**Add the key to GitHub:**

1. Go to GitHub.com and sign in
2. Click your profile picture → Settings
3. Click "SSH and GPG keys" in the left sidebar
4. Click "New SSH key"
5. Give it a title (e.g., "My MacBook")
6. Paste your public key into the "Key" field
7. Click "Add SSH key"

**Test the connection:**

```bash
ssh -T git@github.com
```

Expected output:
```
Hi username! You've successfully authenticated, but GitHub does not provide shell access.
```

---

## Step 3: Ruby Environment Setup

### 3.1 Install rbenv

rbenv is a Ruby version manager that allows you to install and switch between different Ruby versions.

**Install rbenv:**

```bash
brew install rbenv ruby-build
```

**Initialize rbenv in your shell:**

Add this to your `~/.zshrc` file:

```bash
echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
```

**Reload your shell configuration:**

```bash
source ~/.zshrc
```

**Verify installation:**

```bash
rbenv --version
```

Expected output:
```
rbenv 1.x.x
```

### 3.2 Install Ruby 3.4.4

**Install Ruby:**

```bash
rbenv install 3.4.4
```

This will take several minutes as it compiles Ruby from source.

**Set Ruby 3.4.4 as the global version:**

```bash
rbenv global 3.4.4
```

**Verify Ruby installation:**

```bash
ruby --version
```

Expected output:
```
ruby 3.4.4 (2024-xx-xx revision xxxxxx) [arm64-darwin23]
```

The exact date and revision may vary, but the version should be `3.4.4`.

**Important:** If you see a different Ruby version, make sure you've run `source ~/.zshrc` and that rbenv is properly initialized. You can verify with:

```bash
which ruby
```

This should show a path like `/Users/yourname/.rbenv/shims/ruby`, not `/usr/bin/ruby`.

### 3.3 Install Bundler

Bundler manages Ruby gem dependencies for the project.

**Install Bundler:**

```bash
gem install bundler
```

**Verify installation:**

```bash
bundle --version
```

Expected output:
```
Bundler version 2.x.x
```

**Note:** Make sure you have Bundler 2.6.9 or higher. If you need to update:

```bash
gem update bundler
```

---

## Step 4: PostgreSQL Setup

### 4.1 Install PostgreSQL

OurGruuv uses PostgreSQL 17 as its database.

**Install PostgreSQL:**

```bash
brew install postgresql@17
```

### 4.2 Start PostgreSQL Service

**Start PostgreSQL:**

```bash
brew services start postgresql@17
```

**Verify PostgreSQL is running:**

```bash
brew services list | grep postgresql
```

You should see `postgresql@17` with status `started`.

**Alternative verification:**

```bash
psql -l
```

This should show a list of databases. If you get an error, PostgreSQL may not be running.

### 4.3 Verify PostgreSQL Connection

**Test connection:**

```bash
psql postgres -c "SELECT version();"
```

You should see PostgreSQL version information.

**Troubleshooting:**

If you encounter connection errors, see the [Troubleshooting](#troubleshooting) section below or refer to `docs/TROUBLESHOOTING.md`.

---

## Step 5: Node.js and JavaScript Tools

### 5.1 Install Node.js

OurGruuv requires Node.js 24.2.0. We'll use Homebrew to install it.

**Install Node.js:**

```bash
brew install node@24
```

**Add Node.js to your PATH:**

```bash
echo 'export PATH="/opt/homebrew/opt/node@24/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

(For Intel Macs, use `/usr/local/opt/node@24/bin` instead)

**Verify installation:**

```bash
node --version
```

Expected output:
```
v24.2.0
```

If you see a different version, you may need to specify the exact version or use nvm (Node Version Manager) instead.

**Alternative: Using nvm (Node Version Manager)**

If you prefer using nvm for Node.js version management:

```bash
brew install nvm
mkdir ~/.nvm
echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.zshrc
echo '[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"' >> ~/.zshrc
source ~/.zshrc
nvm install 24.2.0
nvm use 24.2.0
nvm alias default 24.2.0
```

### 5.2 Install Yarn

Yarn is a package manager for JavaScript dependencies.

**Install Yarn:**

```bash
npm install -g yarn@1.22.22
```

**Verify installation:**

```bash
yarn --version
```

Expected output:
```
1.22.22
```

---

## Step 6: Railway CLI Setup (Optional for Local Development)

Railway CLI is used for deploying the application to production. You can skip this if you're only doing local development.

### 6.1 Install Railway CLI

**Install Railway CLI:**

```bash
brew install railway
```

**Verify installation:**

```bash
railway --version
```

### 6.2 Authenticate with Railway

**Login to Railway:**

```bash
railway login
```

This will open a browser window for authentication. Follow the prompts to log in with your Railway account.

**Verify authentication:**

```bash
railway whoami
```

This should display your Railway username.

**Note:** To link your project to Railway later, you'll need to run `railway link` in your project directory. See the Railway documentation for more details.

---

## Step 7: Project Setup

### 7.1 Clone the Repository

**Navigate to where you want to store the project:**

```bash
cd ~/Projects  # or wherever you keep your projects
```

**Clone the repository:**

If using SSH (recommended):
```bash
git clone git@github.com:yourusername/our_gruuv.git
```

If using HTTPS:
```bash
git clone https://github.com/yourusername/our_gruuv.git
```

**Navigate into the project directory:**

```bash
cd our_gruuv
```

### 7.2 Install Ruby Dependencies

**Install gems:**

```bash
bundle install
```

This will install all Ruby dependencies listed in the `Gemfile`. This may take several minutes.

**Verify installation:**

```bash
bundle check
```

This should output: `The Gemfile's dependencies are satisfied`

### 7.3 Install JavaScript Dependencies

**Install Node.js packages:**

```bash
yarn install
```

This will install all JavaScript dependencies listed in `package.json`.

**Verify installation:**

```bash
yarn check --verify-tree
```

### 7.4 Set Up Rails Master Key (If Needed)

The Rails master key is used to decrypt encrypted credentials. If you don't have access to `config/master.key`, you'll need to get it from a team member or generate new credentials.

**Check if master.key exists:**

```bash
ls config/master.key
```

If the file exists, you're good to go. If not, you may need to:
1. Get the master key from a team member (they should share it securely)
2. Create `config/master.key` with the key value
3. Or generate new credentials (this will require updating production secrets)

**Note:** Never commit `config/master.key` to git - it's in `.gitignore` for security reasons.

### 7.5 Create Environment Variables File

Create a `.env` file in the project root for local development environment variables.

**Create the file:**

```bash
touch .env
```

**Add basic environment variables:**

Open `.env` in your text editor and add:

```bash
# Rails Host (for URL generation)
RAILS_HOST=localhost:3000

# Rails Action Mailer Protocol
RAILS_ACTION_MAILER_DEFAULT_URL_PROTOCOL=http

# Optional: Thread pool size (defaults to 3)
RAILS_MAX_THREADS=3

# Optional: Port (defaults to 3000)
PORT=3000
```

### 7.6 Configure Google OAuth (Optional)

If you need Google OAuth authentication:

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select an existing one
3. Enable the Google+ API
4. Create OAuth 2.0 credentials:
   - Application type: Web application
   - Authorized redirect URIs: `http://localhost:3000/auth/google_oauth2/callback`
5. Copy your Client ID and Client Secret

**Add to `.env`:**

```bash
GOOGLE_CLIENT_ID=your_google_client_id_here
GOOGLE_CLIENT_SECRET=your_google_client_secret_here
```

You can also use the setup script:

```bash
script/setup_google_oauth.sh
```

### 7.7 Configure Slack Integration (Optional)

If you need Slack integration:

1. Go to [Slack API Apps](https://api.slack.com/apps)
2. Create a new app
3. Configure OAuth scopes and redirect URL
4. Install the app to your workspace
5. Copy the Bot Token, Client ID, and Client Secret

**Add to `.env`:**

```bash
SLACK_BOT_TOKEN=xoxb-your-bot-token-here
SLACK_CLIENT_ID=your_slack_client_id_here
SLACK_CLIENT_SECRET=your_slack_client_secret_here
SLACK_REDIRECT_URI=http://localhost:3000/slack/oauth/callback
SLACK_DEFAULT_CHANNEL=#general
SLACK_BOT_USERNAME=OG
SLACK_BOT_EMOJI=:sparkles:
```

For detailed Slack setup instructions, see `docs/SLACK_INTEGRATION.md`.

---

## Step 8: Database Setup

### 8.1 Run the Setup Script

The easiest way to set up the database is to use the provided setup script:

```bash
bin/setup
```

This script will:
- Install dependencies (if needed)
- Prepare the database (create, migrate, seed)
- Clear old logs and temp files
- Optionally start the development server

**Note:** If you want to skip starting the server, run:

```bash
bin/setup --skip-server
```

### 8.2 Manual Database Setup (Alternative)

If you prefer to set up the database manually:

**Create the database:**

```bash
rails db:create
```

**Run migrations:**

```bash
rails db:migrate
```

**Seed the database:**

```bash
rails db:seed
```

### 8.3 Optional: Run Seeding Scenarios

For development, you can seed the database with realistic test data:

```bash
# Basic scenario (3 organizations, mixed participation)
bundle exec rake "seed:scenario[basic]"

# Full participation scenario
bundle exec rake "seed:scenario[full]"

# Low participation scenario
bundle exec rake "seed:scenario[low]"

# Clean slate (delete all data)
bundle exec rake "seed:scenario[clean]"
```

For more information, see `docs/SEEDING.md`.

---

## Step 9: Verification and Testing

### 9.1 Start the Development Server

**Start the server:**

```bash
bin/dev
```

This starts both the Rails server and the CSS watcher. You should see output indicating both processes are running.

**Verify the application loads:**

Open your browser and navigate to:
```
http://localhost:3000
```

You should see the OurGruuv application homepage.

**Stop the server:**

Press `Ctrl+C` in the terminal to stop the server.

### 9.2 Verify Database Connection

**Test database connection:**

```bash
rails db:version
```

This should show the current database schema version.

**Check database status:**

```bash
rails db:migrate:status
```

This shows which migrations have been applied.

### 9.3 Run the Test Suite

**Run unit and integration specs:**

```bash
./bin/unit-specs
```

This runs all non-system specs (models, controllers, services, etc.). This should complete in a few minutes.

**Run system specs:**

```bash
./bin/system-specs
```

This runs end-to-end browser tests. Make sure Chrome/Chromium is installed for Selenium.

**Run ENM specs:**

```bash
./bin/enm-specs
```

This runs specs for the Ethical Non-Monogamy assessment module.

**Run all specs:**

```bash
bundle exec rspec spec/
```

**Note:** See `README.md` for more information about the test suite organization.

---

## Step 10: Optional Tools

### 10.1 Install ngrok (for External Access)

ngrok is useful for testing Slack OAuth and other integrations that require external URLs.

**Install ngrok:**

```bash
brew install ngrok
```

**Verify installation:**

```bash
ngrok version
```

**Usage:**

Start your Rails server (`bin/dev`), then in another terminal:

```bash
ngrok http 3000 --domain=crappie-saved-absolutely.ngrok-free.app
```

Or use the setup script:

```bash
script/setup_slack_oauth_testing.sh
```

For more information, see `docs/SLACK_INTEGRATION.md`.

### 10.2 Additional Development Tools (Optional)

You may find these tools helpful:

**PostgreSQL GUI (pgAdmin or Postico):**
```bash
brew install --cask postico
```

**Code Editor:**
- VS Code: `brew install --cask visual-studio-code`
- RubyMine: Download from JetBrains website

**Git GUI:**
```bash
brew install --cask github
```

---

## Troubleshooting

### Common Issues

#### PostgreSQL Connection Errors

**Symptoms:**
```
ActiveRecord::ConnectionNotEstablished
connection to server on socket "/tmp/.s.PGSQL.5432" failed
```

**Solutions:**

1. **Restart PostgreSQL:**
   ```bash
   brew services restart postgresql@17
   ```

2. **Check if PostgreSQL is running:**
   ```bash
   brew services list | grep postgresql
   ```

3. **Clean up stale processes:**
   ```bash
   brew services stop postgresql@17
   pg_ctl stop -D /usr/local/var/postgresql@17
   rm -f /usr/local/var/postgresql@17/postmaster.pid
   brew services start postgresql@17
   ```

4. **Verify connection:**
   ```bash
   psql -l
   ```

For more PostgreSQL troubleshooting, see `docs/postgres_troubleshooting.md`.

#### Ruby Version Issues

**Symptoms:**
```
You must use Bundler 2 or greater
Could not find 'bundler' (2.6.9) required by your Gemfile.lock
```

**Solutions:**

1. **Verify rbenv is initialized:**
   ```bash
   eval "$(rbenv init - zsh)"
   ```

2. **Check Ruby version:**
   ```bash
   ruby --version
   ```
   Should show `ruby 3.4.4`

3. **Verify which Ruby is being used:**
   ```bash
   which ruby
   ```
   Should show a path with `.rbenv` in it

4. **Reinstall Ruby if needed:**
   ```bash
   rbenv install 3.4.4
   rbenv global 3.4.4
   ```

5. **Update Bundler:**
   ```bash
   gem update bundler
   ```

#### Node.js Version Issues

**Symptoms:**
```
Error: Node version mismatch
```

**Solutions:**

1. **Verify Node.js version:**
   ```bash
   node --version
   ```
   Should show `v24.2.0` or compatible

2. **If using nvm, switch versions:**
   ```bash
   nvm use 24.2.0
   ```

3. **Reinstall Node.js if needed:**
   ```bash
   brew uninstall node@24
   brew install node@24
   ```

#### Missing Dependencies

If you encounter errors about missing system libraries:

1. **Install common build dependencies:**
   ```bash
   brew install libvips postgresql-client
   ```

2. **For image processing (if needed):**
   ```bash
   brew install imagemagick
   ```

### Getting Help

- Check `docs/TROUBLESHOOTING.md` for more detailed troubleshooting
- Review `README.md` for project overview and documentation links
- Check Rails logs: `log/development.log`
- Check PostgreSQL logs: `brew services info postgresql@17`

### Quick Recovery Commands

If everything seems broken, try this reset sequence:

```bash
# 1. Fix Ruby environment
eval "$(rbenv init - zsh)"
ruby --version

# 2. Restart PostgreSQL
brew services restart postgresql@17

# 3. Test database connection
rails db:version

# 4. Reinstall dependencies
bundle install
yarn install

# 5. Reset database (WARNING: deletes all data)
rails db:drop db:create db:migrate db:seed

# 6. Run full setup
bin/setup --skip-server
```

---

## Next Steps

Once your machine is set up:

1. **Read the documentation:**
   - `README.md` - Project overview
   - `docs/RULES/overview.md` - Development rules and patterns
   - `docs/STYLES/overview.md` - Styling patterns

2. **Explore the codebase:**
   - Review the architecture in `README.md`
   - Check out the vision documents in `docs/vision/`

3. **Start developing:**
   - Create a feature branch
   - Make your changes
   - Run the test suite before committing
   - Follow the project's commit message conventions

4. **Deploy to production:**
   - Push to `main` branch
   - Run `railway up` to deploy

---

## Summary Checklist

Use this checklist to verify your setup:

- [ ] Xcode Command Line Tools installed
- [ ] Homebrew installed and working
- [ ] Git installed and configured
- [ ] SSH keys set up for GitHub
- [ ] rbenv installed and configured
- [ ] Ruby 3.4.4 installed
- [ ] Bundler installed (2.6.9+)
- [ ] PostgreSQL@17 installed and running
- [ ] Node.js 24.2.0 installed
- [ ] Yarn 1.22.22 installed
- [ ] Railway CLI installed (optional)
- [ ] Repository cloned
- [ ] Ruby dependencies installed (`bundle install`)
- [ ] JavaScript dependencies installed (`yarn install`)
- [ ] `.env` file created with environment variables
- [ ] Database created and migrated
- [ ] Development server starts successfully (`bin/dev`)
- [ ] Application loads in browser (http://localhost:3000)
- [ ] Test suite runs successfully

---

**Congratulations!** Your development environment is now set up. Happy coding! 🚀

