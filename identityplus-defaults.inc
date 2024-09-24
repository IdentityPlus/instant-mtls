    ssl_certificate             /etc/instant-mtls/service-id/rbac.${domain}.cer;
    ssl_certificate_key         /etc/instant-mtls/service-id/rbac.${domain}.key;
    ssl_client_certificate      /etc/instant-mtls/service-id/identity-plus-trust-store.cer;
    ssl_verify_client           optional;
    ssl_verify_depth            2;
