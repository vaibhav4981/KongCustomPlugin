local typedefs = require "kong.db.schema.typedefs"

return {
  keyauth_credentials = {
    ttl = true,
    primary_key = { "id" },
    name = "keyauth_credentials",
    endpoint_key = "key",
    cache_key = { "key"},
    admin_api_name = "authorization-bcrypts",
    admin_api_nested_name = "authorization-bcrypt",
    fields = {
      { id = typedefs.uuid },
      { created_at = typedefs.auto_timestamp_s },
      { consumer = { type = "foreign", reference = "consumers", required = true, on_delete = "cascade", }, },
      { key = { type = "string", required = false, unique = true, auto = true }, },
      { tags = typedefs.tags },
    },
  },
}

