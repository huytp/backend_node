FROM ruby:3.2.0

# Install dependencies
RUN apt-get update -qq && apt-get install -y \
  build-essential \
  libpq-dev \
  nodejs \
  postgresql-client \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install bundler
RUN gem install bundler

# Copy Gemfile (Gemfile.lock is optional)
COPY Gemfile* ./
RUN bundle install

# Copy application
COPY . .

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose port
EXPOSE 3000

# Use entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]

# Start server
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

