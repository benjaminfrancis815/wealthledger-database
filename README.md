# WealthLedger

## Installation
- Install postgreSQL 17.6.
- Execute the following command.

```
psql -U postgres -d postgres -v postgres_password='<Your postgres password>' -v wealthledger_app_password='<Your wealthledger_app password>' -f <path>deployment-script.sql
```
