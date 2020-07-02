local constants = require "kong.constants"


local kong = kong
local _realm = 'Key realm="' .. _KONG._NAME .. '"'

local KeyAuthHandler = {}

KeyAuthHandler.PRIORITY = 1003
KeyAuthHandler.VERSION = "2.1.0"

-- loading credentials from database
local function load_credential(key)
  print("this is key from server",key)
  -- implementing new logic
  local cred, err = kong.db.keyauth_credentials:select_by_key(key)
  if not cred then
    return nil, err
  end
  return cred, nil, cred.ttl
end

local function set_consumer(consumer, credential)
  local set_header = kong.service.request.set_header
  local clear_header = kong.service.request.clear_header

  if consumer and consumer.id then
    set_header(constants.HEADERS.CONSUMER_ID, consumer.id)
  else
    clear_header(constants.HEADERS.CONSUMER_ID)
  end

  if consumer and consumer.custom_id then
    set_header(constants.HEADERS.CONSUMER_CUSTOM_ID, consumer.custom_id)
  else
    clear_header(constants.HEADERS.CONSUMER_CUSTOM_ID)
  end

  if consumer and consumer.username then
    set_header(constants.HEADERS.CONSUMER_USERNAME, consumer.username)
  else
    clear_header(constants.HEADERS.CONSUMER_USERNAME)
  end

  kong.client.authenticate(consumer, credential)

  if credential then
    if credential.username then
      set_header(constants.HEADERS.CREDENTIAL_USERNAME, credential.username)
    else
      clear_header(constants.HEADERS.CREDENTIAL_USERNAME)
    end

    clear_header(constants.HEADERS.ANONYMOUS)

  else
    clear_header(constants.HEADERS.CREDENTIAL_USERNAME)
    set_header(constants.HEADERS.ANONYMOUS, true)
  end
end

-- authenticating request
local function do_authentication(conf)

  local headers = kong.request.get_headers()
  local hasher = require 'hasher'
  local hex = require 'hex'
  local key
  local body

  -- implementing custom logic to get param from headers

  -- cfi-authorizatio (customer key ,current timestamp and cfi-apikey) is blake2b-215 hash of (customer key ,current timestamp and cfi-apikey) converted into hex Value
  -- customer key - UUID of register Consumer in Kong
  -- current timestamp in milliseconds as string
  -- cfi-apikey - UUID of apikey of registered consumer in kong
  local cfi_authorization = headers["cfi-authorization"]

  --  Client Key acquired as part of onboarding with API Management.
  -- customer key - UUID of register Consumer in Kong
  local cfi_key = headers["cfi-key"]

  -- currnet time in milliseconds
  local cfi_timeStamp = headers["cfi-timeStamp"]

  -- this request is missing an cfi-authorization, HTTP 401
  if not cfi_authorization or cfi_authorization == "" or cfi_authorization==nil then
    kong.response.set_header("WWW-Authenticate", _realm)
    return nil, { status = 401, message = "Invalid Authentication" }
  end

  -- this request is missing an cfi_key, HTTP 401
  if not cfi_key or cfi_key == "" or cfi_key==nil then
    kong.response.set_header("WWW-Authenticate", _realm)
    return nil, { status = 401, message = "Invalid Authentication" }
  end

  -- this request is missing an cfi-authorization, HTTP 401
    if not cfi_timeStamp or cfi_timeStamp == "" or cfi_timeStamp == nil then
      kong.response.set_header("WWW-Authenticate", _realm)
      return nil, { status = 401, message = "Invalid Authentication" }
    end

  -- retrieve our consumer linked to this cfi-key from keyauth_credentials table if not available in cache
  local cache = kong.cache
  key = cfi_key
  local credential_cache_key = kong.db.keyauth_credentials:cache_key(key)
  local credential, err = cache:get(credential_cache_key, nil, load_credential,key)

  if err then
    kong.log.err(err)
    return kong.response.exit(500, {
      message = "An unexpected error occurred"
    })
  end

  -- no credential in DB, for this key, it is invalid, HTTP 401
  if not credential then
    return nil, { status = 401, message = "Invalid Authentication" }
  end

  -----------------------------------------
  -- Success, this request is authenticated
  -----------------------------------------

  -- retrieve the consumer linked to this cfi key, to set appropriate headers
  local consumer_cache_key, consumer
  consumer_cache_key = kong.db.consumers:cache_key(credential.consumer.id)
  consumer, err      = cache:get(consumer_cache_key, nil,
                                 kong.client.load_consumer,
                                 credential.consumer.id)
  if err then
    kong.log.err(err)
    return nil, { status = 500, message = "An unexpected error occurred" }
  end

  --concatinating string to create blake2b hash
  local txt = key .. cfi_timeStamp .. credential.id

  -- generating blak2b hash value
  local generated_hash = hasher.blake2b(txt)

  -- generating hex value for hash
  local enc, err = hex.encode( generated_hash );

  -- handling error if error generating hash value
  if(err) then
    return nil, { status = 401, message = "Invalid Authentication" }
  end

  --matching hex encoding with cfi-authorization header
  if enc ~= cfi_authorization then
    return nil, { status = 401, message = "Invalid Authentication" }
  end

  -- if successful setting header
  set_consumer(consumer, credential)

  return true
end

-- managing requst
function KeyAuthHandler:access(conf)
  -- check if preflight request and whether it should be authenticated
  if not conf.run_on_preflight and kong.request.get_method() == "OPTIONS" then
    return
  end

  if conf.anonymous and kong.client.get_credential() then
    -- we're already authenticated, and we're configured for using anonymous,
    -- hence we're in a logical OR between auth methods and we're already done.
    return
  end

  local ok, err = do_authentication(conf)
  if not ok then
    if conf.anonymous then
      -- get anonymous user
      local consumer_cache_key = kong.db.consumers:cache_key(conf.anonymous)
      local consumer, err = kong.cache:get(consumer_cache_key, nil,
                                           kong.client.load_consumer,
                                           conf.anonymous, true)
      if err then
        kong.log.err("failed to load anonymous consumer:", err)
        return kong.response.exit(500, { message = "An unexpected error occurred" })
      end


      set_consumer(consumer, nil)

    else
      return kong.response.exit(err.status, { message = err.message }, err.headers)
    end
  end
end

return KeyAuthHandler
