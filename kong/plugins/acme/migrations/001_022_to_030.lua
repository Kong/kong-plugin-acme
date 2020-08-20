return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "acme_domain" (
        "id"          UUID   PRIMARY KEY,
        "name"        TEXT   UNIQUE,
        "created_at"  TIMESTAMP WITH TIME ZONE
      );
    ]],
  },

  cassandra = {
    up = [[
      CREATE TABLE IF NOT EXISTS acme_domain (
        id          uuid PRIMARY KEY,
        name        text,
        created_at  timestamp
      );
      CREATE INDEX IF NOT EXISTS acme_domain_name_idx ON acme_domain(name);
    ]],
  },
}
