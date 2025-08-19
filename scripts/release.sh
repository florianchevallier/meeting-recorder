#!/bin/bash

# MeetingRecorder Release Script
# Usage: ./scripts/release.sh [version] [--dry-run]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables
DRY_RUN=false
VERSION=""
CURRENT_BRANCH=""

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    cat << EOF
🚀 MeetingRecorder Release Script

USAGE:
    $0 <version> [--dry-run]

EXAMPLES:
    $0 1.0.0                 # Create release v1.0.0
    $0 1.0.1 --dry-run      # Simulate release v1.0.1
    $0 --help               # Show this help

WHAT IT DOES:
    ✅ Validates version format (semver)
    ✅ Checks git status (clean working directory)
    ✅ Runs tests to ensure quality
    ✅ Creates and pushes git tag
    ✅ Monitors GitHub Actions pipeline
    ✅ Updates Homebrew formula automatically
    ✅ Opens release page when ready

REQUIREMENTS:
    - Clean git working directory
    - On main branch
    - Tests passing
    - GitHub CLI (gh) installed
EOF
}

validate_version() {
    local version=$1
    
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
        log_error "Invalid version format: $version"
        log_info "Expected: MAJOR.MINOR.PATCH (e.g., 1.0.0, 2.1.3-beta)"
        exit 1
    fi
    
    if git tag | grep -q "^v$version$"; then
        log_error "Tag v$version already exists"
        log_info "Existing tags:"
        git tag | grep "^v" | sort -V | tail -5
        exit 1
    fi
    
    log_success "Version $version is valid"
}

check_requirements() {
    log_info "Checking requirements..."
    
    # Check current branch
    CURRENT_BRANCH=$(git branch --show-current)
    if [[ "$CURRENT_BRANCH" != "main" ]]; then
        log_error "Must be on main branch. Currently on: $CURRENT_BRANCH"
        exit 1
    fi
    
    # Check clean working directory
    if ! git diff-index --quiet HEAD --; then
        log_error "Working directory is not clean"
        git status --porcelain | head -5
        log_info "Commit or stash changes before release"
        exit 1
    fi
    
    # Check GitHub CLI
    if ! command -v gh &> /dev/null; then
        log_warning "GitHub CLI not found"
        log_info "Install with: brew install gh"
        log_info "Script will continue without GitHub integration"
        return 0
    fi
    
    # Check GitHub auth
    if ! gh auth status &> /dev/null; then
        log_warning "Not authenticated with GitHub CLI"
        log_info "Run: gh auth login"
        log_info "Script will continue without GitHub integration"
        return 0
    fi
    
    log_success "All requirements met"
}

run_tests() {
    log_info "Running tests..."
    
    if $DRY_RUN; then
        log_info "[DRY RUN] Would run: swift test"
        return 0
    fi
    
    if swift test --quiet; then
        log_success "All tests passed"
    else
        log_error "Tests failed"
        log_info "Fix tests before creating release"
        exit 1
    fi
}

create_release() {
    local version=$1
    
    log_info "Creating release v$version..."
    
    if $DRY_RUN; then
        log_info "[DRY RUN] Would create tag: v$version"
        log_info "[DRY RUN] Would push to origin"
        return 0
    fi
    
    # Create annotated tag
    git tag -a "v$version" -m "Release version $version

🎉 Features:
- Unified ScreenCaptureKit recording (macOS 15+)
- Automatic Teams meeting detection
- High-quality audio capture (system + microphone)
- Menu bar interface
- Smart file naming

📦 Installation:
Download DMG from GitHub Releases and right-click → Open

🔗 https://github.com/florianchevallier/meeting-recorder/releases/tag/v$version"
    
    log_success "Created tag v$version"
    
    # Push tag to trigger CI/CD
    log_info "Pushing tag to GitHub..."
    git push origin "v$version"
    log_success "Pushed tag v$version"
}

