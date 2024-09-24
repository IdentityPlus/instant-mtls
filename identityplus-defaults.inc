    ssl_certificate             /etc/instant-mtls/service-id/rbac.${domain-template}.cer;
    ssl_certificate_key         /etc/instant-mtls/service-id/rbac.${domain-template}.key;
    ssl_client_certificate      /etc/instant-mtls/service-id/identity-plus-root-ca.cer;
    ssl_verify_client           optional;
    ssl_verify_depth            2;
