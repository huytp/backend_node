# Database Management Guide

## PostgreSQL Database Setup

This application now uses PostgreSQL instead of SQLite for better reliability and performance.

### Initial Setup

1. **Start PostgreSQL service** (if using Docker):
   ```bash
   docker-compose up -d db
   ```

2. **Create and migrate database**:
   ```bash
   cd backend
   rails db:create
   rails db:migrate
   ```

### Database Maintenance

#### Health Check

Check database connection and health:

```bash
rails db:health_check
```

This will show:
- Connection status
- Database size
- Long-running queries
- Lock conflicts

#### Analyze Tables

Analyze tables for query optimization:

```bash
rails db:analyze
```

#### Vacuum Database

Vacuum database to reclaim space and update statistics:

```bash
rails db:vacuum
```

#### Database Info

Show database configuration and version:

```bash
rails db:info
```

### Backup and Restore

#### Create Backup

```bash
# Using pg_dump
pg_dump -h localhost -U postgres devpn_backend > backup_$(date +%Y%m%d).sql

# Or using Docker
docker-compose exec db pg_dump -U postgres devpn_backend > backup_$(date +%Y%m%d).sql
```

#### Restore Backup

```bash
# Using psql
psql -h localhost -U postgres devpn_backend < backup_YYYYMMDD.sql

# Or using Docker
docker-compose exec -T db psql -U postgres devpn_backend < backup_YYYYMMDD.sql
```

## Error Handling

The application now handles PostgreSQL errors gracefully:

1. **Connection Errors**: Caught and logged with full stack traces
2. **Query Errors**: Handled without crashing the application
3. **Transaction Errors**: Automatically rolled back

## What Changed

### Files Modified:
- `Gemfile`: Changed from `sqlite3` to `pg` gem
- `config/database.yml`: Updated to use PostgreSQL configuration
- `docker-compose.yml`: Added PostgreSQL environment variables
- `app/models/traffic_record.rb`: Updated error handling for PostgreSQL
- `app/services/reward_eligibility_service.rb`: Updated error handling for PostgreSQL

### New Rake Tasks:
- `rails db:health_check`: Check database connection and health
- `rails db:analyze`: Analyze tables for query optimization
- `rails db:vacuum`: Vacuum database to reclaim space
- `rails db:info`: Show database configuration and version

## Benefits of PostgreSQL

- **Better Concurrency**: Handles multiple connections efficiently
- **ACID Compliance**: Full transaction support with proper isolation levels
- **Robust Error Recovery**: Better handling of connection issues
- **Production Ready**: Industry-standard database for production deployments
- **Advanced Features**: Full-text search, JSON support, and more

## Monitoring

The application will now:
- Log database errors with full stack traces
- Handle connection errors gracefully
- Retry failed queries when appropriate
- Provide detailed error information for debugging

Check logs for messages like:
- "Database error detected" (connection or query issues)
- "Failed to check reward eligibility" (specific operation failures)