update_homebrew_formula() {
    local version=$1
    
    log_info "Updating Homebrew formula..."
    
    if $DRY_RUN; then
        log_info "[DRY RUN] Would update homebrew-tap/Formula/meety.rb to v$version"
        return 0
    fi
    
    if [[ ! -f "homebrew-tap/update_formula.sh" ]]; then
        log_warning "Homebrew update script not found, skipping formula update"
        return 0
    fi
    
    # Update the formula with the new version
    cd homebrew-tap
    if ./update_formula.sh "v$version"; then
        log_success "Formula updated successfully"
        
        # Commit and push the updated formula
        git add Formula/meety.rb
        if git commit -m "chore: update Meety to v$version"; then
            log_info "Pushing formula update..."
            git push origin main
            log_success "Homebrew formula updated and pushed!"
        else
            log_warning "No changes to commit for formula (possibly already up to date)"
        fi
    else
        log_warning "Failed to update Homebrew formula automatically"
        log_info "You can update it manually later with: cd homebrew-tap && ./update_formula.sh v$version"
    fi
    
    cd ..
}

monitor_pipeline() {
    local version=$1
    
    if $DRY_RUN; then
        log_info "[DRY RUN] Would monitor GitHub Actions pipeline"
        return 0
    fi
    
    if ! command -v gh &> /dev/null || ! gh auth status &> /dev/null; then
        log_info "GitHub CLI not available - check manually:"
        log_info "https://github.com/florianchevallier/meeting-recorder/actions"
        return 0
    fi
    
    log_info "Monitoring GitHub Actions pipeline..."
    
    # Wait for workflow to start
    sleep 5
    
    # Find the workflow run for our tag
    local run_id
    run_id=$(gh run list --event push --limit 5 --json databaseId,headSha,headBranch --jq ".[] | select(.headBranch == \"v$version\") | .databaseId" 2>/dev/null | head -1 || echo "")
    
    if [[ -n "$run_id" && "$run_id" != "null" ]]; then
        log_info "Found workflow run: $run_id"
        log_info "Watching pipeline progress..."
        
        if gh run watch "$run_id" --exit-status; then
            log_success "Pipeline completed successfully!"
            
            # Update Homebrew formula after successful release
            update_homebrew_formula "$version"
            
            # Open release page
            sleep 2
            log_info "Opening release page..."
            gh release view "v$version" --web
        else
            log_error "Pipeline failed"
            log_info "Check logs: gh run view $run_id --log"
            exit 1
        fi
    else
        log_warning "Could not find workflow run"
        log_info "Monitor manually: https://github.com/florianchevallier/meeting-recorder/actions"
    fi
}

show_success() {
    local version=$1
    
    echo
    echo "🎉🎉🎉 RELEASE SUCCESS! 🎉🎉🎉"
    echo
    log_success "Release v$version created successfully!"
    echo
    echo "📦 Release URL:"
    echo "   https://github.com/florianchevallier/meeting-recorder/releases/tag/v$version"
    echo
    echo "📋 What happened:"
    echo "   ✅ Tests passed"
    echo "   ✅ Tag v$version created and pushed"
    echo "   ✅ GitHub Actions pipeline triggered"
    echo "   ✅ DMG built and uploaded automatically"
    echo "   ✅ Release notes generated"
    echo "   ✅ Homebrew formula updated automatically"
    echo
    echo "🚀 Users can now install via:"
    echo "   📦 Direct download: GitHub Releases"
    echo "   🍺 Homebrew: brew install florianchevallier/meety/meety"
    
    if $DRY_RUN; then
        echo
        log_warning "This was a DRY RUN - no actual changes were made"
    fi
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [[ -z "$VERSION" ]]; then
                    VERSION=$1
                else
                    log_error "Multiple versions specified"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Check if version provided
    if [[ -z "$VERSION" ]]; then
        log_error "Version is required"
        echo
        show_usage
        exit 1
    fi
    
    # Header
    echo "🚀 MeetingRecorder Release Script"
    echo "=================================="
    echo
    log_info "Version: $VERSION"
    if $DRY_RUN; then
        log_warning "DRY RUN MODE - No changes will be made"
    fi
    echo
    
    # Execute release process
    check_requirements
    validate_version "$VERSION"
    run_tests
    create_release "$VERSION"
    monitor_pipeline "$VERSION"
    show_success "$VERSION"
}

# Execute main with all arguments
main "$@"