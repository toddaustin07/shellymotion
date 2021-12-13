--[[
  Copyright 2021 Todd Austin

  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
  except in compliance with the License. You may obtain a copy of the License at:

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software distributed under the
  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
  either express or implied. See the License for the specific language governing permissions
  and limitations under the License.


  DESCRIPTION
  
  Shelly Motion Driver

  Dependency:  Edge Bridge running on local LAN

--]]

-- Edge libraries
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local cosock = require "cosock"                                         -- for time only
local socket = require "cosock.socket"                                  -- for time only
local log = require "log"

local bridge = require "bridge"

-- Custom Capabiities
local capdefs = require "capabilitydefs"
local cap_createdev = capabilities.build_cap_from_json_string(capdefs.createdev_cap)
capabilities["partyvoice23922.createanother"] = cap_createdev

-- Module variables
local thisDriver = {}
local initialized = false
local lastinfochange = socket.gettime()
local motionreset = {}


local function resetmotion()

  local device_list = thisDriver:get_devices()
  
  for id, info in pairs(motionreset) do
    for _, device in ipairs(device_list) do
      if device.id == id then
        
        if (socket.gettime() - info.starttime) > tonumber(device.preferences.motionduration) then
          device:emit_event(capabilities.motionSensor.motion('inactive'))
          motionreset[id] = nil
        end

      end
    end
  end
  
end


local function trigger_motion(devaddr)

  local device_list = thisDriver:get_devices()

  for _, device in ipairs(device_list) do

    if device.preferences.deviceaddr ==  devaddr then
      device:emit_event(capabilities.motionSensor.motion('active'))
      if device.preferences.automotion == 'yesauto' then
          motionreset[device.id] = {}
          motionreset[device.id]['starttime'] = socket.gettime()
          thisDriver:call_with_delay(tonumber(device.preferences.motionduration), resetmotion)
      end
    end
  end
end


local function create_device(driver)

  local MFG_NAME = 'SmartThings Community'
  local MODEL = 'ShellyMotionWifi'
  local VEND_LABEL = 'Shelly Motion Sensor'
  local ID = 'ShellyMotion_' .. socket.gettime()
  local PROFILE = 'shellymotion.v1'

  log.info (string.format('Creating new device: label=<%s>, id=<%s>', VEND_LABEL, ID))

  local create_device_msg = {
                              type = "LAN",
                              device_network_id = ID,
                              label = VEND_LABEL,
                              profile = PROFILE,
                              manufacturer = MFG_NAME,
                              model = MODEL,
                              vendor_provided_label = VEND_LABEL,
                            }
                      
  assert (driver:try_create_device(create_device_msg), "failed to create device")

end

-- CAPABILITY HANDLERS

local function handle_createdev(driver, device, command)

  create_device(driver)

end

------------------------------------------------------------------------
--                REQUIRED EDGE DRIVER HANDLERS
------------------------------------------------------------------------

-- Lifecycle handler to initialize existing devices AND newly discovered devices
local function device_init(driver, device)
  
    log.debug(device.id .. ": " .. device.device_network_id .. "> INITIALIZING")
  
    -- Startup Server
    bridge.start_bridge_server(driver)
    
    -- Try to connect to bridge
    bridge.init_bridge(device, device.preferences.bridgeaddr, device.preferences.deviceaddr, trigger_motion)

    log.debug('Exiting device initialization')
end


-- Called when device was just created in SmartThings
local function device_added (driver, device)

  log.info(device.id .. ": " .. device.device_network_id .. "> ADDED")
  
  device:emit_event(capabilities.motionSensor.motion('inactive'))
  
  initialized = true
      
end


-- Called when SmartThings thinks the device needs provisioning
local function device_doconfigure (_, device)

  log.info ('Device doConfigure lifecycle invoked')

end


-- Called when device was deleted via mobile app
local function device_removed(driver, device)
  
  log.warn(device.id .. ": " .. device.device_network_id .. "> removed")
  
  local device_list = driver:get_devices()
  
  if #device_list == 0 then
    log.warn ('All devices removed; driver disabled')
  end
  
end


local function handler_driverchanged(driver, device, event, args)

  log.debug ('*** Driver changed handler invoked ***')

end


local function handler_infochanged (driver, device, event, args)

  log.debug ('Info changed handler invoked')

  local timenow = socket.gettime()
  local timesincelast = timenow - lastinfochange

  log.debug('Time since last info_changed:', timesincelast)
  
  lastinfochange = timenow
  
  if timesincelast > 1 then

  -- Did preferences change?
    if args.old_st_store.preferences then
    
      if args.old_st_store.preferences.bridgeaddr ~= device.preferences.bridgeaddr then
        log.info ('Bridge address changed to: ', device.preferences.bridgeaddr)
        bridge.init_bridge(device, device.preferences.bridgeaddr, device.preferences.deviceaddr, trigger_motion)
        
      elseif args.old_st_store.preferences.automotion ~= device.preferences.automotion then  
        log.info ('Auto motion revert changed to: ', device.preferences.automotion)
      
      elseif args.old_st_store.preferences.motionduration ~= device.preferences.motionduration then 
        log.info ('Motion active duration changed to: ', device.preferences.motionduration)
      
      elseif args.old_st_store.preferences.deviceaddr ~= device.preferences.deviceaddr then 
        log.info ('Device address changed to: ', device.preferences.deviceaddr)
      
      else
        -- Assume driver is restarting - shutdown everything
        log.debug ('****** DRIVER RESTART ASSUMED ******')
        
        bridge.shutdown(driver)
      end
          
    end
  else
    log.error ('Duplicate info_changed assumed - IGNORED')  
  end
  
end


-- Create Initial Device
local function discovery_handler(driver, _, should_continue)
  
  log.debug("Device discovery invoked")
  
  if not initialized then
    create_device(driver)
  end
  
  log.debug("Exiting discovery")
  
end


-----------------------------------------------------------------------
--        DRIVER MAINLINE: Build driver context table
-----------------------------------------------------------------------
thisDriver = Driver("thisDriver", {
  discovery = discovery_handler,
  lifecycle_handlers = {
    init = device_init,
    added = device_added,
    driverSwitched = handler_driverchanged,
    infoChanged = handler_infochanged,
    doConfigure = device_doconfigure,
    removed = device_removed
  },
  
  capability_handlers = {
    [cap_createdev.ID] = {
      [cap_createdev.commands.push.NAME] = handle_createdev,
    },
  }
})

log.info ('Shelly Motion Sensor Driver v1.0 Started')


thisDriver:run()
