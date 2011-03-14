-- database things in here
require("mysqloo")
--[[ erayan_config ]]--
local erayan_config = {
	hostname = "localhost";
	username = "root";
	password = "de341h1aa9n";
	database = "ulib-ulx";
	website  = "blackbox.erayan.eu";
	portnumb = 3306;
	server = "TTT";
}

local database

-- The mysqloo ones are descriptive, but a mouthful.
STATUS_READY	= mysqloo.DATABASE_CONNECTED
STATUS_WORKING	= mysqloo.DATABASE_CONNECTING
STATUS_OFFLINE	= mysqloo.DATABASE_NOT_CONNECTED
STATUS_ERROR	= mysqloo.DATABASE_INTERNAL_ERROR


local queries = {
	-- BanChkr
	['insert_log'] = "INSERT INTO `ulxlog` (`ulxLogTimeStamp`, `ulxLogContent`, `ulxLogServer`) VALUES (NOW(), %s, %s)"
}

local function blankCallback() end
local notifyerror, notifymessage
local addLogOnSuccess, addLogOnFailure
local doConnect, databaseOnFailure, databaseOnConnected
-- functions
local function notifyerror(...)
	ErrorNoHalt("[", os.date(), "][erayan_database.lua] ", ...)
	print()
end
local function notifymessage(...)
	local words = table.concat({"[",os.date(),"][erayan_database.lua] ",...},"").."\n"
	ServerLog(words)
	Msg(words)
end

function doConnect()	
	database = mysqloo.connect(erayan_config.hostname, erayan_config.username, erayan_config.password, erayan_config.database, erayan_config.portnumb)
	database.onConnectionFailed = databaseOnFailure
	database.onConnected = databaseOnConnected
	database.pending = {}
	database:connect()
end
function doAddLogItem(str)
	if not database.state == 0 then
		notifyerror( 'SQL Connection not open.' )
		return false
	else
		local queryText = queries['insert_log']:format(str,erayan_config.server)
	local query = database:query(queryText)
	if (query) then
		query.onFailure = addLogOnFailure
		query:start()
		--print('-----------------------Added Log Item-----------------------')
	else
		table.insert(database.pending, {queryText, steamID, name, ply})
		CheckStatus()
	end

	end
end

function addLogOnFailure(self, err)
	notifyerror( 'SQL LogAdd fail ',err )
end

function databaseOnFailure(self, err)
	notifyerror( 'SQL Connect fail ',err  )
end
function databaseOnConnected(self)
	print('-----------------------Connected to DB-----------------------')
end

-- Hooks
do
local function ShutDown()
		if (database) then
			database:abortAllQueries()
		end
	end

hook.Add("ShutDown", "EraYaNDBShutdown", ShutDown)
end

-- Checks the status of the database and recovers if there are errors
-- WARNING: This function is blocking. It is auto-called every 5 minutes.
function CheckStatus()
	if (not database or database.automaticretry) then return end
	local status = database:status()
	if (status == STATUS_WORKING or status == STATUS_READY) then
		return
	elseif (status == STATUS_ERROR) then
		notifyerror("The database object has suffered an inernal error and will be recreated.")
		local pending = database.pending
		doConnect()
		database.pending = pending
	else
		notifyerror("The server has lost connection to the database. Retrying...")
		database:connect()
	end
end
timer.Create("EraYaN-Status-Checker", 300, 0, CheckStatus)

doConnect()
