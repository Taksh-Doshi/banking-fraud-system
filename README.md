# Banking Transaction & Fraud Flag Management System

A DBMS mini-project scaffold for a banking transaction and fraud flag management
system. The planned application will use Flask, Jinja templates, MySQL
Connector/Python, HTML, CSS, and JavaScript.

The future system is planned to support customer and staff login, deposits,
withdrawals, transfers, rule-based fraud flags, investigations, transaction
audit logging, and reports. Its planned MySQL tables are `CUSTOMER_ACCOUNT`,
`STAFF`, `BANK_TRANSACTION`, `FRAUD_FLAG`, `INVESTIGATION`, and
`TRANSACTION_AUDIT`. Application behavior and database tables have not been
implemented in this initial scaffold.

## Prerequisites

- Python 3.11 or later.
- MySQL Server 8.0 or later for future database development.
- MySQL Workbench is optional and can be used to inspect a local database.
- Visual Studio Code with a terminal.

## Setup

From the project folder, create a virtual environment if one does not already
exist:

```powershell
python -m venv .venv
```

Activate it in the VS Code PowerShell terminal:

```powershell
.\.venv\Scripts\Activate.ps1
```

Alternatively, in a Command Prompt terminal:

```bat
.\.venv\Scripts\activate.bat
```

Install the project dependencies:

```powershell
python -m pip install -r requirements.txt
```

In VS Code, select the interpreter at `.venv\Scripts\python.exe` if it is not
selected automatically. Copy `.env.example` to `.env` and set local values
before configuring the future application. Do not put real credentials in
`.env.example` or commit `.env`.

## Project structure

```text
banking-fraud-system/
├── app.py
├── db.py
├── fraud_rules.py
├── audit.py
├── .env
├── .env.example
├── .gitignore
├── requirements.txt
├── README.md
├── templates/
│   ├── base.html
│   ├── index.html
│   ├── login.html
│   ├── customer_dashboard.html
│   ├── transaction_form.html
│   ├── transaction_history.html
│   ├── staff_dashboard.html
│   ├── fraud_flags.html
│   └── investigation.html
├── static/
│   ├── css/
│   │   └── style.css
│   ├── js/
│   │   └── main.js
│   └── images/
└── sql/
    ├── schema.sql
    ├── sample_data.sql
    └── reports.sql
```

## SQL files

The `sql/` directory is reserved for the future database schema, non-sensitive
development sample data, and reporting queries. No database tables or records
are created by this scaffold.
