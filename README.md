# GitHub to GitLab Migration Tool

A tool to fetch and migrate public GitHub repositories to a single GitLab repository.

## Description

This utility allows you to easily mirror all your public GitHub repositories to your company's GitLab instance. Instead of creating separate repositories, it organizes all your GitHub projects within a single GitLab repository for better management and visibility.

## Features

- Fetches all public repositories from a GitHub account
- Migrates all repositories to a single GitLab repository
- Preserves commit history for each repository
- Organizes repositories in a clean directory structure
- Interactive prompts for all required information

## Requirements

- Git
- curl
- jq
- rsync

## Usage

1. Make the script executable:
   ```
   chmod +x github_to_gitlab.sh
   ```

2. Run the script:
   ```
   ./github_to_gitlab.sh
   ```

3. Follow the interactive prompts to provide:
   - GitHub username
   - GitLab URL
   - GitLab repository name
   - GitLab personal access token

## License

© Copyright 2025 Antonin Nvh - https://codequantum.io

---

*"Simplifying GitHub to GitLab migration with one elegant command."*

---

# Outil de Migration GitHub vers GitLab

Un outil pour récupérer et migrer des dépôts GitHub publics vers un dépôt GitLab unique.

## Fonctionnalités

- Récupère tous les dépôts publics d'un compte GitHub
- Migre tous les dépôts vers un dépôt GitLab unique
- Préserve l'historique des commits pour chaque dépôt
- Organise les dépôts dans une structure de répertoires claire
- Invites interactives pour toutes les informations requises

## Prérequis

- Git
- curl
- jq
- rsync

## Utilisation

1. Rendre le script exécutable :
   ```
   chmod +x github_to_gitlab.sh
   ```

2. Exécuter le script :
   ```
   ./github_to_gitlab.sh
   ```

3. Suivre les instructions interactives pour fournir :
   - Nom d'utilisateur GitHub
   - URL GitLab
   - Nom du dépôt GitLab
   - Jeton d'accès personnel GitLab

## Licence

© Copyright 2025 Antonin Nvh - https://codequantum.io

---

*"Simplifying the migration from GitHub to your company's GitLab with a single command."*