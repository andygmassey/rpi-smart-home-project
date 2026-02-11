#!/bin/bash
# Script to push repository to GitHub with all tags and changes

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Raspberry Pi Smart Home - Push to GitHub                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo "📋 Pre-flight checks..."
echo ""

# Check we're in a git repo
if [ ! -d .git ]; then
    echo "❌ Not in a git repository!"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "⚠️  Warning: You have uncommitted changes!"
    echo ""
    git status --short
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

echo "✅ Repository is clean"
echo ""

# Show what will be pushed
echo "📦 Commits to push:"
git log origin/main..HEAD --oneline 2>/dev/null || git log --oneline -5
echo ""

echo "🏷️  Tags to push:"
git tag -l
echo ""

echo "⚠️  WARNING: This will FORCE PUSH to rewrite history!"
echo "   This is required to remove sensitive data from GitHub."
echo ""
read -p "Ready to push? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "🚀 Pushing to GitHub..."
echo ""

# Force push main branch (to remove sensitive data)
git push origin main --force

# Push tags
git push origin --tags --force

echo ""
echo "✅ Push complete!"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Next Steps:                                               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "1. 📝 Configure repository on GitHub:"
echo "   → See .github-setup-checklist.md for detailed instructions"
echo ""
echo "2. 🏷️  Create v1.0.0 release:"
echo "   → Go to: https://github.com/andygmassey/rpi-smart-home-project/releases/new"
echo "   → Select tag: v1.0.0"
echo "   → Copy release notes from CHANGELOG.md"
echo ""
echo "3. 🌐 Make repository public:"
echo "   → Settings → Danger Zone → Change visibility → Make public"
echo ""
echo "4. ⚙️  Enable Issues and Discussions:"
echo "   → Settings → Features → Check boxes"
echo ""
echo "5. 🏷️  Add topics:"
echo "   → Main page → About → Settings (gear icon)"
echo "   → Add: raspberry-pi, home-automation, docker, smart-home, etc."
echo ""
echo "📖 Full checklist: .github-setup-checklist.md"
echo ""
echo "🎉 Your repository is ready for the world!"
echo ""
