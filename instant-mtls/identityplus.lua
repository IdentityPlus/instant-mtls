local http = require("resty.http")
local cjson = require("cjson")
local httpc = nil
local cert = nil
local key = nil
local ssl = require "ngx.ssl"

local _M = {}

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

            return 302
        else
            ngx.status = 400
            ngx.header["Content-Type"] = "text/plain"
            ngx.say("Bad TLS/mTLS request. Possible causes:")
            ngx.say(" - no client certificate detected,")
            ngx.say(" - client certificate expired,")
            ngx.say(" - client certificate authority not trusted,")
            ngx.say(" - client certificate authentication failed,")
            ngx.say(" - certificate owner does not have the right to access the requested content")

            return 400
        end
    end

    function _M.ensure_role(real_host, roles)
        if real_host == nil then
            real_host = ngx.var.host
        end

        -- get the roles of the entity making the request
        local validation = _M.validate(real_host, true)

        if validation ~= nil and validation["service-roles"] ~= nil then
            
            -- _M.print_table(validation["service-roles"], "    ")
            -- pass mTLS information upstream
            ngx.req.set_header("X-TLS-Client-Serial", ngx.var.ssl_client_serial)
            ngx.req.set_header("X-mTLS-ID-Serial", ngx.var.ssl_client_serial)
            ngx.req.set_header("X-mTLS-Roles", table.concat(validation["service-roles"], ","))
            -- ngx.req.set_header("Host", real_host)

            for _, role in pairs(roles) do
                for _, assigned_role in pairs(validation["service-roles"]) do
                    if assigned_role == role then
                        -- nothing to do, audit log maybe
                        ngx.log(0, 'Access granted for mTLS ID '..ngx.var.ssl_client_serial..', on '..real_host..', with role '..role);
                        return
                    end
                end
            end

        end
        
        -- fail the TLS connection if no roles
        -- do audit logs, report the intruder
        ngx.log(0, 'Access blocked for mTLS ID '..ngx.var.ssl_client_serial..', on '..real_host..', no matching roles with any of '..table.concat(roles, ",")..' at this time');

        ngx.exit(_M.fail())
    end

    function _M.purge()
        -- purge mem cache
        ngx.shared.identity_plus_memcache:flush_all()
        ngx.shared.identity_plus_memcache:flush_expired()
        
        -- clean up file caches
        os.execute("rm -rf " .. CACHE_DIR .. "/*")
    end
 
    function _M.simple_diagnostics(host)
        ngx.status = 200
        ngx.header["Content-Type"] = "text/plain"

        ngx.say("Client Serial Number: "..ngx.var.ssl_client_serial.."")
        ngx.say("Client Distinguished Name: "..ngx.var.ssl_client_s_dn.."")
        -- ngx.say("Agent Type: "..ngx.var.ssl_client_s_dn_ou)
        -- ngx.say("Agent ID: "..string.gsub(ngx.var.ssl_client_s_dn_cn, " / %d+", ""))

        ngx.update_time()
        local start_time = ngx.now()
        
        local validation = _M.validate(host, false)
        
        ngx.update_time()
        local end_time = ngx.now()
        
        ngx.say("Response Latency: "..(end_time - start_time).."s")

        local exit_code = 200

        if validation == nil then
            exit_code = _M.fail()

        elseif validation["outcome"] then
            ngx.say("Outcome: "..validation["outcome"].."")
            if validation["service-roles"] then
                _M.say_table_plain(validation["service-roles"], "    ")
            end

        else
            _M.say_table_plain(validation)

        end 

        ngx.exit(exit_code)
    end

 
    function _M.diagnostics(host)
        ngx.status = 200
        ngx.header["Content-Type"] = "text/html"

        ngx.say([[
            <html><body>
            <h2>Identity Plus</h2>
        ]])
        
        ngx.say("<p>Client Serial Number: "..ngx.var.ssl_client_serial.."</p>")
        ngx.say("<p>Client Distinguished Name: "..ngx.var.ssl_client_s_dn.."</p>")
        -- ngx.say("Agent Type: "..ngx.var.ssl_client_s_dn_ou)
        -- ngx.say("Agent ID: "..string.gsub(ngx.var.ssl_client_s_dn_cn, " / %d+", ""))

        ngx.update_time()
        local start_time = ngx.now()
        
        local validation = _M.validate(host, false)
        
        ngx.update_time()
        local end_time = ngx.now()
        
        ngx.say("<p>Response Latency: "..(end_time - start_time).."s</p>")

        local exit_code = 200

        if validation == nil then
            ngx.say("<pre>")
            exit_code = _M.fail()
            ngx.say("</pre>")

        elseif validation["outcome"] then
            ngx.say("<p>Outcome: "..validation["outcome"].."</p>")
            ngx.say("<p>Org. ID: "..validation["organizational-reference"].."</p>")
            
            ngx.say("<p>Service Roles:</p><ul>")
            if validation["service-roles"] then
                _M.say_table(validation["service-roles"], "    ")
            end
            ngx.say("</ul>")

        else
            ngx.say("<pre>")
            _M.say_table(validation)
            ngx.say("</pre>")

        end 

        ngx.req.read_body()
        local args, err = ngx.req.get_post_args()
        if args then
            if args["action"] == "purge" then
                _M.purge()
                ngx.say('<P>Identity Plus Cache Purged ...</P>')
            end
        end

        ngx.say([[
            <FORM method="POST"><INPUT type="SUBMIT" VALUE="Diagnose"><INPUT type="hidden" ID="action" NAME="action" VALUE="diagnose"></FORM>
            <FORM method="POST"><INPUT type="SUBMIT" VALUE="Purge Caches"><INPUT type="hidden" ID="action" NAME="action" VALUE="purge"></FORM>
        ]])
        
        ngx.say("</body></html>")
        ngx.exit(exit_code)
    end

    function _M.configure_mtls(host)
        local ssl = require "ngx.ssl"

        ngx.log(0, 'Loading certificate material for '..host);

        ssl.set_der_cert(_M.load_from_file('/etc/instant-mtls/service-id/'..host..'.cer'))
        ssl.set_der_priv_key(_M.load_from_file('/etc/instant-mtls/service-id/'..host..'.key'))
        ssl.verify_client(ssl.parse_pem_cert(_M.load_from_file('/etc/instant-mtls/identity-plus-trust-store.pem')), 2)
    end

    function _M.load_from_file(path)
        local file = io.open(path, "r")

        if not file then
            return nil, "Could not open file: " .. path
        end

        local content = file:read("*a")
        file:close()

        return content
    end

    function _M.tcp_ensure_role(host, roles)
        -- get the roles of the entity making the request
        local validation = _M.validate(host, false)

        if validation ~= nil and validation["service-roles"] ~= nil then
            -- _M.print_table(validation["service-roles"], "    ")
            for _, role in pairs(roles) do
                for _, assigned_role in pairs(validation["service-roles"]) do
                    if assigned_role == role then
                        -- nothing to do, audit log maybe
                        ngx.log(0, 'Access granted for mTLS ID '..ngx.var.ssl_client_serial..', on '..host..', with role '..role);
                        return
                    end
                end
            end

        end
        
        -- fail the TLS connection if no roles
        -- do audit logs, report the intruder
        ngx.log(0, 'Access blocked for mTLS ID '..ngx.var.ssl_client_serial..', on '..host..', no matching roles at this time');
        ngx.exit(1)            
    end


    function _M.validate(host, cacheable)
        local serial = ngx.var.ssl_client_serial

        if serial == nil then
            return nil
        end

        local distinguished_name = ngx.var.ssl_client_s_dn

        -- see if we have information about this serial cached                
        -- we will cache responses from identity plus to avoid introducing a lag in each and every request
        if cacheable == true then
            local cached_validation = _M.get_from_mem_cache(host, serial)        

            if cached_validation ~= nil then
                -- return cached_validation
                return cached_validation
            end
        end

        local is_cached = true;
        local result = nil

        if cacheable == true then
            result = _M.get_from_disk_cache(serial, host)
        end
        
        if result == nil then
            result = _M.make_https_request('api.'..IDENTITY_PLUS_SERVICE, '/v1', 'GET', '{"Identity-Inquiry": {"serial-number": "0x'..serial..'", "service": "'..host..'"}}')
            is_cached = false
        end

        local validation = cjson.decode(result)

        -- if the response is a profile, we dive into the response
        if validation["Identity-Profile"] then
            validation = validation["Identity-Profile"];
        else
            ngx.log(ngx.ERR, "Unable to perform validations for "..host..": ", result)
        end

        -- in case of a good outcome (whether thre are roles or not)
        if validation["outcome"] and string.find(validation["outcome"], "OK 0001", 0, true) then
            -- update the cache and prefix it with timestamp
            _M.cache(host, serial, validation)
            _M.disk_cache(serial, host, result)

            return validation
        end        

        return nil
    end

    function _M.get_from_mem_cache(host, serial)
        -- resolve from memcache
        local memcache = ngx.shared.identity_plus_memcache

        -- in diagnose mode, we skip the cache
        if memcache ~= nil then
            local cached_roles = memcache:get(host..'/'..serial)

            if cached_roles ~= nil then
                return cached_roles
            end
        end

        return nil
    end

    function _M.get_from_disk_cache(serial, host)
        os.execute("mkdir -p " .. CACHE_DIR.."/"..host)
        local disk_cache = io.open(CACHE_DIR.."/"..host.."/"..serial, "r")
        
        -- if the cache file exist load from cache
        -- in diagnose mode, we skip the cache
        if disk_cache ~= nil then
            local result = disk_cache:read("*all")
            disk_cache:close()

            -- determine how long the value was cached
            local result_index = string.find(result, "{", 0, true)
            local cache_time = os.time() - tonumber(string.sub(result, 0, result_index -1))
            result = string.sub(result, result_index)

            -- if cache is older than the timeout defined, we will invalidate the cache
            -- to force a call to identity plus for fresh results
            if cache_time > CACHE_TIMEOUT then
                return nil
            end
            
            return result
        end

        return nil
    end
    
    function _M.disk_cache(serial, host, result)
        os.execute("mkdir -p " .. CACHE_DIR.."/"..host)
        cache = io.open(CACHE_DIR.."/"..host.."/"..serial, "w")
        cache:write(os.time()..result)
        cache:close()
    end

    function _M.cache(host, serial, roles)
        -- resolve from memcache
        local memcache = ngx.shared.identity_plus_memcache

        -- in diagnose mode, we skip the cache
        if memcache ~= nil then
            memcache:set(host..'/'..serial, roles, CACHE_TIMEOUT)
        end
    end


    -- this uses Identity Plus mTLS Persona to forward the TCP request to Identity Plus.
    -- as such, it is Persona who handles the service agent certificate, we do not care about it in this code 
    function _M.make_https_request(host, path, method, body)
        local sock = ngx.socket.tcp()

        -- Set timeout (in milliseconds)
        sock:settimeout(5000)

        -- Connect to the host and port
        local ok, err = sock:connect(MTLS_PERSONA_HOST, MTLS_PERSONA_PORT)
        if not ok then
            ngx.log(0, "Failed to connect, falling back to curl requests instead. Please check mTLS Prsona is running on "..MTLS_PERSONA_HOST..":"..MTLS_PERSONA_PORT.." : ", err)
            return _M.curl_request("https://"..host.."/"..path, method, body)
        end

        ngx.update_time()
        local start_time = ngx.now()
        
        _M.send_http_request(sock, host, path, method, body)
    
        local body = _M.receive_http_response(sock)

        return body
    end


    function _M.receive_http_response(sock)
        -- Receive the HTTP response
        local response_lines = {}
        local content_length = 0
        while true do
            local line, err = sock:receive("*l")
            if not line then
                ngx.log(ngx.ERR, "failed to receive response: ", err)
                return nil, err
            end
            if line == "" then
                break
            end
            table.insert(response_lines, line)
            
            -- Check for Content-Length header
            local key, value = line:match("^(%S+):%s*(%S+)$")
            if key and key:lower() == "content-length" then
                content_length = tonumber(value)
            end
        end

        -- Read the response body exactly as per the Content-Length header
        local response_body = ""
        if content_length > 0 then
            response_body, err = sock:receive(content_length)
            if not response_body then
                ngx.log(ngx.ERR, "failed to receive response body: ", err)
                return nil, err
            end
        end

        -- Close the connection
        -- sock:close()
        sock:setkeepalive(600000)

        -- Concatenate the response headers and body into a single response string
        local response = table.concat(response_lines, "\n") .. "\r\n\r\n" .. response_body

        -- ngx.log(0, "-------------- response -----------------")
        -- ngx.log(0, "", response)
        -- ngx.log(0, "-------------------------------")

        -- Parse the response
        local body_start = response:find("\r\n\r\n", 1, true)
        if not body_start then
            ngx.log(0, "invalid HTTP response")
            return nil, "invalid HTTP response"
        end

        local body = response:sub(body_start + 4)
        -- ngx.log(0, "response body: ", body)

        return body
    end


    function _M.send_http_request(sock, host, path, method, body)
        -- Prepare the HTTP request
        local request = string.format("%s %s HTTP/1.1\r\nHost: %s\r\nContent-Type: application/json\r\nContent-Length: %d\r\nConnection: keep-alive\r\n\r\n%s", method, path, host, #body, body)

        -- ngx.log(0, "-------------- response -----------------")
        -- ngx.log(0, "", request)
        -- ngx.log(0, "-------------------------------")

        -- Send the HTTP request
        local bytes, err = sock:send(request)
        if not bytes then
            ngx.log(0, "failed to send request: ", err)
            return nil, err
        end
    end


    -- This method works in every situation, but there is no keep-alive across curl processes.
    -- As such, the TCP + TLS handhsake time is added at each reequest, consequently the calls
    -- have about 5x latency
    function _M.curl_request(url, method, body)
        -- no cached value, or expired
        -- make the call to identity plus api to find out about the certificate
        local cmd = '/usr/bin/curl -sk -X '..method..' -H "Content-Type: application/json" -d \''..body..'\' --key '..IDENTITY_PLUS_IDENTITY_FOLDER..'/'..IDENTITY_PLUS_AGENT_NAME..'.key --cert '..IDENTITY_PLUS_IDENTITY_FOLDER..'/'..IDENTITY_PLUS_AGENT_NAME..'.cer '..url

        -- this is for debug purpose
        -- ngx.log(0, '\n---------------------------\n'..cmd..'\n---------------------------\n')

        -- read the output of the command into the result variable
        local output = io.popen(cmd, 'r')
        result = output:read('*all')
        output:close()

        -- this is for debug purpose
        -- ngx.log(0, '\n---------------------------\n'..result..'\n---------------------------\n')

        return result
    end


    -- This method only works with http context as the stream context for some reason the ssl certificate is not set
    function _M.https_request(url, method, body)
        -- Default to GET method if not specified
        method = method or "GET"

        if httpc == nil or cert == nil or key == nil then
            httpc = http.new()
            
            local ssl = require "ngx.ssl"
            cert, err = ssl.parse_pem_cert(_M.load_from_file(IDENTITY_PLUS_IDENTITY_FOLDER..'/'..IDENTITY_PLUS_AGENT_NAME..'.cer'))
            key, err1 = ssl.parse_pem_priv_key(_M.load_from_file(IDENTITY_PLUS_IDENTITY_FOLDER..'/'..IDENTITY_PLUS_AGENT_NAME..'.key'))
        end

        local res, err = httpc:request_uri(url, {
            method = method,
            body = body,
            ssl_verify = false,
            sl_verify_depth = 5,
            keepalive = true,
            ssl_client_cert = cert,
            ssl_client_priv_key = key,
        })
    
        if not res then
            ngx.log(0, "Failed to request: ", err)
            return nil
        end

        return res.body
    end

    function _M.print_table(t, indent)
        indent = indent or ""
        for k, v in pairs(t) do
            if type(v) == "table" then
                ngx.log(0, indent .. k .. ": ")
                _M.print_table(v, indent .. "  ")
            else
                ngx.log(0, indent .. k .. ": ", v)
            end
        end
    end
    
    function _M.say_table(t)
        indent = indent or ""
        for k, v in pairs(t) do
            if type(v) == "table" then
                ngx.say("<p>" .. k .. ":</p><ul>")
                _M.say_table(v)
                ngx.say("</ul>")
            elseif type(v) == "number" then
                ngx.say("<li>" .. k .. ": "..("%.0f"):format(v).."</li>")
            else
                ngx.say("<li>" .. k .. ": "..v.."</li>")
            end
        end
    end

    function _M.say_table_plain(t, indent)
        indent = indent or ""
        for k, v in pairs(t) do
            if type(v) == "table" then
                ngx.say(indent .. k .. ": ")
                _M.say_table_plain(v, indent .. "  ")
            else
                ngx.say(indent .. k .. ": ", v)
            end
        end
    end

return _M
