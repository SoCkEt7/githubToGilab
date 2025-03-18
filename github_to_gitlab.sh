#!/bin/bash

# ============================================================================ #
#                        GitHub to GitLab Migration Script                      #
# ============================================================================ #
#                                                                              #
#  This script fetches your public GitHub repositories and pushes them         #
#  to a single GitLab repository with proper organization                      #
#                                                                              #
#  Copyright (c) 2025 Antonin Nvh - https://codequantum.io                     #
#                                                                              #
# ============================================================================ #

# Exit on error
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Create temp directory for working
TEMP_DIR="./temp_repos"

# Show banner
display_banner() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "  ╔═════════════════════════════════════════════════════════╗"
    echo "  ║                                                         ║"
    echo "  ║               ${GREEN}GitHub ${RESET}${BOLD}${BLUE}to${RESET}${BOLD}${MAGENTA} GitLab ${BLUE}Migration                  ║"
    echo "  ║                                                         ║"
    echo "  ╚═════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "${CYAN}  Copyright (c) 2025 Antonin Nvh - https://codequantum.io${RESET}"
    echo ""
}

# Check and install requirements
check_requirements() {
    echo -e "${YELLOW}Checking required dependencies...${RESET}"
    
    local missing_deps=()
    
    if ! command -v git >/dev/null 2>&1; then
        missing_deps+=("git")
    fi
    
    if ! command -v curl >/dev/null 2>&1; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq >/dev/null 2>&1; then
        missing_deps+=("jq")
    fi
    
    if ! command -v rsync >/dev/null 2>&1; then
        missing_deps+=("rsync")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Missing required dependencies:${RESET} ${missing_deps[*]}"
        echo -e "${YELLOW}Would you like to install the missing dependencies? (y/n)${RESET}"
        read -r INSTALL_DEPS
        
        if [[ "$INSTALL_DEPS" == "y" ]]; then
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get update
                sudo apt-get install -y "${missing_deps[@]}"
            elif command -v yum >/dev/null 2>&1; then
                sudo yum install -y "${missing_deps[@]}"
            elif command -v brew >/dev/null 2>&1; then
                brew install "${missing_deps[@]}"
            else
                echo -e "${RED}Error: Package manager not supported.${RESET}"
                echo -e "${YELLOW}Please install the following dependencies manually: ${missing_deps[*]}${RESET}"
                exit 1
            fi
        else
            echo -e "${RED}Required dependencies missing. Please install them and run the script again.${RESET}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}All dependencies are installed!${RESET}"
}

# Create log file
setup_logging() {
    LOG_FILE="github_to_gitlab_$(date +'%Y%m%d_%H%M%S').log"
    touch "$LOG_FILE"
    echo -e "${YELLOW}Log file created at:${RESET} ${CYAN}$LOG_FILE${RESET}"
    echo ""
}

