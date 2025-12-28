namespace :db do
  desc "Check PostgreSQL database connection and basic health"
  task health_check: :environment do
    puts "Checking database health..."

    ActiveRecord::Base.connection_pool.with_connection do |connection|
      if connection.adapter_name == 'PostgreSQL'
        begin
          # Check connection
          connection.execute("SELECT 1")
          puts "✓ Database connection successful"

          # Check database size
          result = connection.execute("SELECT pg_size_pretty(pg_database_size(current_database()))").first
          puts "✓ Database size: #{result['pg_size_pretty']}"

          # Check for long-running queries
          long_queries = connection.execute("
            SELECT count(*) as count
            FROM pg_stat_activity
            WHERE state = 'active'
            AND query_start < now() - interval '5 minutes'
          ").first

          if long_queries['count'].to_i > 0
            puts "⚠ Warning: #{long_queries['count']} long-running queries detected"
          else
            puts "✓ No long-running queries"
          end

          # Check for locks
          locks = connection.execute("
            SELECT count(*) as count
            FROM pg_locks
            WHERE NOT granted
          ").first

          if locks['count'].to_i > 0
            puts "⚠ Warning: #{locks['count']} ungranted locks detected"
          else
            puts "✓ No lock conflicts"
          end

          puts "✓ Database health check passed"
        rescue => e
          puts "✗ Database health check failed: #{e.message}"
          exit 1
        end
      else
        puts "This task is for PostgreSQL databases"
      end
    end
  end

  desc "Analyze PostgreSQL database tables for query optimization"
  task analyze: :environment do
    puts "Analyzing database tables..."

    ActiveRecord::Base.connection_pool.with_connection do |connection|
      if connection.adapter_name == 'PostgreSQL'
        begin
          # Get all tables
          tables = connection.execute("
            SELECT tablename
            FROM pg_tables
            WHERE schemaname = 'public'
          ").map { |row| row['tablename'] }

          tables.each do |table|
            puts "Analyzing table: #{table}..."
            connection.execute("ANALYZE #{table};")
          end

          puts "✓ Database analysis complete"
        rescue => e
          puts "✗ Analysis error: #{e.message}"
          exit 1
        end
      else
        puts "This task is for PostgreSQL databases"
      end
    end
  end

  desc "Vacuum PostgreSQL database to reclaim space"
  task vacuum: :environment do
    puts "Vacuuming database..."

    ActiveRecord::Base.connection_pool.with_connection do |connection|
      if connection.adapter_name == 'PostgreSQL'
        begin
          # Get all tables
          tables = connection.execute("
            SELECT tablename
            FROM pg_tables
            WHERE schemaname = 'public'
          ").map { |row| row['tablename'] }

          tables.each do |table|
            puts "Vacuuming table: #{table}..."
            connection.execute("VACUUM ANALYZE #{table};")
          end

          puts "✓ Database vacuum complete"
        rescue => e
          puts "✗ Vacuum error: #{e.message}"
          exit 1
        end
      else
        puts "This task is for PostgreSQL databases"
      end
    end
  end

  desc "Show database connection info"
  task info: :environment do
    config = ActiveRecord::Base.connection_config
    puts "Database Configuration:"
    puts "  Adapter: #{config[:adapter]}"
    puts "  Database: #{config[:database]}"
    puts "  Host: #{config[:host] || 'localhost'}"
    puts "  Port: #{config[:port] || 5432}"
    puts "  Username: #{config[:username]}"
    puts "  Pool: #{config[:pool] || 5}"

    ActiveRecord::Base.connection_pool.with_connection do |connection|
      if connection.adapter_name == 'PostgreSQL'
        begin
          version = connection.execute("SELECT version()").first['version']
          puts "  PostgreSQL Version: #{version.split(',')[0]}"

          db_size = connection.execute("SELECT pg_size_pretty(pg_database_size(current_database()))").first
          puts "  Database Size: #{db_size['pg_size_pretty']}"
        rescue => e
          puts "  Error getting database info: #{e.message}"
        end
      end
    end
  end
end
