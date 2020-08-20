local typedefs = require "kong.db.schema.typedefs"

return {
  acme_storage = {
    ttl = true,
    primary_key = { "id" },
    cache_key = { "key" },
    name = "acme_storage",
    fields = {
      { id = typedefs.uuid },
      { key = { type = "string", required = true, unique = true, auto = true }, },
      { value = { type = "string", required = true, auto = true }, },
      { created_at = typedefs.auto_timestamp_s },
    },
  },

  acme_domain = {
    primary_key = { "id" },
    cache_key = { "name" },
    endpoint_key = "name",
    generate_admin_api = true,
    admin_api_name = "acme-domains",
    name = "acme_domain",
    fields = {
      { id = typedefs.uuid },
      { name = { type = "string", required = true, unique = true }, },
      { created_at = typedefs.auto_timestamp_s },
    },
  },
}
