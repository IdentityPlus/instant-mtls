-- define constants, identity plus API home and the cahce timeout
IDENTITY_PLUS_SERVICE = 'identity.plus'

-- search pattern is /etc/'..host..'/agent-id/'..IDENTITY_PLUS_AGENT_NAME..'.key | .cer
-- example /etc/www.my-service.com/agent-id/Default.key
IDENTITY_PLUS_AGENT_NAME = "Service-Name"

-- subdirectories need to be created for all host-names (../www.my-service.com) and
-- nginx needs to own the sub-folders
CACHE_DIR = "/var/cache/instant-mtls"

-- timeout is in seconds
CACHE_TIMEOUT = 1800

-- authentication fail policy ['block' / 'auth']
STRANGER_POLICY = 'auth'

-- lack of device identity ['strict' / 'lax']
-- not sure this will work, we have to somehow create a session mechanism in LUA
-- otherwise every request will be redirected to identity plus
DEVICE_IDENTITY_POLICY = 'lax'
