local client = require "kong.plugins.acme.client"
local http = require "resty.http"

local function find_plugin()
  for plugin, err in kong.db.plugins:each(1000) do
    if err then
      return nil, err
    end

    if plugin.name == "acme" then
      return plugin
    end
  end
end

return {
  ["/acme"] = {
    POST = function(self)
      local plugin, err = find_plugin()
      if err then
        return kong.response.exit(500, { message = err })
      elseif not plugin then
        return kong.response.exit(404)
      end
      local conf = plugin.config

      local host = self.params.host
      if not host or type(host) ~= "string" then
        return kong.response.exit(400, { message = "host must be provided and containing a single domain" })
      end

      -- we don't allow port for security reason in test_only mode
      if string.find(host, ":") ~= nil then
        return kong.response.exit(400, { message = "port is not allowed in host" })
      end

      -- string "true" automatically becomes boolean true from lapis
      if self.params.test_http_challenge_flow == true then
        local check_path = string.format("http://%s/.well-known/acme-challenge/", host)
        local httpc = http.new()
        local res, err = httpc:request_uri(check_path .. "x")
        if not err then
          if ngx.re.match("no Route matched with those values", res.body) then
            err = check_path .. "* doesn't map to a route in Kong"
          elseif res.body ~= "Not found\n" then
            err = "unexpected response found :" .. (res.body or "<nil>")
            if res.status ~= 404 then
              err = err .. string.format(", unexpected status code: %d", res.status)
            end
          else
            return kong.response.exit(200, { message = "sanity test for host " .. host .. " passed"})
          end
        end
        return kong.response.exit(400, { message = "problem found running sanity check for " .. host .. ": " .. err})
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

    PATCH = function()
      client.renew_certificate()
      return kong.response.exit(202, { message = "Renewal process started successfully" })
    end,
  },
  ['/acme-domains/cascade/:host'] = {
    DELETE = function(self)
      local host = self.params.host
      -- retrieve acme_domain for given host
      local entity, err = kong.db.acme_domain:select_by_name(host)
      if err then
        kong.log.err("Error when selecting acme_domain: " .. err)
        return kong.response.exit(500, { message = "failed to retrieve acme domain: " .. err })
      end
      if entity then
         -- delete acme_domain record for the retrieved entity id (for host)
        local ok, err = kong.db.acme_domain:delete({
          id = entity.id,
        })
        if not ok then
          kong.log.err("error while deleting acme_domain: " ..  host .. " : " ..  err)
          return kong.response.exit(500, { message = "failed to delete acme domain entry: " .. host .. " : " .. err })
        end
      else
        kong.log.info("Could not find acme_domain: " .. host .. " ..continuing for sni_entity deletion")
        -- continue to sni_entity deletion even if acme_domain doesn't exist
      end
      -- retrieve sni entity for the given host
      local sni_entity, err = kong.db.snis:select_by_name(host)
      if err then
        kong.log.err("error finding sni entity for: " .. host .. " : " .. err)
        return kong.response.exit(500, { message = "failed to retrieve sni entry for host: " .. host .. " : " .. err })
      end
      if not sni_entity then
        kong.log.info("Could not find sni_entity for: " .. host)
        return kong.response.exit(204, {})
      end
      local cert_id = sni_entity.certificate.id
      -- delete certificate for the sni_entity and sni_entity record
      --- ..binded by foreign key constraint with certificate record
      local ok, err = kong.db.certificates:delete({
        id = cert_id,
      })
      if not ok then
        kong.log.err("error deleting certificate: " .. cert_id .. " for sni_entity:  " .. host .. " : " .. err)
        return kong.response.exit(500, { message = "failed to delete certificate for: " .. host .. " : " .. err })
      end
      -- After certificate is deleted successfully for the given host
      return kong.response.exit(204, {})
    end
  }
}
