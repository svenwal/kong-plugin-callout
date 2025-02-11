# Kong Plugin | `callout`: Dynamic callout with External Service Integration

This plugin enables dynamic JWT generation by:
1) Extracting values from the request body using configurable JSON paths
2) Making a callout to an external service with the extracted values
3) Extracting values from the service response using configurable JSON paths
4) Creating a JWT with the extracted response values
5) Adding the JWT as a bearer token in a configurable header

The plugin is designed to work as part of an authentication/authorization flow, where additional validation or enrichment is needed from an external service before generating a JWT.

## Configuration Reference

| FORM PARAMETER | DEFAULT | DESCRIPTION |
|:--------------|:--------|:------------|
| `config.extract_paths` | (required) | Map of key-value pairs where values are JSON paths to extract from request body |
| `config.endpoint_url` | (required) | URL of the external service to call |
| `config.ssl_verify` | `true` | Whether to verify SSL certificates when calling the external service |
| `config.set_headers` | `false` | Whether to set extracted request values as headers |
| `config.header_prefix` | `X-Extracted-` | Prefix for headers when set_headers is true |
| `config.jwt_paths` | (required) | Map of key-value pairs where values are JSON paths to extract from service response |
| `config.jwt_secret` | (required) | Secret key for signing the JWT |
| `config.jwt_header_name` | `Authorization` | Header name where the JWT will be set |
| `config.error_message` | `Authentication failed` | Custom error message returned on failures |
| `config.return_errors` | `false` | Whether to include detailed error messages in responses |

## Example Configuration

See the provided `deck-example-dump.yaml` for a complete configuration example. Apply it using:


## Plugin Flow

1. **Request Body Processing**
   - Reads and parses the JSON request body
   - Extracts values using configured `extract_paths`
   - Optionally sets extracted values as headers with `header_prefix`

2. **External Service Call**
   - Makes HTTP POST request to `endpoint_url`
   - Sends extracted values as JSON payload
   - Verifies SSL if `ssl_verify` is true

3. **Response Processing**
   - Parses JSON response from external service
   - Extracts values using configured `jwt_paths`

4. **JWT Generation**
   - Creates JWT using extracted response values
   - Signs JWT with configured `jwt_secret`
   - Sets JWT in `jwt_header_name` with "Bearer" prefix

## Error Handling

The plugin returns 401 Unauthorized with configurable error messages:

```json
{
  "message": "Authentication failed",
  "error": "Detailed error message (if return_errors is true)"
}
```

## Development

### Prerequisites
1. Kong Gateway 3.x
2. Lua development environment
3. Docker and docker-compose (for testing)
4. decK (for configuration management)

### Installation
1. Clone this repository
2. Copy the `plugins/callout` directory to Kong's plugins directory
3. Add 'callout' to the `plugins` list in your Kong configuration
4. Restart Kong

### Testing
Use the provided docker-compose.yaml for testing:

```bash
docker-compose up -d
```

This will start Kong with:
- Admin API on port 6001
- Proxy on port 6000
- Manager on port 6002
- Plugin enabled and ready for testing

Apply the example configuration:
```bash
deck gateway sync --kong-addr http://localhost:6001 < deck-example-dump.yaml
```

Test the plugin with a sample request:
```bash
curl -X POST http://localhost:6000/ \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "id": "123",
      "email": "user@example.com"
    }
  }'
```

Common error scenarios:
- Missing or invalid request body
- JSON parsing errors
- Path extraction failures
- External service connection failures
- External service error responses
- JWT creation failures
