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
  ['/acme-domains/:host'] = {
    DELETE = function(self)
      kong.log.err("HMMMMMMMM")
      local host = self.params.host
      local entity, err = kong.db.acme_domain:select_by_name(host)
      if err then
        kong.log.err("Error when selecting acme_domain: " .. err)
        return nil
      end
      if not entity then
        kong.log.err("Could not find acme_domain.")
        return nil
      end
      local ok, err_0 = kong.db.acme_domain:delete({
        id = entity.id,
      })
      if not ok then
        kong.log.err("error while deleting acme_domain ", host, err_0)
        return
      end
      local sni_entity, err = kong.db.snis:select_by_name(host)
      if err then
        kong.log.err("error finding sni entity: ", err)
        return
      end
      kong.log.err(sni_entity)
      local cert_id = sni_entity.certificate.id
      local ok, err = kong.db.snis:delete({
        id = sni_entity.id,
      })
      if not ok then
        kong.log.err("error deleting certificate entity ", host, ": ", err)
        return err
      end
      local ok, err_2 = kong.db.certificates:delete({
        id = cert_id,
      })
      if not ok then
        kong.log.err("error cleaning up certificate entity ", cert_id, ": ", err_2)
      end
    end
  }
}
