-- define constants, identity plus API home and the cahce timeout
IDENTITY_PLUS_SERVICE = 'identity.plus'

-- defines the folder where the agent mTLS ID certificate and key are stored
-- do not use trailing slash
IDENTITY_PLUS_IDENTITY_FOLDER = "/etc/instant-mtls"

-- defines the name of the mTLS ID of the agent
IDENTITY_PLUS_AGENT_NAME = "Service-Agent"

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
