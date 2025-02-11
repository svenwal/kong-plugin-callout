local typedefs = require "kong.db.schema.typedefs"

return {
  name = "callout",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { extract_paths = {
              type = "map",
              keys = { type = "string" },
              values = { type = "string" },
              required = true,
          }},
          { endpoint_url = {
              type = "string",
              required = true
          }},
          { ssl_verify = {
              type = "boolean",
              default = true,
          }},
          { set_headers = {
              type = "boolean",
              default = false,
          }},
          { header_prefix = {
              type = "string",
              default = "X-Extracted-",
          }},
          { jwt_paths = {
              type = "map",
              keys = { type = "string" },
              values = { type = "string" },
              required = true,
          }},
          { jwt_secret = {
              type = "string",
              required = true,
          }},
          { jwt_header_name = {
              type = "string",
              default = "Authorization",
          }},
        },
      },
    },
  },
}
