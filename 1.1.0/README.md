# WealthLedger

## Installation
- Update the values in mutual-funds.csv file.
- Execute the following command.

```
psql -U postgres -d postgres -f <path>deployment-script.sql
```

## Rollback

```
psql -U postgres -d postgres -f <path>rollback-script.sql
```