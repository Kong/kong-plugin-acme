local client = require "kong.plugins.acme.client"

local function find_plugin()
  local iter = kong.db.plugins:each()
  while true do
    local plugin, err = iter()
    if err then
      return nil, err
    end
    if not plugin then
      return
    end

    if plugin.name == "acme" then
      return plugin
    end
  end
end

return {
  ["/acme/create"] = {
    POST = function(self)
      local plugin, err = find_plugin()
      if err then
        return kong.response.exit(500, { message = err })
      elseif not plugin then
        return kong.response.exit(404)
      end
      local conf = plugin.config

      -- sanity check for kong setup?

      local host = self.params.host
      if not host or type(host) ~= "string" then
        return kong.response.exit(400, { message = "host must be provided and containing a single domain" })
      end
      err = client.update_certificate(conf, host, nil)
      if err then
        return kong.response.exit(500, { message = "failed to update certificate: " .. err })
      end
      err = client.store_renew_config(conf, host)
      if err then
        return kong.response.exit(500, { message = "failed to store renew config: " .. err })
      end
      local msg = "certificate for host " .. host .. " is created"
      return kong.response.exit(201, { message = msg })
    end,
  },

  ["/acme/renew"] = {
    POST = function()
      client.renew_certificate()
      return kong.response.exit(202)
    end,
  },
}
