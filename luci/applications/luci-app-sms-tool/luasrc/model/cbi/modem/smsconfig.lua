-- Copyright 2020-2023 Rafa� Wabik (IceG) - From eko.one.pl forum
-- Licensed to the GNU General Public License v3.0.

local util = require "luci.util"
local fs = require "nixio.fs"
local sys = require "luci.sys"
local http = require "luci.http"
local dispatcher = require "luci.dispatcher"
local http = require "luci.http"
local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

local USSD_FILE_PATH = "/etc/config/ussd.user"
local PHB_FILE_PATH = "/etc/config/phonebook.user"
local SMSC_FILE_PATH = "/etc/config/smscommands.user"
local AT_FILE_PATH = "/etc/config/atcmds.user"

local led = tostring(uci:get("sms_tool", "general", "smsled"))
local dsled = tostring(uci:get("sms_tool", "general", "ledtype"))
local ledtime = tostring(uci:get("sms_tool", "general", "checktime"))

local m
local s
local dev1, dev2, dev3, dev4, leds
local try_devices1 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_devices2 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_devices3 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_devices4 = nixio.fs.glob("/dev/tty[A-Z][A-Z]*")
local try_leds = nixio.fs.glob("/sys/class/leds/*")


local devv = tostring(uci:get("sms_tool", "general", "readport"))

local smsmem = tostring(uci:get("sms_tool", "general", "storage"))

local statusb = luci.util.exec("sms_tool -s".. smsmem .. " -d ".. devv .. " status")

local smsnum = string.sub (statusb, 23, 27)

local smscount = string.match(smsnum, '%d+')

m = Map("sms_tool", translate("Configuration sms-tool"),
	translate("Configuration panel for sms_tool and gui application."))

s = m:section(NamedSection, 'general' , "sms_tool" , "" .. translate(""))
s.anonymous = true
s:tab("sms", translate("SMS Settings"))
s:tab("info", translate("Notification Settings"))

this_tab = "sms"

dev1 = s:taboption(this_tab, Value, "readport", translate("SMS Reading Port"))
if try_devices1 then
local node
for node in try_devices1 do
dev1:value(node, node)
end
end

mem = s:taboption(this_tab, ListValue, "storage", translate("Message storage area"), translate("Messages are stored in a specific location (for example, on the SIM card or modem memory), but other areas may also be available depending on the type of device."))
mem.default = "SM"
mem:value("SM", translate("SIM card"))
mem:value("ME", translate("Modem memory"))
mem.rmempty = true

local msm = s:taboption(this_tab, Flag, "mergesms", translate("Merge split messages"), translate("Checking this option will make it easier to read the messages, but it will cause a discrepancy in the number of messages shown and received."))
msm.rmempty = false

msma = s:taboption(this_tab, ListValue, "algorithm", translate("Merge algorithm"), translate(""))
msma.default = "Simple"
msma:value("Simple", translate("Simple (merge without sorting)"))
msma:value("Advanced", translate("Advanced (merges with sorting)"))
msma:depends("mergesms", "1")
msma.rmempty = true

msmd = s:taboption(this_tab, ListValue, "direction", translate("Direction of message merging"), translate(""))
msmd.default = "Start"
msmd:value("Start", translate("From beginning to end"))
msmd:value("End", translate("From end to beginning"))
msmd:depends("algorithm", "Advanced")
msmd.rmempty = true

dev2 = s:taboption(this_tab, Value, "sendport", translate("SMS Sending Port"))
if try_devices2 then
local node
for node in try_devices2 do
dev2:value(node, node)
end
end

local t = s:taboption(this_tab, Value, "pnumber", translate("Prefix Number"), translate("The phone number should be preceded by the country prefix (for Poland it is 48, without '+'). If the number is 5, 4 or 3 characters, it is treated as 'short' and should not be preceded by a country prefix."))
t.rmempty = true
t.default = 48

local f = s:taboption(this_tab, Flag, "prefix", translate("Add Prefix to Phone Number"), translate("Automatically add prefix to the phone number field."))
f.rmempty = false


local i = s:taboption(this_tab, Flag, "information", translate("Explanation of number and prefix"), translate("In the tab for sending SMSes, show an explanation of the prefix and the correct phone number."))
i.rmempty = false

this_tabb = "info"

local uw = s:taboption(this_tabb, Flag, "lednotify", translate("Notify new messages"), translate("The LED informs about a new message. Before activating this function, please config and save the SMS reading port, time to check SMS inbox and select the notification LED."))
uw.rmempty = false

function uw.write(self, section, value)
if devv ~= nil or devv ~= '' then
if ( smscount ~= nil and led ~= nil ) then
    if value == '1' then

       luci.sys.call("echo " .. smscount .. " > /etc/config/sms_count")
	luci.sys.call("uci set sms_tool.general.lednotify=" .. 1 .. ";/etc/init.d/smsled enable;/etc/init.d/smsled start")
	luci.sys.call("/sbin/cronsync.sh")

    elseif value == '0' then
       luci.sys.call("uci set sms_tool.general.lednotify=" .. 0 .. ";/etc/init.d/smsled stop;/etc/init.d/smsled disable")
	    if dsled == 'D' then
		luci.sys.call("echo 0 > '/sys/class/leds/" .. led .. "/brightness'")
	    end
	luci.sys.call("/sbin/cronsync.sh")

    end
return Flag.write(self, section ,value)
  end
end
end

local time = s:taboption(this_tabb, Value, "checktime", translate("Check inbox every minute(s)"), translate("Specify how many minutes you want your inbox to be checked."))
time.rmempty = false
time.maxlength = 2
time.default = 5

function time.validate(self, value)
	if ( tonumber(value) < 60 and tonumber(value) > 0 ) then
	return value
	end
end

sync = s:taboption(this_tabb, ListValue, "prestart", translate("Restart the inbox checking process every"), translate("The process will restart at the selected time interval. This will eliminate the delay in checking your inbox."))
sync.default = "6"
sync:value("4", translate("4h"))
sync:value("6", translate("6h"))
sync:value("8", translate("8h"))
sync:value("12", translate("12h"))
sync.rmempty = true


leds = s:taboption(this_tabb, Value, "smsled", translate("Notification LED"), translate("Select the notification LED."))
if try_leds then
local node
local status
for node in try_leds do
local status = node
local all = string.sub (status, 17)
leds:value(all, all)
end
end

oled = s:taboption(this_tabb, ListValue, "ledtype", translate("The diode is dedicated only to these notifications"), translate("Select 'No' in case the router has only one LED or if the LED is multi-tasking."))
oled.default = "D"
oled:value("S", translate("No"))
oled:value("D", translate("Yes"))
oled.rmempty = true

local timeon = s:taboption(this_tabb, Value, "ledtimeon", translate("Turn on the LED for seconds(s)"), translate("Specify for how long the LED should be on."))
timeon.rmempty = false
timeon.maxlength = 3
timeon.default = 1

local timeoff = s:taboption(this_tabb, Value, "ledtimeoff", translate("Turn off the LED for seconds(s)"), translate("Specify for how long the LED should be off."))
timeoff.rmempty = false
timeoff.maxlength = 3
timeoff.default = 5

return m
