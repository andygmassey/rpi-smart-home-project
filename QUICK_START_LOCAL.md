# Quick Start - Your Local Setup

You now have a clean public repository! Here's how to continue working:

## ✅ What's Already Set Up

- ✅ Git remote connected to GitHub
- ✅ Pre-commit hook installed (checks for secrets)
- ✅ .env file created (YOU NEED TO EDIT IT!)
- ✅ .gitignore protecting your secrets

## 🚀 Next Steps for Local Development

### 1. Configure Your .env File (IMPORTANT!)

```bash
nano .env
```

**Change these values:**
```bash
DEVICE_IP=192.168.1.76              # Your actual reTerminal IP
INFLUXDB_ADMIN_PASS=your_real_password_here
GRAFANA_ADMIN_PASS=your_real_password_here
INFLUXDB_USER_PASS=your_real_password_here
MQTT_PASS=your_real_password_here
```

### 2. Test Your Local Setup

```bash
# Pull any changes
git pull origin main

# Your docker-compose will use values from .env automatically
cd docker/grafana-influx
docker compose up -d

# .env is NOT in git, so your secrets are safe!
git status  # Should NOT show .env
```

### 3. Make Changes and Commit

```bash
# Edit files
nano scripts/some-script.sh

# Check what changed
git status
git diff

# The pre-commit hook will check for secrets!
git add scripts/some-script.sh
git commit -m "feat: improve some script"

# Push to GitHub
git push origin main
```

## 🛡️ Protection Features

1. **Pre-commit Hook**: Automatically checks for secrets before committing
   - Blocks commits with your actual IP
   - Blocks commits with real passwords
   - Blocks Pi-hole sensitive data

2. **.gitignore**: Prevents committing:
   - .env file
   - Pi-hole runtime data
   - Database files
   - Backups

3. **Environment Variables**: Your configs use `${DEVICE_IP}` which:
   - Reads from .env locally (your real IP)
   - Shows placeholder in git (generic example)
   - Best of both worlds!

## 📖 Full Documentation

- **[LOCAL_DEVELOPMENT.md](LOCAL_DEVELOPMENT.md)** - Complete local development guide
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - How to contribute
- **[.github-setup-checklist.md](.github-setup-checklist.md)** - GitHub setup steps

## 🆘 Quick Help

**"How do I use my real IP locally?"**
→ Edit `.env` with your device's IP address

**"Will my passwords be committed?"**
→ No! `.env` is gitignored and pre-commit hook checks

**"Can I work on private features?"**
→ Yes! Create a `dev` branch: `git checkout -b dev`

**"I made a mistake!"**
→ `git reset HEAD~1` (if not pushed) or commit a fix

## 🎯 Your Workflow

```bash
# Daily development cycle
git pull origin main           # Get updates
# ... make changes ...
git add <files>                # Stage changes
git commit -m "type: message"  # Hook checks secrets!
git push origin main           # Push to public repo
```

**Your .env stays local with real values - never committed!** ✅

---

Need more help? Read [LOCAL_DEVELOPMENT.md](LOCAL_DEVELOPMENT.md)
