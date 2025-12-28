#!/bin/bash

echo "🚀 Setting up DeVPN Backend..."

# Check Ruby version
if ! command -v ruby &> /dev/null; then
    echo "❌ Ruby is not installed. Please install Ruby 3.2.0 or later."
    exit 1
fi

# Install bundler if not present
if ! command -v bundle &> /dev/null; then
    echo "📦 Installing bundler..."
    gem install bundler
fi

# Install dependencies
echo "📥 Installing dependencies..."
bundle install

# Setup database
echo "🗄️  Setting up database..."
rails db:create
rails db:migrate

echo "✅ Setup complete!"
echo ""
echo "To start the server:"
echo "  rails server"
echo ""
echo "To start Sidekiq (background jobs):"
echo "  bundle exec sidekiq"

