local typedefs = require "kong.db.schema.typedefs"


return {
  name = "authorization-blake2b",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { key_names = {
              type = "array",
              required = true,
              elements = typedefs.header_name,
              default = {  "cfi-authorization", "cfi-key", "cfi-timeStamp" },
          }, },
          { hide_credentials = { type = "boolean", default = false }, },
          { anonymous = { type = "string" }, },
          { key_in_body = { type = "boolean", default = false }, },
          { run_on_preflight = { type = "boolean", default = true }, },
        },
    }, },
  },
}