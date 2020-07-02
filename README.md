
# Kong Authorization-Blake2b custom plugin

Description
====================
The plugin is developed to use with kong API gateway for Custom authentication
and Authorization. As there is multiple plugin is available in kong for authentication. But
to fulfill our requirement we develop this custom plugin named as "Authorization-Blake2b".
This plugin uses hashing technique Blake2b. The plugin is developed with the help of Key-Auth plugin which is already available in kong.

Ths plugin has following mandatory header parameters:

|    Sr. No.|       Name       	| Datatype 	|    type   	| description                                                                                                                                                                                                                                                                                                                                   	|
|:--------:|:----------------:	|:--------:	|:---------:	|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	|
|    1    | cfi-authorization 	|   text   	| Mandatory 	| It is hex value of black2b hash of (cfi-key, cfi-timestamp, cfi-apikey)<br>Need to concat value of (cfi-key, cfi-timestamp, cfi-apikey) and then generate blake2b for this string.<br>where,<br>cfi-key :- UUID of registered Consumer in Kong<br>cfi-timestamp :- Current timestamp <br>cfi-apikey :- UUID of apikey, generated for Consumer 	|
|    2    |      cfi-key     	|   text   	| Mandatory 	| UUID of Consumer                                                                                                                                                                                                                                                                                                                              	|
|    3    |   cfi-timestamp  	|   text   	| Mandatory 	| current time in millisonds.<br>Note: It should be exact same with cfi-timestamp used to create cfi-authorization.                                                                                                                                                                                                                             	|

##### Working of Plugin
It accepts 3 parameters from header that is `cfi-authorization`, `cfi-key`, `cfi-timestamp`.
then it find cfi-apikey associated with cfi-key. if key found then it calculate blake2b hash by concatinating 3 values `cfi_key`, `cfi_timestamp`, `cfi_apikey`.
After creating hash, we convert it into hex code and compare with header parameter `cfi-authorization`.


Plugin Installation
====================

#### Dependancy for plugin installation
1. Luarocks should be installed on system. Please refer following link for installtion.
https://github.com/luarocks/luarocks/wiki/Download

#### Steps for plugin installation

##### 1.Clone the code to any directory in system
```
git clone https://github.com/vaibhav4981/KongCustomPlugin
```
##### 2.move to directory
```
cd ./CustomPlugin
```
##### 3.Install Plugin
```
luarocks make kong-plugin-authorization-blake2b-1.0.0-1.rockspec
```
Now, Plugin is installed but we need to enable it into kong.

##### 4.Enable plugin into kong. Add following line into kong.conf file and restart kong.
For more details refer https://docs.konghq.com/0.10.x/plugin-development/distribution/
```
plugins = bundled,authorization-blake2b
```

##### 5.Enabling the plugin on a Service
```$xslt
$ curl -X POST http://kong:8001/services/{service}/plugins \
    --data "name=authorization-blake2b"
```
{service} is the id or name of the Service that this plugin configuration will target.

##### 6.Enabling the plugin on a Route
```$xslt
$ curl -X POST http://kong:8001/routes/{route}/plugins \
    --data "name=authorization-blake2b"
```
{route} is the id or name of the Route that this plugin configuration will target.


How to use?
====================

#### 1.Create a Consumer (cfi-key)
You need to associate a credential to an existing Consumer object. A Consumer should have only one credential.

To create a Consumer, you can execute the following request:
```$xslt
$curl -d "username=user123&custom_id=SOME_CUSTOM_ID" http://localhost:8001/consumers/
```
Expected Output:
```$xslt
{
	"custom_id": "SOME_CUSTOM_ID",
	"created_at": 1593700255,
	"id": "61ab8768-e75b-491c-b297-b8703208fbf6", //cfi-key
	"tags": null,
	"username": "user123"
}
```

#### 2.Create cfi-apikey
You can provision new credentials by making the following HTTP request.
To create a cfi-apikey, you can execute the following request:
```$xslt
$curl -X POST http://localhost:8001/consumers/{consumer}/key-auth -d '{"key":"CFI_KEY"}'
```
Example:
```$xslt
$curl --location --request POST 'http://tuziaathvan.in:8001/consumers/61ab8768-e75b-491c-b297-b8703208fbf6/key-auth' \
--data-raw '{
    "key":"61ab8768-e75b-491c-b297-b8703208fbf6"
}'
```
Expected Output:
```$xslt
{
    "created_at": 1593702036,
    "consumer": {
        "id": "61ab8768-e75b-491c-b297-b8703208fbf6"
    },
    "id": "031a0bd4-2387-4f5d-b8af-73d4a202c220",
    "tags": null,
    "ttl": null,
    "key": "61ab8768-e75b-491c-b297-b8703208fbf6"
}
```

#### 3.Delete cfi-apikey
You can delete an cfi-api Key by making the following HTTP request:
```$xslt
$curl -X DELETE http://kong:8001/consumers/{consumer}/key-auth/{id}'
```
1. `consumer`: The id or username property of the Consumer entity to associate the credentials to.
2. `id`: The id attribute of the key credential object.

Example:
```$xslt
$curl -X DELETE http://localhost:8001/consumers/61ab8768-e75b-491c-b297-b8703208fbf6/key-auth/031a0bd4-2387-4f5d-b8af-73d4a202c220'
```