# Interactive configuration
get_user_config() {
    echo -e "${YELLOW}Please provide the following information:${RESET}"
    echo ""
    
    read -p "$(echo -e "${CYAN}Enter your GitHub username:${RESET} ")" GITHUB_USERNAME
    read -p "$(echo -e "${CYAN}Enter your GitLab URL (e.g., https://gitlab.company.com):${RESET} ")" GITLAB_URL
    read -p "$(echo -e "${CYAN}Enter your GitLab target repository name:${RESET} ")" GITLAB_REPO
    
    echo -e "${YELLOW}Enter your GitLab personal access token${RESET}"
    echo -e "${CYAN}(Token needs api, read_repository, and write_repository permissions):${RESET} "
    read -s GITLAB_TOKEN
    echo ""
    
    # Validate inputs
    if [ -z "$GITHUB_USERNAME" ] || [ -z "$GITLAB_URL" ] || [ -z "$GITLAB_REPO" ] || [ -z "$GITLAB_TOKEN" ]; then
        echo -e "${RED}Error: All fields are required.${RESET}"
        exit 1
    fi
    
    # Remove trailing slash from GitLab URL if present
    GITLAB_URL=${GITLAB_URL%/}
    
    echo -e "${GREEN}Configuration complete!${RESET}"
    echo ""
}

# Fetch public repositories
fetch_github_repos() {
    echo -e "${YELLOW}Fetching repositories for GitHub user:${RESET} ${CYAN}$GITHUB_USERNAME${RESET}"
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Get list of public repositories with progress indicator
    echo -ne "${YELLOW}Fetching repository list...${RESET} "
    
    REPOS=$(curl -s "https://api.github.com/users/$GITHUB_USERNAME/repos?type=public&per_page=100" | jq -r '.[].name')
    
    if [ -z "$REPOS" ]; then
        echo -e "\n${RED}No public repositories found for user $GITHUB_USERNAME${RESET}"
        exit 1
    fi
    
    REPO_COUNT=$(echo "$REPOS" | wc -l)
    echo -e "${GREEN}Done!${RESET}"
    
    echo -e "${GREEN}Found ${REPO_COUNT} public repositories:${RESET}"
    echo ""
    
    # Display repositories in a nicely formatted list
    local count=1
    while IFS= read -r repo; do
        echo -e "  ${CYAN}$count.${RESET} $repo"
        ((count++))
    done <<< "$REPOS"
    
    echo ""
    echo -e "${YELLOW}Do you want to migrate all repositories? (y/n)${RESET}"
    read -r MIGRATE_ALL
    
    if [[ "$MIGRATE_ALL" != "y" ]]; then
        echo -e "${YELLOW}Enter repository numbers to migrate (comma-separated, e.g. 1,3,5):${RESET} "
        read -r REPO_SELECTION
        
        # Convert selection to array
        IFS=',' read -ra SELECTED_INDICES <<< "$REPO_SELECTION"
        SELECTED_REPOS=""
        
        for index in "${SELECTED_INDICES[@]}"; do
            repo_name=$(echo "$REPOS" | sed -n "${index}p")
            if [ -n "$repo_name" ]; then
                SELECTED_REPOS+="$repo_name"$'\n'
            fi
        done
        
        REPOS=$SELECTED_REPOS
        REPO_COUNT=$(echo "$REPOS" | wc -l)
        
        echo -e "${GREEN}Selected $REPO_COUNT repositories for migration.${RESET}"
    fi
}

# Setup GitLab repository
setup_gitlab_repo() {
    echo -e "${YELLOW}Setting up GitLab repository...${RESET}"
    
    # Check if repository exists
    echo -ne "${YELLOW}Checking if GitLab repository exists:${RESET} ${CYAN}$GITLAB_REPO${RESET} "
    REPO_EXISTS=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
                 "$GITLAB_URL/api/v4/projects?search=$GITLAB_REPO" | \
                 jq -r '.[] | select(.path == "'$GITLAB_REPO'") | .id')
    
    if [ -z "$REPO_EXISTS" ]; then
        echo -e "${YELLOW}Not found.${RESET}"
        echo -ne "${YELLOW}Creating GitLab repository:${RESET} ${CYAN}$GITLAB_REPO${RESET} "
        
        # Clean description to avoid control characters
        CLEAN_DESC="GitHub Mirror Repository - Contains imported public repositories"
        
        curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
             -d "name=$GITLAB_REPO" \
             -d "path=$GITLAB_REPO" \
             -d "description=$CLEAN_DESC" \
             "$GITLAB_URL/api/v4/projects" > /dev/null
        
        echo -e "${GREEN}Done!${RESET}"
    else
        echo -e "${GREEN}Found!${RESET}"
    fi
    
    # Set up the repository URL
    GITLAB_REPO_URL="${GITLAB_URL}/${GITLAB_REPO}.git"
    
    # Check if repository is empty
    echo -ne "${YELLOW}Checking GitLab repository status...${RESET} "
    
    if curl -s --head --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            "$GITLAB_URL/api/v4/projects/$GITLAB_REPO/repository/tree" | grep -q "200 OK"; then
        echo -e "${YELLOW}Repository exists and has content.${RESET}"
        echo -e "${YELLOW}Cloning existing GitLab repository...${RESET}"
        
        git clone "$GITLAB_REPO_URL" gitlab_repo
        cd gitlab_repo
    else
        echo -e "${YELLOW}Repository is empty or new.${RESET}"
        echo -e "${YELLOW}Initializing new GitLab repository...${RESET}"
        
        mkdir -p gitlab_repo
        cd gitlab_repo
        git init
        
        # Create a README file with information
        cat > README.md << EOF
# GitHub Repository Mirror

This repository contains mirrored content from GitHub public repositories of user: $GITHUB_USERNAME

## Description

A comprehensive collection of public GitHub repositories automatically migrated to GitLab. This mirror provides a secure backup and allows for seamless integration with your company's GitLab infrastructure.

## Structure

Each GitHub repository is stored in its own directory under \`github_repos/\`:

\`\`\`
github_repos/
  ├── repo1/
  ├── repo2/
  └── repo3/
\`\`\`

## Copyright

Copyright (c) 2025 Antonin Nvh - https://codequantum.io
EOF
        
        git add README.md
        git commit -m "Initial commit: Repository structure"
        git branch -M main
        git remote add origin "$GITLAB_REPO_URL"
    fi
    
    echo -e "${GREEN}GitLab repository setup complete!${RESET}"
    echo ""
}

# Process a single repository
process_repo() {
    local repo=$1
    local success=0
    
    echo -e "\n${BOLD}${YELLOW}Processing repository:${RESET} ${CYAN}$repo${RESET} ($(($current_repo))/$REPO_COUNT)"
    
    # Create a directory for the repository
    mkdir -p "github_repos/$repo"
    
    # Clone the GitHub repository to a temp location
    echo -ne "${YELLOW}Cloning from GitHub...${RESET} "
    cd ..
    
    if git clone "https://github.com/$GITHUB_USERNAME/$repo.git" temp_clone 2>> "$LOG_FILE"; then
        echo -e "${GREEN}Done!${RESET}"
        
        # Copy contents (excluding .git) to the target directory
        echo -ne "${YELLOW}Copying repository content...${RESET} "
        if rsync -a --exclude='.git' "temp_clone/" "gitlab_repo/github_repos/$repo/" 2>> "$LOG_FILE"; then
            echo -e "${GREEN}Done!${RESET}"
            success=1
        else
            echo -e "${RED}Failed!${RESET}"
        fi
        
        # Remove the temp clone
        rm -rf temp_clone
    else
        echo -e "${RED}Failed!${RESET}"
    fi
    
    # If successful, add and commit
    if [ $success -eq 1 ]; then
        # Go back to GitLab repo directory
        cd gitlab_repo
        
        # Add the new files
        echo -ne "${YELLOW}Adding files to GitLab repo...${RESET} "
        if git add "github_repos/$repo" 2>> "../$LOG_FILE"; then
            echo -e "${GREEN}Done!${RESET}"
            
            # Commit with reference to original repo
            echo -ne "${YELLOW}Committing changes...${RESET} "
            if git commit -m "Import GitHub repository: $repo from $GITHUB_USERNAME" 2>> "../$LOG_FILE"; then
                echo -e "${GREEN}Done!${RESET}"
                echo -e "${GREEN}Repository $repo has been successfully added to the GitLab repository${RESET}"
            else
                echo -e "${RED}Failed!${RESET}"
            fi
        else
            echo -e "${RED}Failed!${RESET}"
        fi
    fi
    
    cd ..
    return $success
}

# Push repositories to GitLab
push_to_gitlab() {
    echo -e "\n${BOLD}${YELLOW}Pushing all repositories to GitLab...${RESET}"
    
    cd gitlab_repo
    
    # Configure GitLab credentials for push
    echo -ne "${YELLOW}Setting up credentials...${RESET} "
    # Set up git credentials for push
    git config credential.helper store
    git config user.name "GitHub Mirror"
    git config user.email "noreply@example.com"
    
    # Handle GitLab URLs with/without https:// prefix
    if [[ "$GITLAB_URL" == http* ]]; then
        echo "https://oauth2:${GITLAB_TOKEN}@${GITLAB_URL#http*://}" > ~/.git-credentials
    else
        echo "https://oauth2:${GITLAB_TOKEN}@${GITLAB_URL}" > ~/.git-credentials
    fi
    
    chmod 600 ~/.git-credentials
    echo -e "${GREEN}Done!${RESET}"
    
    # Push to GitLab
    echo -ne "${YELLOW}Pushing to GitLab...${RESET} "
    
    # Try pushing with different branch names
    if git push -u origin main 2>> "../$LOG_FILE"; then
        echo -e "${GREEN}Success! (main branch)${RESET}"
    elif git push -u origin master 2>> "../$LOG_FILE"; then
        echo -e "${GREEN}Success! (master branch)${RESET}"
    else
        echo -e "${RED}Failed! Attempting force push...${RESET}"
        
        # Try force push as last resort
        if git push -u -f origin main 2>> "../$LOG_FILE"; then
            echo -e "${YELLOW}Success with force push! (main branch)${RESET}"
        elif git push -u -f origin master 2>> "../$LOG_FILE"; then
            echo -e "${YELLOW}Success with force push! (master branch)${RESET}"
        else
            echo -e "${RED}All push attempts failed! See log file for details.${RESET}"
            echo -e "${YELLOW}You may need to manually push the repository.${RESET}"
        fi
    fi
    
    # Remove credentials
    rm ~/.git-credentials
    
    cd ..
}

# Cleanup function
cleanup() {
    echo -e "\n${YELLOW}Do you want to remove the temporary repositories? (y/n)${RESET}"
    read -r CLEANUP
    if [[ "$CLEANUP" == "y" ]]; then
        cd ..
        rm -rf "$TEMP_DIR"
        echo -e "${GREEN}Temporary repositories removed.${RESET}"
    else
        echo -e "${YELLOW}Temporary files kept at:${RESET} ${CYAN}$(pwd)${RESET}"
    fi
}

# Main function
main() {
    # Initialize
    display_banner
    check_requirements
    setup_logging
    get_user_config
    fetch_github_repos
    setup_gitlab_repo
    
    # Process repositories
    echo -e "\n${BOLD}${GREEN}Starting migration of $REPO_COUNT repositories...${RESET}"
    
    current_repo=1
    success_count=0
    
    # Create a progress bar
    while IFS= read -r repo; do
        if [ -n "$repo" ]; then
            if process_repo "$repo"; then
                ((success_count++))
            fi
            ((current_repo++))
        fi
    done <<< "$REPOS"
    
    # Push all to GitLab
    push_to_gitlab
    
    # Show summary
    echo -e "\n${BOLD}${GREEN}Migration Complete!${RESET}"
    echo -e "${GREEN}Successfully migrated $success_count out of $REPO_COUNT repositories.${RESET}"
    echo -e "${YELLOW}GitLab repository:${RESET} ${CYAN}$GITLAB_URL/$GITLAB_REPO${RESET}"
    
    # Cleanup
    cleanup
    
    echo -e "\n${BOLD}${GREEN}Thank you for using GitHub to GitLab Migration Tool!${RESET}"
    echo -e "${CYAN}Copyright (c) 2025 Antonin Nvh - https://codequantum.io${RESET}"
}

# Run the script
main