# SETUP.md

## Development Environment Setup

This document describes how to set up the local development environment for this project.

### Environment Used
- OS: macOS (Apple Silicon)
- Shell: zsh
- Package manager: Homebrew
- Python: 3.11.15
- PostgreSQL: 14.22
- dbt Core: 1.11.7
- dbt-postgres: 1.10.0

---

## 1. Install Homebrew

If Homebrew is not already installed:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

echo >> ~/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv zsh)"

brew --version

brew install python@3.11 postgresql@14

brew services start postgresql@14

echo 'export PATH="/opt/homebrew/opt/postgresql@14/bin:$PATH"' >> ~/.zprofile
source ~/.zprofile

python3.11 --version
psql --version
pg_isready

psql postgres

CREATE DATABASE assignment_db;
CREATE USER assignment_user WITH PASSWORD 'assignment_password';
GRANT ALL PRIVILEGES ON DATABASE assignment_db TO assignment_user;

mkdir -p ~/data-stack
cd ~/data-stack
python3.11 -m venv dbt-venv
source dbt-venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install dbt-postgres
dbt --version
deactivate

mkdir -p ~/.dbt

kk_assignment:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      user: assignment_user
      password: assignment_password
      port: 5432
      dbname: assignment_db
      schema: public
      threads: 4

source ~/data-stack/dbt-venv/bin/activate

dbt debug

dbt seed

dbt run

dbt test

dbt build

dbt seeds are used for CSV ingestion because the source data is static files.
If dbt init fails in an existing project directory, dbt_project.yml can be created manually (already included in repo).
The ~/.dbt/profiles.yml file is not checked into version control for security reasons.
PostgreSQL must be running before any dbt commands will work.
The setup was tested on macOS with Apple Silicon (arm64). EOF


