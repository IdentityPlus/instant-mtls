-- define constants, identity plus API home and the cahce timeout

-- The API home. This is useful to define alternative routes
IDENTITY_PLUS_SERVICE = 'identity.plus'

-- search pattern is /etc/'..host..'/agent-id/'..IDENTITY_PLUS_AGENT_NAME..'.key | .cer
-- example /etc/www.my-service.com/agent-id/Default.key
IDENTITY_PLUS_AGENT_NAME = "Default"

-- subdirectories need to be created for all host-names (../www.my-service.com) and
-- nginx needs to own the sub-folders
CACHE_DIR = "/var/cache/identity-plus"

-- timeout is in seconds (client certificates will be re-validated at this interval)
CACHE_TIMEOUT = 1800

-- authentication fail policy ['block' / 'auth']
STRANGER_POLICY = 'auth'
