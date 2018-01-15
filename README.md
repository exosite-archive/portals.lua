# portals.lua

## Installation

Copy [portals.lua](./portals.lua) to the modules folder in your solution as a lua module. You can then require this module in your solution code to use the functions provided by it. For more information on how the modules work, please refer to [Module's docs](http://docs.exosite.com/articles/working-with-apis/#modules).

## API Reference

Please see [portals.lua 1.0.0](https://exosite.github.io/portals.lua/)

## Example

### Assumptions

* Your application is called `fuchico.apps.exosite.io`
* Your endpoint is called `POST /portals`
* Your portals email is `user@example.com`
* Your portals password is `secret`
* You have configured Portals service according to [Exosite Documentation](http://docs.exosite.com/quickstarts/portals/ "Exosite Documentation")

### Annotated source

````lua
--#ENDPOINT POST /portals
local portals = require "portals"

--Make the library talk to the Portals service, you can change this to other
--services with the same API, but if you are talking to the portals service,
--this line is redundant, feel free to delete
portals.setService(Portals)

--Get user token based on email and password in the request body. If any error
--occur, this script exits with the error info.
--
--This assumes that both `email` and `password` exist in the request body. e.g.
--
--```sh
--curl https://yourapp.apps.exosite.io \
--    -d'{"email":"user@example.com","password":"secret"}'
--```
local token = portals.getUserToken({
  email = request.body.email,
  password = request.body.password
})
if token.error ~= nil then
    return token
end

--Get all devices the returned token has access to. Again if there is any
--error, it'll exit with the error info.
local devices = portals.getDevices(token)
if devices.error ~= nil then
    return devices
elseif #devices < 1 then
    return { message = 'No device found' }
end

--Get all data sources associated with those devices the token has access to.
--Exit with error info if any error.
--
--Here we are getting data sources associated with all devices but if you only
--want to get data sources associated with some devices, you can definitely do
--that.
local dataSources = portals.getDataSources(token, devices)
if dataSources.error ~= nil then
    return dataSources
elseif #dataSources < 1 then
    return { message = 'No data source found' }
end

--Filter the data sources table to get data sources associated with the first
--device. We are getting data sources associated with the first device just
--because we are trying to demo how portals.filterDataSourcesByDevice can be
--used.
local dataSourcesOfFirstDevice = portals.filterDataSourcesByDevice(dataSources, devices[1])
if #dataSourcesOfFirstDevice < 1 then
    return { message = 'No data source found on the first device' }
end

--Get last two data points from all data sources associated with the first
--returned devices. Exit with error info on error. Again, you can get data
--points from some data source like above. For more options, please consult the
--API reference.
local dataList = portals.getDataFromDataSources(token, dataSourcesOfFirstDevice, {
    limit = 2
})
if dataList.error ~= nil then
    return dataList
end

--Filter the data list table to get data points associated with the first
--data sources. We are getting data points associated with the first data
--sources just because we are trying to demo how
--portals.filterDataListByDataSources can be used.
local dataOfFirstDataSource = portals.filterDataListByDataSources(
    dataList,
    dataSourcesOfFirstDevice[1]
)

--Exit with the filtered data points
return dataOfFirstDataSource
````
