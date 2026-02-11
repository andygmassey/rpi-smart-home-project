# Local Development Guide

This guide helps you work on your personal instance while keeping the public repository clean.

## 🔧 Initial Setup (Do This Once)

### 1. Create Your Local .env File

The repository uses placeholders for security. Create your actual config:

```bash
cd "/Users/andy/Documents/Projects/HR012 - reTerminal SmartHome/01 - Code"

# Copy the example
cp .env.example .env

# Edit with your ACTUAL values
nano .env
```

**Set your real values in .env:**
```bash
DEVICE_IP=192.168.1.76              # Your actual reTerminal IP
TZ=Asia/Hong_Kong                    # Your timezone
INFLUXDB_ADMIN_PASS=your_actual_password
GRAFANA_ADMIN_PASS=your_actual_password
# ... etc
```

**✅ The .env file is gitignored** - your secrets won't be committed!

### 2. Optional: Create a Local Config Override

If you need to override placeholder IPs in config files without committing them:

```bash
# Create a local config that overrides placeholders
cat > docker/homepage/config/services.local.yaml << 'EOF'
# This file overrides services.yaml locally
# Add your actual IPs here
# This file is gitignored
EOF

# Add to .gitignore if needed
echo "*.local.yaml" >> .gitignore
```

## 🔄 Development Workflow

### Daily Work Pattern

```bash
# 1. Pull latest changes from GitHub
git pull origin main

# 2. Work on your code (your .env has real values)
# Make changes, test on your reTerminal

# 3. Before committing, verify no secrets
git diff

# 4. Commit your changes
git add <files>
git commit -m "feat: description of your changes"

# 5. Push to GitHub
git push origin main
```

### Key Rules

**✅ SAFE to commit:**
- Code changes (scripts, docker-compose files)
- Documentation updates
- New features
- Bug fixes
- Using placeholders (YOUR_DEVICE_IP, 192.168.1.100)

**❌ NEVER commit:**
- `.env` file (has real passwords)
- Pi-hole runtime data (`etc-pihole/cli_pw`, databases, etc.)
- Backup files
- Your actual IP addresses in documentation
- Any file with real passwords or tokens

## 🎯 Working with Two Versions

You have two "versions" of config:

### Public Version (in Git)
- Uses `YOUR_DEVICE_IP` in docs
- Uses `192.168.1.100` in configs
- Uses `$HOME` in scripts
- No secrets

### Local Version (on your machine)
- `.env` has real IP: `192.168.1.76`
- Environment variables populate real values at runtime
- Your actual passwords in `.env`

**How it works:**
```yaml
# In docker-compose.yml (committed to git)
FTLCONF_LOCAL_IPV4: ${DEVICE_IP:-192.168.1.100}

# When you run docker compose:
# - Reads DEVICE_IP=192.168.1.76 from your .env
# - Uses your actual IP
# - But git only sees the placeholder!
```

## 🌿 Branching Strategy (Optional)

If you want to keep experimental work separate:

```bash
# Create a development branch
git checkout -b dev

# Work on features
# ... make changes ...
git commit -m "feat: experimental feature"

# When ready, merge to main
git checkout main
git merge dev
git push origin main

# Or keep dev branch private
git push origin dev  # (then keep main public, dev private)
```

## 🔍 Quick Checks Before Committing

```bash
# Check what you're about to commit
git status
git diff

# Search for any secrets (your actual IP)
git diff | grep "192.168.1.76"  # Should return nothing!

# Search for your username
git diff | grep -i "massey"  # Should return nothing!

# If found, use placeholders instead
```

## 🛠️ Useful Git Aliases

Add these to `~/.gitconfig` for easier workflow:

```ini
[alias]
    # Check for secrets before committing
    check-secrets = !git diff --cached | grep -E '192\\.168\\.1\\.76|massey|password|secret'

    # Show what would be pushed
    preview-push = log origin/main..HEAD --oneline

    # Quick commit with conventional format
    feat = "!f() { git commit -m \"feat: $*\"; }; f"
    fix = "!f() { git commit -m \"fix: $*\"; }; f"
    docs = "!f() { git commit -m \"docs: $*\"; }; f"
```

Usage:
```bash
git check-secrets      # Before committing
git preview-push       # Before pushing
git feat "add new dashboard"  # Quick commit
```

## 📋 Recommended .gitignore Additions

Your `.gitignore` is already comprehensive, but you can add project-specific patterns:

```bash
# Add to .gitignore if needed
cat >> .gitignore << 'EOF'

# Local development overrides
*.local.yaml
*.local.sh
*-local.*

# Your personal notes
NOTES.md
TODO.md
PERSONAL_*.md
EOF
```

## 🔄 Syncing Your Live System

When you make changes in git and want to deploy to your reTerminal:

```bash
# On your Mac (in the repo)
git add .
git commit -m "feat: your changes"
git push origin main

# On your reTerminal (SSH)
ssh YOUR_USERNAME@192.168.1.76
cd ~/rpi-smart-home-project
git pull origin main
./deploy.sh  # Deploy changes
```

## 🆘 Troubleshooting

### "I accidentally committed my real IP!"

```bash
# If you haven't pushed yet
git reset HEAD~1  # Undo last commit (keeps changes)
# Fix the file, then recommit

# If you already pushed
# Edit the file with placeholders
git add <file>
git commit -m "fix: replace hardcoded IP with placeholder"
git push origin main
```

### "My .env is gone!"

```bash
# Recreate from example
cp .env.example .env
nano .env  # Add your actual values
```

### "Git says everything is clean but I see changes"

```bash
# Check if the file is gitignored
git check-ignore -v <filename>

# If it shows output, the file is ignored (correct!)
# Your .env file SHOULD be ignored
```

## 📚 Summary

**Your Setup:**
- ✅ Public repo on GitHub (clean, no secrets)
- ✅ Local .env with real credentials (not in git)
- ✅ Docker Compose reads .env automatically
- ✅ You can work freely without exposing secrets

**Workflow:**
1. Work locally with real values in `.env`
2. Commit code changes (not config values)
3. Push to GitHub
4. Deploy changes to reTerminal via git pull

**Protection:**
- `.gitignore` prevents committing secrets
- GitHub now has clean history
- You can develop safely

Need help? Check [CONTRIBUTING.md](CONTRIBUTING.md) or open a discussion!
