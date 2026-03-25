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
```

Add Homebrew to the shell:

```bash
echo >> ~/.zprofile
echo 'eval "$(/opt/homebrew/bin/brew shellenv zsh)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv zsh)"
```

Verify:

```bash
brew --version
```

---

## 2. Install Python and PostgreSQL

```bash
brew install python@3.11 postgresql@14
```

Start PostgreSQL:

```bash
brew services start postgresql@14
```

Add PostgreSQL binaries to PATH:

```bash
echo 'export PATH="/opt/homebrew/opt/postgresql@14/bin:$PATH"' >> ~/.zprofile
source ~/.zprofile
```

Verify:

```bash
python3.11 --version
psql --version
pg_isready
```

---

## 3. Create PostgreSQL Database and User

Connect to PostgreSQL:

```bash
psql postgres
```

Create the project database and user:

```sql
CREATE DATABASE assignment_db;
CREATE USER assignment_user WITH PASSWORD 'assignment_password';
GRANT ALL PRIVILEGES ON DATABASE assignment_db TO assignment_user;
\q
```

Test the connection:

```bash
psql -h localhost -U assignment_user -d assignment_db
```

---

## 4. Create dbt Virtual Environment

```bash
mkdir -p ~/data-stack
cd ~/data-stack
python3.11 -m venv dbt-venv
source dbt-venv/bin/activate
pip install --upgrade pip setuptools wheel
pip install dbt-postgres
dbt --version
deactivate
```

---

## 5. Configure dbt Profile

Create the dbt profile file:

```bash
mkdir -p ~/.dbt
```

Add the following to ~/.dbt/profiles.yml:

```yaml
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
```

---

## 6. Clone and Set Up the Project

```bash
git clone <repository-url>
cd kodekloud_assignment
```

Activate the dbt virtual environment:

```bash
source ~/data-stack/dbt-venv/bin/activate
```

Verify the dbt connection:

```bash
dbt debug
```

All checks should pass.

---

## 7. Run the Pipeline

Load raw CSV data into PostgreSQL:

```bash
dbt seed
```

Build all models (staging, dimensions, facts, analytics views):

```bash
dbt run
```

Run tests:

```bash
dbt test
```

Or run everything together:

```bash
dbt build
```

Expected output: PASS=69 WARN=0 ERROR=0 SKIP=0 NO-OP=0 TOTAL=69

---

## 8. Verify the Output

Connect to PostgreSQL and check the results:

```bash
psql -h localhost -U assignment_user -d assignment_db
```

Check seed tables:

```sql
\dt public.*
```

Check MRR/ARR:

```sql
select * from public.view_monthly_mrr_arr;
```

Check top courses by revenue:

```sql
select * from public.view_course_revenue_monthly limit 10;
```

---

## 9. Troubleshooting

### psql command not found
Add PostgreSQL to PATH:

```bash
export PATH="/opt/homebrew/opt/postgresql@14/bin:$PATH"
```

### dbt debug fails with connection error
Ensure PostgreSQL is running:

```bash
brew services start postgresql@14
pg_isready
```

### dbt init fails in existing directory
This is expected. The dbt_project.yml is already included in the repository. Skip dbt init and proceed to dbt debug.

---

## 10. Notes

- dbt seeds are used for CSV ingestion because the source data is static files.
- If dbt init fails in an existing project directory, dbt_project.yml can be created manually (already included in repo).
- The ~/.dbt/profiles.yml file is not checked into version control for security reasons.
- PostgreSQL must be running before any dbt commands will work.
- The setup was tested on macOS with Apple Silicon (arm64).
