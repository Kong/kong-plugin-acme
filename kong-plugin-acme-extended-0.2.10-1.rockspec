package = "kong-plugin-acme-extended"
version = "0.2.10-1"
source = {
   url = "git+https://github.com/Instamojo/kong-plugin-acme.git",
   branch = "master",
}
description = {
   homepage = "https://github.com/Instamojo/kong-plugin-acme",
   summary = "Let's Encrypt integration with Kong with better domain management",
   license = "Apache 2.0",
}
build = {
   type = "builtin",
   modules = {
      ["kong.plugins.acme-ext.api"] = "kong/plugins/acme/api.lua",
      ["kong.plugins.acme-ext.client"] = "kong/plugins/acme/client.lua",
      ["kong.plugins.acme-ext.daos"] = "kong/plugins/acme/daos.lua",
      ["kong.plugins.acme-ext.handler"] = "kong/plugins/acme/handler.lua",
      ["kong.plugins.acme-ext.migrations.000_base_acme"] = "kong/plugins/acme/migrations/000_base_acme.lua",
      ["kong.plugins.acme-ext.migrations.001_022_to_030"] = "kong/plugins/acme/migrations/001_022_to_030.lua",
      ["kong.plugins.acme-ext.migrations.init"] = "kong/plugins/acme/migrations/init.lua",
      ["kong.plugins.acme-ext.schema"] = "kong/plugins/acme/schema.lua",
      ["kong.plugins.acme-ext.storage.kong"] = "kong/plugins/acme/storage/kong.lua"
   }
}
dependencies = {
  --"kong >= 1.2.0",
  "lua-resty-acme ~> 0.5"
}
