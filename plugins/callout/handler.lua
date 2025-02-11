local cjson = require "cjson.safe"
local http = require "resty.http"
local jwt = require "resty.jwt"


local CalloutHandler = {
    PRIORITY = 1010,
    VERSION = "0.1",
}


function CalloutHandler:new()
    
end

local function extract_values(json, paths)
    local results = {}
    for key, path in pairs(paths) do
        local value = json
        for segment in path:gmatch("[^.]+") do
            if type(value) ~= "table" then
                return nil, "Invalid path: " .. path
            end
            value = value[segment]
            if value == nil then
                return nil, "Value not found for path: " .. path
            end
        end
        results[key] = value
    end
    return results
end

local function create_jwt(payload, secret)
    -- Create and sign JWT directly using resty.jwt
    local token = jwt:sign(
        secret,
        {
            header = {
                typ = "JWT",
                alg = "HS256"
            },
            payload = payload
        }
    )
    
    if not token then
        kong.log.debug("Failed to create JWT")
        return nil, "Failed to create JWT"
    end
    
    return token
end

function CalloutHandler:access(conf)
    kong.log.debug("Starting access phase")
    kong.log.debug("Endpoint URL: ", conf.endpoint_url)
    
    -- Read and parse request body
    ngx.req.read_body()
    local body = ngx.req.get_body_data()
    if not body then
        local err = "No request body found"
        kong.log.debug(err)
        return kong.response.exit(401, { 
            message = conf.error_message,
            error = conf.return_errors and err or nil
        })
    end
    
    kong.log.debug("Request body: ", body)
    local json_body, err = cjson.decode(body)
    if not json_body then
        local err_msg = "JSON decode error: " .. err
        kong.log.debug(err_msg)
        return kong.response.exit(401, { 
            message = conf.error_message,
            error = conf.return_errors and err_msg or nil
        })
    end
    
    -- Extract values from request body based on configuration
    kong.log.debug("Extracting values with paths: ", cjson.encode(conf.extract_paths))
    local extracted_values, extract_err = extract_values(json_body, conf.extract_paths)
    if not extracted_values then
        local err_msg = "Extraction error: " .. extract_err
        kong.log.debug(err_msg)
        return kong.response.exit(401, { 
            message = conf.error_message,
            error = conf.return_errors and err_msg or nil
        })
    end
    kong.log.debug("Extracted values: ", cjson.encode(extracted_values))
    
    -- Set extracted values as headers if configured
    if conf.set_headers then
        kong.log.debug("Setting headers with prefix: ", conf.header_prefix)
        for key, value in pairs(extracted_values) do
            if type(value) == "string" then
                kong.log.debug("Setting header: ", conf.header_prefix .. key, " = ", value)
                kong.service.request.set_header(conf.header_prefix .. key, value)
            end
        end
    end
    
    -- Make HTTP call to configured endpoint
    kong.log.debug("Making HTTP call to: ", conf.endpoint_url)
    local httpc = http.new()
    local res, err = httpc:request_uri(conf.endpoint_url, {
        method = "POST",
        body = cjson.encode(extracted_values),
        headers = {
            ["Content-Type"] = "application/json",
        },
        ssl_verify = conf.ssl_verify
    })
    
    if not res then
        local err_msg = "HTTP call failed: " .. err
        kong.log.debug(err_msg)
        return kong.response.exit(401, { 
            message = conf.error_message,
            error = conf.return_errors and err_msg or nil
        })
    end
    
    kong.log.debug("HTTP response status: ", res.status)
    kong.log.debug("HTTP response body: ", res.body)
    
    if res.status >= 400 then
        local err_msg = "Endpoint returned error status: " .. res.status
        kong.log.debug(err_msg)
        return kong.response.exit(401, { 
            message = conf.error_message,
            error = conf.return_errors and err_msg or nil
        })
    end
    
    -- Parse response body
    local response_json, parse_err = cjson.decode(res.body)
    if not response_json then
        local err_msg = "Failed to parse response JSON: " .. parse_err
        kong.log.debug(err_msg)
        return kong.response.exit(401, { 
            message = conf.error_message,
            error = conf.return_errors and err_msg or nil
        })
    end
    
    -- Extract values from response for JWT
    kong.log.debug("Extracting JWT values with paths: ", cjson.encode(conf.jwt_paths))
    local jwt_values, jwt_extract_err = extract_values(response_json, conf.jwt_paths)
    if not jwt_values then
        local err_msg = "JWT extraction error: " .. jwt_extract_err
        kong.log.debug(err_msg)
        return kong.response.exit(401, { 
            message = conf.error_message,
            error = conf.return_errors and err_msg or nil
        })
    end
    kong.log.debug("JWT values: ", cjson.encode(jwt_values))
    
    -- Create JWT
    local jwt_token = create_jwt(jwt_values, conf.jwt_secret)
    if not jwt_token then
        local err_msg = "Failed to create JWT token"
        kong.log.debug(err_msg)
        return kong.response.exit(401, { 
            message = conf.error_message,
            error = conf.return_errors and err_msg or nil
        })
    end
    kong.log.debug("Created JWT token: ", jwt_token)
    
    -- Set JWT in header
    kong.log.debug("Setting JWT header: ", conf.jwt_header_name)
    kong.service.request.set_header(conf.jwt_header_name, "Bearer " .. jwt_token)
end

return CalloutHandler