#### 4.Create dummy-Service
Create a dummy-service to test plugin.Use following HTTP request:
```$xslt
$curl --location --request POST 'http://localhost:8001/services/' \
--header 'Content-Type: application/json' \
--data-raw '{
    "name": "dummy-service",
	"url":"http://dummy.restapiexample.com/api/v1/employees"
}'
```
Expected Output:
```$xslt
{
    "host": "dummy.restapiexample.com",
    "created_at": 1593702786,
    "connect_timeout": 60000,
    "id": "2a623b8f-7f9e-44b0-9e79-578da60d35f0",
    "protocol": "http",
    "name": "dummy-service",
    "read_timeout": 60000,
    "port": 80,
    "path": "/api/v1/employees",
    "updated_at": 1593702786,
    "retries": 5,
    "write_timeout": 60000,
    "tags": null,
    "client_certificate": null
}
```
#### 5.Create route
Create a dummy route to test plugin.Use following HTTP request:
```$xslt
$curl --location --request POST 'http://tuziaathvan.in:8001/services/dummy-service/routes' \
 --header 'Content-Type: application/json' \
 --data-raw '{
    "hosts": ["dummy.restapiexample.com"],
    "paths": ["/api/v1/employees"]
 }'
```
Expected Output:
```$xslt
{
    "id": "935d6b78-ef60-4f3a-ac2f-b3804b9a7273",
    "path_handling": "v0",
    "paths": [
        "/api/v1/employees"
    ],
    "destinations": null,
    "headers": null,
    "protocols": [
        "http",
        "https"
    ],
    "methods": null,
    "snis": null,
    "service": {
        "id": "2a623b8f-7f9e-44b0-9e79-578da60d35f0"
    },
    "name": null,
    "strip_path": true,
    "preserve_host": false,
    "regex_priority": 0,
    "updated_at": 1593704173,
    "sources": null,
    "hosts": [
        "dummy.restapiexample.com"
    ],
    "https_redirect_status_code": 426,
    "tags": null,
    "created_at": 1593704173
}
```

#### 6.Enable Authorization-Blake2b to our service
When we are enabling plugin to service it automatically apply to all it's route.
```$xslt
$ curl -X POST http://localhost:8001/services/dummy-service/plugins \
    --data "name=authorization-blake2b"
```
Expected Output:
```$xslt
{
	"created_at": 1593703054,
	"config": {
		"key_names": ["cfi-authorization", "cfi-key", "cfi-timeStamp"],
		"run_on_preflight": true,
		"anonymous": null,
		"hide_credentials": false,
		"key_in_body": false
	},
	"id": "aabde500-ffce-4414-bc81-b97bb93f9b03",
	"service": {
		"id": "2a623b8f-7f9e-44b0-9e79-578da60d35f0"
	},
	"enabled": true,
	"protocols": ["grpc", "grpcs", "http", "https"],
	"name": "authorization-blake2b",
	"consumer": null,
	"route": null,
	"tags": null
}
```

Now, We are done with the plugin installation to our dummy-service. let's test it.

#### 7.Test the plugin
As mentioned in description we need 3 header parameters to raise HTTP request.
Here Considering following parameters,

| Sr. No       	| Name           	| Value                                                                                             	                            |
|---------	|-------------------	|----------------------------------------------------------------------------------------------------------------------------------	|
| 1       	| cfi-key        	    | 61ab8768-e75b-491c-b297-b8703208fbf6                                                                                             	|
| 2       	| cfi-apikey        	| 031a0bd4-2387-4f5d-b8af-73d4a202c220                                                                                             	|
| 3       	| cfi-timestamp     	| 1592813588888                                                                                                                    	|
| 4       	| cfi-authorization 	| c8d0b88413763cd23eeb0fdad2b184b09afc04ccf74882656db688a6cfbf023fa75636576b149d2b093af498d8bf94666978d1e4baa2acb95e7f99a54772a7e2 	|

Test out route with following HTTP request:
```$xslt
curl --location --request GET 'http://ec2-13-126-25-34.ap-south-1.compute.amazonaws.com:8000/api/v1/employees' \
--header 'Host: dummy.restapiexample.com' \
--header 'cfi-authorization: c8d0b88413763cd23eeb0fdad2b184b09afc04ccf74882656db688a6cfbf023fa75636576b149d2b093af498d8bf94666978d1e4baa2acb95e7f99a54772a7e2' \
--header 'cfi-key: 61ab8768-e75b-491c-b297-b8703208fbf6' \
--header 'cfi-timestamp: 1592813588888'
```

Expected Output:
```$xslt
{
    "status": "success",
    "data": [
        {
            "id": "1",
            "employee_name": "Tiger Nixon",
            "employee_salary": "320800",
            "employee_age": "61",
            "profile_image": ""
        },
        {
            "id": "2",
            "employee_name": "Garrett Winters",
            "employee_salary": "170750",
            "employee_age": "63",
            "profile_image": ""
        }
    ]
}
```

#### Note:
Test Code to create cfi-authorization.

##### 1.Save below code as test.lua
```$xslt
  local hasher = require 'hasher'
  local hex = require 'hex'
  --concatinating string to create blake2b hash
  local cfi_key=""
  local cfi_timeStamp=""
  local cfi_apikey=""

  local txt = cfi_key .. cfi_timeStamp .. cfi_apikey

  -- generating blak2b hash value
  local generated_hash = hasher.blake2b(txt)

  -- generating hex value for hash
  local enc, err = hex.encode( generated_hash );

  print("Hex Encoded value:",enc)

```

##### 2.Install dependency required to run code
```$xslt
$luarocks install hasher
```
for more details visit https://luarocks.org/modules/edubart/hasher

```$xslt
$luarocks install hex
```
for more details visit https://luarocks.org/modules/mah0x211/hex

##### 3.Run the code (Make sure that you have Lua5.1)
```$xslt
lua test.lua
```
Expected Output:
```$xslt
   Hex Encoded value:c8d0b88413763cd23eeb0fdad2b184b09afc04ccf74882656db688a6cfbf023fa75636576b149d2b093af498d8bf94666978d1e4baa2acb95e7f99a54772a7e2
```
