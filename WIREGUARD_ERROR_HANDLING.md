# WireGuard Error Handling Improvements

## Problem

The application was failing to create WireGuard configs when nodes were unreachable, with errors like:
```
Failed to create WireGuard config: Cannot create WireGuard config: Node API unavailable and no cached info.
Error: Failed to fetch WireGuard info after 2 attempts: Failed to open TCP connection to 183.80.151.69:51820 (execution expired)
```

## Improvements Made

### 1. Configurable Timeouts

Timeouts are now configurable via environment variables:

- `NODE_API_TIMEOUT` (default: 10 seconds) - Total request timeout
- `NODE_API_OPEN_TIMEOUT` (default: 5 seconds) - Connection establishment timeout
- `WIREGUARD_CACHE_MAX_AGE_HOURS` (default: 24 hours) - Maximum age for cached WireGuard info

### 2. Stale Cache Support

The system now:
- Uses cached WireGuard info if available, even if slightly stale (within 24 hours by default)
- Falls back to stale cache if API is unavailable
- Only requires fresh API data if cache is older than the configured threshold

### 3. Better Error Handling

- **Specific error types**: Distinguishes between timeout, connection refused, and network errors
- **Exponential backoff**: Retries with increasing delays (2s, 4s)
- **Better error messages**: More descriptive error messages with context
- **Graceful degradation**: Uses cached info when API is unavailable

### 4. Improved Logging

- Debug logs for each retry attempt
- Warning logs for connection issues
- Error logs with full context
- Cache age information in logs

## Configuration

### Environment Variables

Add to your `.env` or `docker-compose.yml`:

```bash
# Node API timeouts (in seconds)
NODE_API_TIMEOUT=10
NODE_API_OPEN_TIMEOUT=5

# Cache settings (in hours)
WIREGUARD_CACHE_MAX_AGE_HOURS=24
```

### Docker Compose Example

```yaml
services:
  web:
    environment:
      - NODE_API_TIMEOUT=15
      - NODE_API_OPEN_TIMEOUT=8
      - WIREGUARD_CACHE_MAX_AGE_HOURS=48
```

## How It Works

### Connection Flow

1. **Check Cache First**: Look for cached WireGuard info in database
2. **Validate Cache Age**: Use cache if it's within the max age threshold
3. **Fetch from API**: If no cache or cache is stale, fetch from node API
4. **Fallback to Stale Cache**: If API fails but stale cache exists, use it
5. **Error if No Options**: Only raise error if no cache and API unavailable

### Error Handling

The system handles these error types:

- **Connection Timeout**: Node is not responding within timeout period
- **Connection Refused**: Node is not accepting connections
- **Network Error**: General network connectivity issues
- **API Error**: Node API returned an error response

Each error type is logged with appropriate context and the system attempts to recover using cached data.

## Troubleshooting

### Node API Unavailable

If you see "Node API unavailable" errors:

1. **Check Node Status**: Verify the node is running and accessible
   ```bash
   curl http://NODE_IP:51820/api/info
   ```

2. **Check Network**: Ensure backend can reach the node
   ```bash
   telnet NODE_IP 51820
   ```

3. **Increase Timeouts**: If node is slow to respond
   ```bash
   NODE_API_TIMEOUT=30
   NODE_API_OPEN_TIMEOUT=15
   ```

4. **Use Cached Info**: If node is temporarily unavailable, the system will use cached info automatically

### Cache Issues

If cached info is being used but seems incorrect:

1. **Clear Cache**: Update the node record to force refresh
   ```ruby
   node = Node.find_by(address: 'NODE_ADDRESS')
   node.update(wireguard_public_key: nil, wireguard_endpoint: nil)
   ```

2. **Reduce Cache Age**: Force more frequent refreshes
   ```bash
   WIREGUARD_CACHE_MAX_AGE_HOURS=1
   ```

## Best Practices

1. **Monitor Node Health**: Regularly check node availability
2. **Set Appropriate Timeouts**: Balance between responsiveness and reliability
3. **Cache Management**: Keep cache age reasonable (24-48 hours for stable nodes)
4. **Error Monitoring**: Watch logs for connection issues and investigate root causes
5. **Node Registration**: Ensure nodes have valid API URLs configured

## Log Examples

### Successful Cache Use
```
INFO: Using cached WireGuard info from database for node: 0x123... (cache age: 2.5h)
```

### API Fetch Success
```
INFO: Fetching WireGuard info from node API: http://183.80.151.69:51820
INFO: Saved WireGuard info to database for node: 0x123...
```

### Fallback to Stale Cache
```
WARN: Failed to fetch WireGuard info from API: Connection timeout - execution expired
WARN: Using stale cached WireGuard info for node 0x123... (API unavailable)
```

### Connection Error
```
WARN: Connection timeout fetching WireGuard info from http://183.80.151.69:51820 (attempt 1/2): execution expired
WARN: Connection timeout fetching WireGuard info from http://183.80.151.69:51820 (attempt 2/2): execution expired
ERROR: Failed to fetch WireGuard info from API: Failed to fetch WireGuard info after 2 attempts: Connection timeout - execution expired
```


