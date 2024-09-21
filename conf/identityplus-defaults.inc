    ssl_certificate             /etc/instant-mtls/service-id/$org_domain.cer;
    ssl_certificate_key         /etc/instant-mtls/service-id/$org_domain.key;
    ssl_client_certificate      /etc/instant-mtls/identity-plus-trust-store.pem;
    ssl_verify_client           optional;
    ssl_verify_depth            2;

    # a default cert is necessary, otherise nginx won't start
    # ssl_certificate             /etc/instant-mtls/resty-auto-ssl-fallback.cer;
    # ssl_certificate_key         /etc/instant-mtls/resty-auto-ssl-fallback.key;

    # set certficates dynamically for the connection
    # ssl_certificate_by_lua_block{
    #     identityplus.configure_mtls(ngx.var.org_domain)
    # }
