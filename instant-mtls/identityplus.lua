local _M = {}

    function _M.init()

        -- ngx.log(ngx.STDERR, '---->> host: '..ngx.var.host..'\n')

        -- read the serial number, this will be a hexadecimal integer value
        local serial = ngx.var.ssl_client_serial
        local distinguished_name = ngx.var.ssl_client_s_dn

        if serial == nil then
            return ''
        end

        -- see if we have information about this serial cached                
        -- we will cache responses from identity plus to avoid introducing a lag in each and every request

        -- resolve from memcache
        local memcache = nill
        if ngx.var.request_uri ~= "/identityplus/diagnose" then
            memcache = ngx.shared.identity_plus_memcache
        end

        -- in diagnose mode, we skip the cache
        if memcache ~= nil then
            local cached_roles = memcache:get(serial)
            if cached_roles ~= nil then
                return cached_roles
            end
        end

        local roles = ""

        -- resolve from file cache
        local result = ""

        local cache = nil
        if ngx.var.request_uri ~= "/identityplus/diagnose" then
            os.execute("mkdir -p " .. CACHE_DIR.."/"..ngx.var.host)
            cache = io.open(CACHE_DIR.."/"..ngx.var.host.."/"..serial, "r")
        end

        -- if the cache file exist load from cache
        -- in diagnose mode, we skip the cache
        if cache ~= nil then
            result = cache:read("*all")
            cache:close()

            -- determine how long the value was cached
            local result_index = string.find(result, "{", 0, true)
            local cache_time = os.time() - tonumber(string.sub(result, 0, result_index -1))
            result = string.sub(result, result_index)

            -- if cache is older than the timeout defined, we will invalidate the cache
            -- to force a call to identity plus for fresh results
            if cache_time > CACHE_TIMEOUT then
                cache = nil
            end
            
            -- this is for debug purpose
            -- ngx.req.set_header("X-Cache-Delta", cache_time)
        end

        -- if we have no cache, we use a second if instead of else, because
        -- cache can be invalidated in the previous if block
        if cache == nil then

            -- make the call to identity plus api to find out about the certificate
            local cmd = '/usr/bin/curl -sk -X GET -H "Content-Type: application/json" -d \'{"Identity-Inquiry": {"serial-number": "0x'..serial..'"}}\' --key '..IDENTITY_PLUS_IDENTITY_FOLDER..'/'..IDENTITY_PLUS_AGENT_NAME..'.key --cert '..IDENTITY_PLUS_IDENTITY_FOLDER..'/'..IDENTITY_PLUS_AGENT_NAME..'.cer https://api.'..IDENTITY_PLUS_SERVICE..'/v1'

            -- this is for debug purpose
            -- ngx.log(0, cmd)

            -- read the output of the command into the result variable
            local output = io.popen(cmd, 'r')
            result = output:read('*all')
            output:close()
        end

        -- if the response is anything other than OK or we have no service-roles defined (it means there is no relationship of any kind)
        -- we will not cache the response either in memory or on disk
        if string.find(result, "OK 0001", 0, true) ~= nil and string.find(result, "service-roles", 0, true) ~= nil then

            -- update the cache and prefix it with timestamp
            if cache == nil then
                -- ngx.log(ngx.STDERR, '---->> cache: '..CACHE_DIR.."/"..ngx.var.host.."/"..serial..'\n')
                os.execute("mkdir -p " .. CACHE_DIR.."/"..ngx.var.host)
                cache = io.open(CACHE_DIR.."/"..ngx.var.host.."/"..serial, "w")
                cache:write(os.time()..result)
                cache:close()
            end                    

            -- extract the roles list, we know we have one, and remove quotes
            s, e = string.find(result, "service-roles", 0, true)
            ss, ee = string.find(result, "]", e, true)
            roles = string.sub(result, e + 4, ss -1)

            -- store to memcache if we have one
            if memcache ~= nil then
                memcache:set(serial, roles, CACHE_TIMEOUT)
            end
        end

        -- this is for debug purposes
        -- ngx.log(0, result)

        return roles

    end


    function _M.fail()
        if STRANGER_POLICY == 'auth' then
            local cmd = '/usr/bin/curl -sk -X PUT -H "Content-Type: application/json" -d \'{"Intent": {"type": "request"}}\' --key '..IDENTITY_PLUS_IDENTITY_FOLDER..'/'..IDENTITY_PLUS_AGENT_NAME..'.key --cert '..IDENTITY_PLUS_IDENTITY_FOLDER..'/'..IDENTITY_PLUS_AGENT_NAME..'.cer https://api.'..IDENTITY_PLUS_SERVICE..'/v1'
            local output = io.popen(cmd, 'r')
            result = output:read('*all')
            output:close()

            s, e = string.find(result, "value\":\"", 0, true)
            intent_id = string.sub(result, e + 1, e + 32)

            ngx.status = 302
            ngx.header["Location"] = 'https://signon.'..IDENTITY_PLUS_SERVICE..'/'..intent_id
            return ngx.exit(302)
        else
            ngx.status = 400
            ngx.header["Content-Type"] = "text/plain"
            ngx.say("Bad TLS/mTLS request. Possible causes:")
            ngx.say(" - no client certificate detected,")
            ngx.say(" - client certificate expired,")
            ngx.say(" - client certificate authority not trusted,")
            ngx.say(" - client certificate authentication failed,")
            ngx.say(" - certificate owner does not have the right to access the requested content")
            return ngx.exit(400)
        end
    end


    function _M.ensure_role(roles)
        local has_role = false

        for index, value in pairs(roles) do
            if string.find(ngx.var.identity_plus_roles, value) ~= nil then
                has_role = true
            end
        end

        if has_role == false then
            _M.fail()
        end
    end

    function _M.purge()
        -- purge mem cache
        ngx.shared.identity_plus_memcache:flush_all()
        ngx.shared.identity_plus_memcache:flush_expired()
        
        -- clean up file caches
        os.execute("rm -rf " .. CACHE_DIR .. "/*")

        -- respond
        ngx.status = 200
        ngx.header["Content-Type"] = "text/plain"
        ngx.say("Identity Plus mTLS caches purged: OK")
        return ngx.exit(200)
    end

    function _M.diagnostics()
        local t_zero = ngx.now()
        ngx.status = 200
        ngx.header["Content-Type"] = "text/plain"
        ngx.say("Identity Plus diagnose: OK")
        ngx.say("Roles: "..ngx.var.identity_plus_roles)
        ngx.say("Client Serial Number: "..ngx.var.ssl_client_serial)
        ngx.say("Client Distinguished Name: "..ngx.var.ssl_client_s_dn)
        ngx.say("Agent Type: "..ngx.var.ssl_client_s_dn_ou)
        ngx.say("Agent ID: "..string.gsub(ngx.var.ssl_client_s_dn_cn, " / %d+", ""))
        ngx.say("Latency: "..(ngx.now() - t_zero))
        return ngx.exit(200)
    end

return _M
