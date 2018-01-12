--- Portals service support functions.
-- Please refer to the [GitHub](https://github.com/exosite/portals.lua) repo
-- for an integration example.
-- @module portals
local di = {
    service = Portals
}
local portals = {}

local function copyTable(dest, source)
    if type(source) == 'table' then
        for sourceKey, sourceVal in pairs(source) do
            dest[sourceKey] = sourceVal
        end
    end
    return dest
end

local function dataSourceToRid(dataSource)
    return dataSource.rid
end

local function deviceEqual(lhs, rhs)
    return lhs.rid == rhs.rid
end

local function filter(predicate)
    return function(unfiltered)
        local filtered = {}
        for _, value in pairs(unfiltered) do
            if predicate(value) then filtered[#filtered+1] = value end
        end
        return filtered
    end
end

local function filterByType(oidType)
    --Assume permission is http://docs.exosite.com/portals/portalsapi/#permission-object
    return filter(function(permission)
        return permission.oid.type == oidType
    end)
end

--See http://docs.exosite.com/portals/portalsapi/#get-multiple-devices for data
--structure of aliases
local function getAliasedRids(aliases)
    local rids = {}

    for rid in pairs(aliases) do
        rids[#rids + 1] = rid
    end

    return rids
end

local function getDataFromMultipleDataSources(token, dataSourceRids, options)
    local params = copyTable({
        dataSourceRids = '['..table.concat(dataSourceRids, ',')..']',
        token = token
    }, options)
    local dataList = di.service.getDataFromMultipleDataSources(params)
    if dataList.error ~= nil then
        local message
        message = 'Failed getDataFromMultipleDataSources'
        return { message = message, error = dataList }
    end
    return dataList
end

local function getMultipleDataSources(token, dataSourceRids)
    local dataSources = di.service.getMultipleDataSources({
        dataSourceRids = '['..table.concat(dataSourceRids, ',')..']',
        token = token
    })
    if dataSources.error ~= nil then
        local message
        message = 'Failed getMultipleDataSources'
        return { message = message, error = dataSources }
    end
    return dataSources
end

local function getMultipleDevices(token, deviceRids)
    local devices = di.service.getMultipleDevices({
        deviceRids = '['..table.concat(deviceRids, ',')..']',
        token = token
    })
    if devices.error ~= nil then
        local message
        message = 'Failed getMultipleDevices'
        return { message = message, error = devices }
    end
    return devices
end

--Assume permissions are http://docs.exosite.com/portals/portalsapi/#permission-object
local function getMultipleGroups(token, groupIds)
    local permissions = di.service.getMultipleGroups({
        groupIds = '['..table.concat(groupIds, ',')..']',
        token = token
    })
    if permissions.error ~= nil then
        local message = 'Failed getMultipleGroups'
        return { message = message, error = permissions }
    end
    return permissions
end

local function getUserPermissions(token)
    local permissions = di.service.getUserPermissions({ token = token })
    if permissions.error ~= nil then
        local message = 'Failed getUserPermissions'
        return { message = message, error = permissions }
    end
    return permissions
end

--Assume permissions are http://docs.exosite.com/portals/portalsapi/#permission-object
local function groupToPermissions(group)
    return group.permissions
end

local function includeDataSource(dataSourceRidList, dataSource)
    for _, dataSourceRid in pairs(dataSourceRidList) do
        if dataSourceRid == dataSource.rid then
            return true
        end
    end
    return false
end

local function includeDevice(uncheckedDevices, device)
    for _, uncheckedDevice in pairs(uncheckedDevices) do
        if deviceEqual(uncheckedDevice, device) then
            return true
        end
    end
    return false
end

--Assume permissions are http://docs.exosite.com/portals/portalsapi/#permission-object
local function listPortalDevices(token, portalId)
    local devices = di.service.listPortalDevices({
        portalId = portalId,
        token = token
    })
    if devices.error ~= nil then
        local message = 'Failed listPortalDevices'
        return { message = message, error = devices }
    end
    return devices
end

local function getDevicesFromMultiplePortals(token, portalIds)
    local deviceLists = {}
    for _, portalId in pairs(portalIds) do
        local devices = listPortalDevices(token, portalId)
        if devices.error ~= nil then
            return devices
        end
        deviceLists[#deviceLists + 1] = devices
    end
    return deviceLists
end

local function map(mapping, unmapped)
    local mapped = {}
    for index,value in pairs(unmapped) do
        mapped[index] = mapping(value)
    end
    return mapped
end

local function merge(merged, unmerged)
    local clone = { unpack(merged) }
    for _, value in pairs(unmerged) do
        clone[#clone + 1] = value
    end
    return clone
end

--See http://docs.exosite.com/portals/portalsapi/#get-multiple-devices for data
--structure of device
local function deviceToDataSources(device)
    return merge(device.dataSources, getAliasedRids(device.info.aliases))
end

local function linkToDevices(dataSources, devices)
    return map(function(dataSource)
        dataSource.devices = filter(function(device)
            local dataSourceRidList = deviceToDataSources(device)
            return includeDataSource(dataSourceRidList, dataSource)
        end)(devices)
        return dataSource
    end, dataSources)
end

local function permissionToId(permission)
    return permission.oid.id
end

local function mapPermissionsToDevices(token, permissions)
    local deviceRids = map(permissionToId, permissions)
    local devices = getMultipleDevices(token, deviceRids)
    return devices
end

local function reduce(reducer)
    return function(source, init)
        for _, value in pairs(source) do
            init = init == nil and value or reducer(init, value)
        end
        return init
    end
end

local function getGroupPermissions(token, permissions)
    local groupIds = map(permissionToId, permissions)
    local groups = getMultipleGroups(token, groupIds)
    if groups.error ~= nil then
        return groups
    end
    local groupPermissionLists = map(groupToPermissions, groups)
    local groupPermissions = reduce(merge)(groupPermissionLists, {})

    return groupPermissions
end

local function stringEqual(lhs, rhs)
    return lhs == rhs
end

local function uniqueBy(isEqual, items)
    local uniques = {}
    for _, item in pairs(items) do
        local inUnique = true
        for _, unique in pairs(uniques) do
            if isEqual(unique, item) then
                inUnique = false
                break;
            end
        end
        if inUnique == true then
            uniques[#uniques + 1] = item
        end
    end
    return uniques
end

local function unique(strings)
    return uniqueBy(stringEqual, strings)
end

local function getPortalDevices(token, permissions)
    local portalIds = unique(map(permissionToId, permissions))
    local deviceLists = getDevicesFromMultiplePortals(token, portalIds)
    if deviceLists.error ~= nil then
        return deviceLists
    end
    local devices = reduce(merge)(deviceLists, {})

    return devices
end

--- Filter data list by a data source
-- This is a helper function to work on the semantic level instead of working on
-- the lower level
-- @tparam table dataList list of data returned by @{getDataFromDataSources}
-- @tparam table dataSource a single data source from the list returned by @{getDataSources}
-- @treturn table data filtered data
function portals.filterDataListByDataSources(dataList, dataSource)
    return dataList[dataSource.rid]
end

--- Filter data sources by a device
-- This is a helper function used in the scenario when all devices and data
-- sources are fetched and cached at once and we need to find data sources
-- associated with a device
-- @tparam table dataSources list of dataSources returned by @{getDataSources}
-- @tparam table device a single devices from the list returned by @{getDevices}
-- @treturn table dataSources filtered dataSources
function portals.filterDataSourcesByDevice(dataSources, device)
    return filter(function(dataSource)
        return includeDevice(dataSource.devices, device)
    end)(dataSources)
end

--- Get data associated by the data sources
-- The token, data sources and options are used together to find all data
-- associated with the data sources.
--
-- There is currently limitation in the implementation preventing a user from
-- successfully getting results back when there are more than 198 data sources.
-- This will be addressed in the next release.
-- @tparam string token a token returned by @{getUserToken}
-- @tparam table dataSources list of dataSources returned by @{getDataSources}
-- @tparam table options options to select the data set see [Get data from
-- multiple data
-- sources](http://docs.exosite.com/portals/portalsapi/#get-data-from-multiple-data-sources)
-- for all options
-- @treturn table list of data indexed by data source rids see [Get data from
-- multiple data
-- sources](http://docs.exosite.com/portals/portalsapi/#get-data-from-multiple-data-sources)
-- for its data structure
function portals.getDataFromDataSources(token, dataSources, options)
    local dataSourceRids = map(dataSourceToRid, dataSources)
    local dataList = getDataFromMultipleDataSources(token, dataSourceRids, options)
    return dataList
end

--- Get data sources associated by the devices
-- The token and the devices are used together to find all data sources
-- associated with the devices.
--
-- There is currently limitation in the implementation preventing a user from
-- successfully getting results back when there are more than 198 devices and/or 198 groups the token has access to
-- This will be addressed in the next release.
-- @tparam string token a token returned by @{getUserToken}
-- @tparam table devices list of devices returned by @{getDevices}
-- @treturn table list of data sources which can be used by other functions see
-- [Get multiple data
-- sources](http://docs.exosite.com/portals/portalsapi/#get-multiple-data-sources)
-- for its data structure
function portals.getDataSources(token, devices)
    local dataSourceRidLists = map(deviceToDataSources, devices)

    local dataSourceRids = unique(reduce(merge)(dataSourceRidLists, {}))

    local dataSources = getMultipleDataSources(token, dataSourceRids)
    if dataSources.error ~= nil then
        return dataSources
    end

    local linkedDataSources = linkToDevices(
        dataSources,
        devices
    )

    return linkedDataSources
end

--- Get user devices
-- The token is used to query all device, portal and group permissions, then it
-- follows group permissions to find more device and portal permissions, then
-- follow all the portal permissions to find all device permissions from here,
-- all device permissions are turned into devices
--
-- There is currently limitation in the implementation preventing a user from
-- successfully getting results back when there are more than 198 devices.
-- This will be addressed in the next release.
-- @tparam string token a token returned by @{getUserToken}
-- @treturn table list of devices which can be used by other functions see [Get
-- multiple
-- devices](http://docs.exosite.com/portals/portalsapi/#get-multiple-devices)
-- for its data structure
function portals.getDevices(token)
    local userPermissions = getUserPermissions(token)
    if userPermissions.error ~= nil then
        return userPermissions
    end

    local userGroupPermissions = filterByType('Group')(userPermissions)
    local groupPermissions = getGroupPermissions(token, userGroupPermissions)
    if groupPermissions.error ~= nil then
        return groupPermissions
    end
    local permissions = merge(userPermissions, groupPermissions)

    local userPortalPermissions = filterByType('Portal')(permissions)
    local portalDevices = getPortalDevices(token, userPortalPermissions)
    if portalDevices.error ~= nil then
        return portalDevices
    end

    local userDevicePermissions = filterByType('Device')(permissions)
    local userDevices = mapPermissionsToDevices(token, userDevicePermissions)
    if userDevices.error ~= nil then
        return userDevices
    end

    local devices = uniqueBy(deviceEqual, merge(portalDevices, userDevices))

    return devices
end

--- Get user token with email and password
-- The email and the password is used together to get a token
-- @tparam table auth authentication info
-- @tparam string auth.email authentication email
-- @tparam string auth.password authentication password
-- @treturn string token which can be used by other functions
function portals.getUserToken(auth)
    local token = di.service.getUserToken(auth)
    if token.error ~= nil then
        local message
        if token.status == 403 then
            message = 'Email does not exist or password is incorrect'
        elseif token.status == 404 then
            message = 'Host does not exist in Portal'
        else
            message = 'Failed getUserToken'
        end
        return { message = message, error = token }
    end
    return token
end

--- Set service
-- Set the service this library works with
-- @tparam string service service instance
-- @treturn string token which can be used by other functions
function portals.setService(service)
    di.service = service
end

return portals
