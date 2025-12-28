# PostgreSQL Migration Guide

## Summary

The backend has been migrated from SQLite to PostgreSQL. This provides better reliability, concurrency, and is production-ready.

## Changes Made

### 1. Gemfile
- ✅ Replaced `sqlite3` gem with `pg` gem

### 2. Database Configuration
- ✅ Updated `config/database.yml` to use PostgreSQL
- ✅ Configured for development, test, and production environments
- ✅ Uses environment variables for database credentials

### 3. Docker Configuration
- ✅ Updated `docker-compose.yml` with PostgreSQL environment variables
- ✅ Updated `Dockerfile` to use PostgreSQL client instead of SQLite
- ✅ Updated `docker-entrypoint.sh` to wait for PostgreSQL and run migrations

### 4. Error Handling
- ✅ Updated `TrafficRecord` model to handle PostgreSQL errors
- ✅ Updated `RewardEligibilityService` to handle PostgreSQL errors
- ✅ Changed from `SQLite3::Exception` to `PG::Error` and `ActiveRecord::StatementInvalid`

### 5. Database Tasks
- ✅ Created PostgreSQL-specific rake tasks:
  - `rails db:health_check` - Check database health
  - `rails db:analyze` - Analyze tables for optimization
  - `rails db:vacuum` - Vacuum database
  - `rails db:info` - Show database info

## Next Steps

### 1. Install Dependencies

```bash
cd backend
bundle install
```

This will install the `pg` gem and remove `sqlite3`.

### 2. Start PostgreSQL (Docker)

If using Docker Compose:

```bash
docker-compose up -d db
```

This will start the PostgreSQL container defined in `docker-compose.yml`.

### 3. Create and Migrate Database

```bash
# Create the database
rails db:create

# Run migrations
rails db:migrate

# (Optional) Seed data if you have seeds
rails db:seed
```

### 4. Verify Setup

```bash
# Check database health
rails db:health_check

# Show database info
rails db:info
```

### 5. Start the Application

```bash
# Using Docker Compose
docker-compose up

# Or locally
rails server
```

## Data Migration (If Needed)

If you have existing SQLite data that needs to be migrated:

### Option 1: Export/Import (Recommended for small datasets)

1. Export from SQLite:
   ```bash
   sqlite3 db/development.sqlite3 .dump > sqlite_dump.sql
   ```

2. Convert SQLite dump to PostgreSQL format (manual editing may be required)

3. Import to PostgreSQL:
   ```bash
   psql -h localhost -U postgres devpn_backend < converted_dump.sql
   ```

### Option 2: Recreate Database (For development)

If you don't need to preserve data:

```bash
rails db:drop db:create db:migrate
```

## Environment Variables

The following environment variables are used (with defaults):

- `POSTGRES_HOST` (default: `localhost` for local, `db` for Docker)
- `POSTGRES_PORT` (default: `5432`)
- `POSTGRES_USER` (default: `postgres`)
- `POSTGRES_PASSWORD` (default: `postgres`)
- `POSTGRES_DB` (default: `devpn_backend` for production)

## Troubleshooting

### Connection Refused

If you see "connection refused" errors:

1. Check PostgreSQL is running:
   ```bash
   docker-compose ps db
   # or
   pg_isready -h localhost
   ```

2. Check environment variables are set correctly

3. Verify database exists:
   ```bash
   rails db:create
   ```

### Migration Errors

If migrations fail:

1. Check database connection:
   ```bash
   rails db:health_check
   ```

2. Check migration status:
   ```bash
   rails db:migrate:status
   ```

3. Reset if needed (⚠️ deletes all data):
   ```bash
   rails db:reset
   ```

## Benefits

✅ **No more corruption issues** - PostgreSQL is much more robust
✅ **Better concurrency** - Handles multiple connections efficiently
✅ **Production ready** - Industry standard for production deployments
✅ **Better error handling** - More informative error messages
✅ **ACID compliance** - Full transaction support

## Notes

- Old SQLite database files (`db/*.sqlite3`) can be safely deleted after migration
- The SQLite initializer has been removed
- All database recovery tasks have been updated for PostgreSQL


