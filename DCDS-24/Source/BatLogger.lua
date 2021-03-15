--[[
    --------------------------------------------------------------------
    Battery Logger & alarm management

    Based on RC-Thoughts RFID-Battery, many thanks to Tero!
    --------------------------------------------------------------------
    Released under MIT-license by Roman Dittrich (dittrich.r@gmail.com)
    
    Version 1.4, released 2021-03-15
    --------------------------------------------------------------------
--]]
collectgarbage()

------------------------------------------------------------------------
-- Locals
------------------------------------------------------------------------
local appVersion = "1.4"
local formFooter = "Battery Logger v." .. appVersion
local formFooter2 = "Code by Roman Dittrich, based on RFID-Battery"
local trans8

local modelName

local sensors = { labels = { "..." }, ids = { "..." }, params = { "..." } }

local batteries = { names = {}, cells = {}, caps = {}, cycles = {} }
local batIndex, menuBatIndex

local mahSensor, mahParam, mahID
local voltSensor, voltParam, voltID

local alarmCapacity, alarmCapacityVoice, alarmCapacityRpt, alarmCapacityRptIndex
local alarmInitVolt, alarmInitVoltVoice, alarmInitVoltRpt, alarmInitVoltRptIndex

local announceSwitch
local announceTime, announceRepeat = 0, 0
local percentage = "-"

local redAlert = false
local lowDisplay = false
local voltAlarmTSet = false
local voltAlarmTStore, voltAlarmTCurrent = 0, 0
local capVoicePlayed = false
local voltVoicePlayed = false

local shouldLog = false
local logTriggerTime = 0
local logCapacity = 0
local logHaveMah = false

local loopReset = false
local linkLostTSet = false
local linkLostTStore, linkLostTCurrent = 0, 0
local lastRxLink = 0
------------------------------------------------------------------------
-- Read translations
------------------------------------------------------------------------
local function setLanguage()
   local lng = system.getLocale()
   local file = io.readall("Apps/BatLogger/locale.jsn")
   local obj = json.decode(file)
   if (obj) then
      trans8 = obj[lng] or obj[obj.default]
   end
end

------------------------------------------------------------------------
-- Read available sensors for user to select
------------------------------------------------------------------------
local function readSensors()
   local snsrs = system.getSensors()
   for i,sensor in ipairs(snsrs) do
      if (sensor.label ~= "") then
         table.insert(sensors.labels, string.format("%s", sensor.label))
         table.insert(sensors.ids, string.format("%s", sensor.id))
         table.insert(sensors.params, string.format("%s", sensor.param))
      end
   end
end

------------------------------------------------------------------------
-- Prepare battery list for selectbox
------------------------------------------------------------------------
local function truncatedBatteryList()
   retval = {}
   retval[1] = trans8.unlistedBat
   
   for i, battery in ipairs(batteries.names) do
      if (battery ~= "") then
	 retval[i + 1] = battery
      end
   end

   return retval
end

------------------------------------------------------------------------
-- Reset the values used in loop() after changing the battery
------------------------------------------------------------------------
local function clearLoopValues()
   shouldLog = false
   logTriggerTime = 0
   logCapacity = 0
   logHaveMah = false
   redAlert = false
   lowDisplay = false
   voltAlarmTSet = false
   voltAlarmTStore = 0
   voltAlarmTCurrent = 0
   capVoicePlayed = false
   voltVoicePlayed = false
   lowVoltVoicePlayed = false
   announceTime = 0
   percentage = "-"
   loopReset = false
   linkLostTSet = false
   linkLostTStore = 0
   linkLostTCurrent = 0
end

------------------------------------------------------------------------
-- Render the telemetry
------------------------------------------------------------------------
local function printBattery()
   local text = { red = 0, green = 0, blue = 0 }
   local bg = { red = 0, green = 0, blue = 0 }
   bg.red, bg.green, bg.blue = lcd.getBgColor()
   
   -- set text color
   if (bg.red + bg.green + bg.blue)/3 <= 128 then
      text.red, text.green, text.blue = 255, 255, 255
   end

   lcd.setColor(text.red, text.green, text.blue)

   -- no battery selected
   if (batIndex < 1) then
      lcd.drawText((150 - lcd.getTextWidth(FONT_BOLD, trans8.noPack))/2, 3, trans8.noPack, FONT_BOLD)

      lcd.drawText((57 - lcd.getTextWidth(FONT_BIG, "-"))/2, 25, "-", FONT_BIG)
      lcd.drawText((57 - lcd.getTextWidth(FONT_MINI, trans8.telCycles))/2, 51, trans8.telCycles, FONT_MINI)

      lcd.drawText((210 - lcd.getTextWidth(FONT_BIG, "-"))/2, 25, "-", FONT_BIG)
      lcd.drawText((210 - lcd.getTextWidth(FONT_MINI, trans8.telCapacity))/2, 51, trans8.telCapacity, FONT_MINI)
   else   
      if (percentage == "-" or mahID == 0) then -- percentage not measured yet or no capacity sensor set
	 
	 
	 lcd.drawText((150 - lcd.getTextWidth(FONT_BOLD, batteries.names[batIndex]))/2, 3, batteries.names[batIndex], FONT_BOLD)
	 lcd.drawText((57 - lcd.getTextWidth(FONT_BIG, string.format("%.0f", batteries.cycles[batIndex])))/2, 25, string.format("%.0f", batteries.cycles[batIndex]), FONT_BIG)
	 lcd.drawText((57 - lcd.getTextWidth(FONT_MINI, trans8.telCycles))/2, 51, trans8.telCycles, FONT_MINI)

	 lcd.drawText((210 - lcd.getTextWidth(FONT_BIG, string.format("%.0f", batteries.caps[batIndex])))/2, 25, string.format("%.0f", batteries.caps[batIndex]), FONT_BIG)
	 lcd.drawText((210 - lcd.getTextWidth(FONT_MINI,trans8.telCapacity))/2,51,trans8.telCapacity,FONT_MINI)
      else
	 lcd.drawRectangle(5, 9, 26, 41)
	 lcd.drawFilledRectangle(12, 6, 12, 4)
	 local chgY = 50 - (percentage * 0.39)
	 local chgH = (percentage * 0.39) - 1

	 if (redAlert == true) then
	    lcd.setColor(240, 0, 0)
	 else
	    lcd.setColor(0, 196, 0)
	 end

	 lcd.drawFilledRectangle(6, chgY, 24, chgH)
	 lcd.setColor(text.red, text.blue, text.green)
	 lcd.drawText(43, 4, batteries.names[batIndex], FONT_MINI)

	 if (lowDisplay) then
	    lcd.drawText(125 - lcd.getTextWidth(FONT_MAXI, "LOW"), 12, "LOW", FONT_MAXI)
	 else
	    local dispVal = string.format("%.1f%%", percentage)
	    lcd.drawText(144 - lcd.getTextWidth(FONT_MAXI, dispVal), 14, dispVal, FONT_MAXI)
	 end

	 lcd.drawText(41, 52, string.format("%.0f %s", batteries.cycles[batIndex], trans8.telCycShort), FONT_MINI)
	 lcd.drawText(85, 52, string.format("%.0f %s", batteries.caps[batIndex], trans8.telCapShort), FONT_MINI)
	 local dispCells = string.format("%.0f%s", batteries.cells[batIndex], "S")
	 lcd.drawText((36 - lcd.getTextWidth(FONT_NORMAL, dispCells))/2, 49, dispCells, FONT_NORMAL)
      end
   end

   collectgarbage()
end

------------------------------------------------------------------------
-- sensors changes
------------------------------------------------------------------------
local function sensorChanged_mAh(value)
   mahSensor = value
   system.pSave("BTL_mAhSensor", value)

   mahID = string.format("%s", sensors.ids[mahSensor])
   mahParam = string.format("%s", sensors.params[mahSensor])

   if (mahID == "...") then
      mahID = 0
      mahParam = 0
   end

   system.pSave("BTL_mAhID", mahID)
   system.pSave("BTL_mAhParam", mahParam)
end

local function sensorChanged_volt(value)
   voltSensor = value
   system.pSave("BTL_voltSensor", value)

   voltID = string.format("%s", sensors.ids[voltSensor])
   voltParam = string.format("%s", sensors.params[voltSensor])

   if (voltID == "...") then
      voltID = 0
      voltParam = 0
   end

   system.pSave("BTL_voltID", voltID)
   system.pSave("BTL_voltParam", voltParam)
end

------------------------------------------------------------------------
-- alarm settings changes
------------------------------------------------------------------------
local function settingsChanged_capacityAlarm(value)
   alarmCapacity = value
   system.pSave("BTL_capAlarm", value)
--   alarmCapacityTr = string.format("%.1f", alarmCapacity)
--   system.pSave("BTL_capAlarmTr", alarmCapacityTr)
   system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
end

local function settingsChanged_capacityAlarmVoice(value)
   alarmCapacityVoice = value
   system.pSave("BTL_capAlarmVoice", value)
end

local function settingsChanged_capacityAlarmRepeat(value)
   alarmCapacityRpt = not value
   form.setValue(alarmCapacityRptIndex, alarmCapacityRpt)
   if (alarmCapacityRpt) then
      system.pSave("BTL_capAlarmRpt", 1)
   else
      system.pSave("BTL_capAlarmRpt", 0)
   end
end

local function settingsChanged_voltAlarm(value)
   alarmInitVolt = value
   system.pSave("BTL_initVoltAlarm", value)
   system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
end

local function settingsChanged_voltAlarmVoice(value)
   alarmInitVoltVoice = value
   system.pSave("BTL_initVoltAlarmVoice", value)
end

local function settingsChanged_voltAlarmRepeat(value)
   alarmInitVoltRpt = not value
   form.setValue(alarmInitVoltRptIndex, alarmInitVoltRpt)
   if (alarmInitVoltRpt) then
      system.pSave("BTL_initVoltAlarmRpt", 1)
   else
      system.pSave("BTL_initVoltAlarmRpt", 0)
   end
end

local function settingsChanged_lowVoltAlarm(value)
   alarmLowVolt = value
   system.pSave("BTL_lowVoltAlarm", value)
   system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
end

local function settingsChanged_lowVoltAlarmVoice(value)
   alarmLowVoltVoice = value
   system.pSave("BTL_lowVoltAlarmVoice", value)
end

local function settingsChanged_lowVoltAlarmRepeat(value)
   alarmLowVoltRpt = not value
   form.setValue(alarmLowVoltRptIndex, alarmLowVoltRpt)
   if (alarmLowVoltRpt) then
      system.pSave("BTL_lowVoltAlarmRpt", 1)
   else
      system.pSave("BTL_lowVoltAlarmRpt", 0)
   end
end

local function settingsChanged_announceSwitch(value)
   announceSwitch = value
   system.pSave("BTL_announceSwitch", value)
end

local function settingsChanged_announceTime(value)
   announceRepeat = value
   system.pSave("BTL_announceTime", value)
end

------------------------------------------------------------------------
-- battery settings changes
------------------------------------------------------------------------
local function settingsChanged_batName(i, value)
   batteries.names[i] = value:gsub("[^%w ]", "")
   system.pSave("BTL_batNames", batteries.names)
   system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
end

local function settingsChanged_bat1Name(value)
   settingsChanged_batName(1, value)
end

local function settingsChanged_bat2Name(value)
   settingsChanged_batName(2, value)
end

local function settingsChanged_bat3Name(value)
   settingsChanged_batName(3, value)
end

local function settingsChanged_bat4Name(value)
   settingsChanged_batName(4, value)
end

local function settingsChanged_bat5Name(value)
   settingsChanged_batName(5, value)
end

local function settingsChanged_bat6Name(value)
   settingsChanged_batName(6, value)
end

local function settingsChanged_bat7Name(value)
   settingsChanged_batName(7, value)
end

local function settingsChanged_bat8Name(value)
   settingsChanged_batName(8, value)
end

local function settingsChanged_bat9Name(value)
   settingsChanged_batName(9, value)
end

local function settingsChanged_bat10Name(value)
   settingsChanged_batName(10, value)
end

local function settingsChanged_bat11Name(value)
   settingsChanged_batName(11, value)
end

local function settingsChanged_bat12Name(value)
   settingsChanged_batName(12, value)
end

local function settingsChanged_bat13Name(value)
   settingsChanged_batName(13, value)
end

local function settingsChanged_bat14Name(value)
   settingsChanged_batName(14, value)
end

local function settingsChanged_bat15Name(value)
   settingsChanged_batName(15, value)
end

local function settingsChanged_batCells(i, value)
   batteries.cells[i] = value
   system.pSave("BTL_batCells", batteries.cells)
   system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
end

local function settingsChanged_bat1Cells(value)
   settingsChanged_batCells(1, value)
end

local function settingsChanged_bat2Cells(value)
   settingsChanged_batCells(2, value)
end

local function settingsChanged_bat3Cells(value)
   settingsChanged_batCells(3, value)
end

local function settingsChanged_bat4Cells(value)
   settingsChanged_batCells(4, value)
end

local function settingsChanged_bat5Cells(value)
   settingsChanged_batCells(5, value)
end

local function settingsChanged_bat6Cells(value)
   settingsChanged_batCells(6, value)
end

local function settingsChanged_bat7Cells(value)
   settingsChanged_batCells(7, value)
end

local function settingsChanged_bat8Cells(value)
   settingsChanged_batCells(8, value)
end

local function settingsChanged_bat9Cells(value)
   settingsChanged_batCells(9, value)
end

local function settingsChanged_bat10Cells(value)
   settingsChanged_batCells(10, value)
end

local function settingsChanged_bat11Cells(value)
   settingsChanged_batCells(11, value)
end

local function settingsChanged_bat12Cells(value)
   settingsChanged_batCells(12, value)
end

local function settingsChanged_bat13Cells(value)
   settingsChanged_batCells(13, value)
end

local function settingsChanged_bat14Cells(value)
   settingsChanged_batCells(14, value)
end

local function settingsChanged_bat15Cells(value)
   settingsChanged_batCells(15, value)
end


local function settingsChanged_batCap(i, value)
   batteries.caps[i] = value
   system.pSave("BTL_batCaps", batteries.caps)
   system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
end

local function settingsChanged_bat1Cap(value)
   settingsChanged_batCap(1, value)
end
   
local function settingsChanged_bat2Cap(value)
   settingsChanged_batCap(2, value)
end

local function settingsChanged_bat3Cap(value)
   settingsChanged_batCap(3, value)
end

local function settingsChanged_bat4Cap(value)
   settingsChanged_batCap(4, value)
end

local function settingsChanged_bat5Cap(value)
   settingsChanged_batCap(5, value)
end

local function settingsChanged_bat6Cap(value)
   settingsChanged_batCap(6, value)
end

local function settingsChanged_bat7Cap(value)
   settingsChanged_batCap(7, value)
end

local function settingsChanged_bat8Cap(value)
   settingsChanged_batCap(8, value)
end

local function settingsChanged_bat9Cap(value)
   settingsChanged_batCap(9, value)
end

local function settingsChanged_bat10Cap(value)
   settingsChanged_batCap(10, value)
end

local function settingsChanged_bat11Cap(value)
   settingsChanged_batCap(11, value)
end

local function settingsChanged_bat12Cap(value)
   settingsChanged_batCap(12, value)
end

local function settingsChanged_bat13Cap(value)
   settingsChanged_batCap(13, value)
end

local function settingsChanged_bat14Cap(value)
   settingsChanged_batCap(14, value)
end

local function settingsChanged_bat15Cap(value)
   settingsChanged_batCap(15, value)
end

local function settingsChanged_batCycles(i, value)
   batteries.cycles[i] = value
   system.pSave("BTL_batCycles", batteries.cycles)
   system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
end

local function settingsChanged_bat1Cycles(value)
   settingsChanged_batCycles(1, value)
end

local function settingsChanged_bat2Cycles(value)
   settingsChanged_batCycles(2, value)
end

local function settingsChanged_bat3Cycles(value)
   settingsChanged_batCycles(3, value)
end

local function settingsChanged_bat4Cycles(value)
   settingsChanged_batCycles(4, value)
end

local function settingsChanged_bat5Cycles(value)
   settingsChanged_batCycles(5, value)
end

local function settingsChanged_bat6Cycles(value)
   settingsChanged_batCycles(6, value)
end

local function settingsChanged_bat7Cycles(value)
   settingsChanged_batCycles(7, value)
end

local function settingsChanged_bat8Cycles(value)
   settingsChanged_batCycles(8, value)
end

local function settingsChanged_bat9Cycles(value)
   settingsChanged_batCycles(9, value)
end

local function settingsChanged_bat10Cycles(value)
   settingsChanged_batCycles(10, value)
end

local function settingsChanged_bat11Cycles(value)
   settingsChanged_batCycles(11, value)
end

local function settingsChanged_bat12Cycles(value)
   settingsChanged_batCycles(12, value)
end

local function settingsChanged_bat13Cycles(value)
   settingsChanged_batCycles(13, value)
end

local function settingsChanged_bat14Cycles(value)
   settingsChanged_batCycles(14, value)
end

local function settingsChanged_bat15Cycles(value)
   settingsChanged_batCycles(15, value)
end

------------------------------------------------------------------------
-- Battery selection change
------------------------------------------------------------------------
local function selectionBatteryChanged(value)
   menuBatIndex = value
   
   if (value == 1) then
      batIndex = -1
   else
      batIndex = value - 1
   end
   
   form.reinit()
   clearLoopValues()
   if (batIndex > 0) then
      system.messageBox(trans8.battSelected .. batteries.names[batIndex])
   end
end

------------------------------------------------------------------------
-- write csv file with the log - TODO: rewrite this
------------------------------------------------------------------------
local function writeLog()
   local logFile = "Apps/BatLogger/log.csv"
   local dt = system.getDateTime()
   local logTime = string.format("%d%02d%02dT%02d%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min)
   local logCap = string.format("%.0f", logCapacity)
   local batCap = string.format("%.0f", batteries.caps[batIndex])
   local batCyc = batteries.cycles[batIndex] + 1
   local batName = batteries.names[batIndex]:gsub("[^%w ]", "")
   settingsChanged_batCycles(batIndex, batCyc)

   local logLine = string.format("%s,%s,%s,%s,%s,%s,,,", logTime, modelName, batName, batCap, logCap, batCyc)

   local writeLog = io.open(logFile, "a")
   if (writeLog) then
      io.write(writeLog, logLine, "\n")
      io.close(writeLog)
   end

   system.messageBox(trans8.logWrite, 5)
   collectgarbage()
end

------------------------------------------------------------------------
-- UI - Settings form
------------------------------------------------------------------------
local function initSettingsForm(subform)
   if (subform == 1) then
      form.setButton(1, ":tools", HIGHLIGHTED)
      form.setButton(2, "1-5", ENABLED)
      form.setButton(3, "6-10", ENABLED)
      form.setButton(4, "11-15", ENABLED)

      form.addRow(1)
      form.addLabel({ label = trans8.labelModel, font = FONT_BIG })
      
      form.addRow(1)
      form.addLabel({ label = trans8.labelCommon, font = FONT_BOLD })

      form.addRow(2)
      form.addLabel({ label = trans8.modName })
      form.addLabel({ label = system.getProperty("Model"), alignRight = true })

      --sensor settings - model related
      form.addRow(2)
      form.addLabel({ label = trans8.sensorMah })
      form.addSelectbox(sensors.labels, mahSensor, true, sensorChanged_mAh)

      form.addRow(2)
      form.addLabel({ label = trans8.sensorVolt })
      form.addSelectbox(sensors.labels, voltSensor, true, sensorChanged_volt)

      --capacity alarm settings
      form.addRow(1)
      form.addLabel({ label = trans8.labelAlarm, font = FONT_BOLD })

      form.addRow(2)
      form.addLabel({ label = trans8.AlmVal })
      form.addIntbox(alarmCapacity, 0, 100, 0, 0, 1, settingsChanged_capacityAlarm)

      form.addRow(2)
      form.addLabel({ label = trans8.selAudio })
      form.addAudioFilebox(alarmCapacityVoice, settingsChanged_capacityAlarmVoice)
      
      form.addRow(2)
      form.addLabel({ label = trans8.rptAlm, width = 275 })
      alarmCapacityRptIndex = form.addCheckbox(alarmCapacityRpt, settingsChanged_capacityAlarmRepeat)

      --empty battery alarm settings
      form.addRow(1)
      form.addLabel({ label = trans8.labelAlarmEmpty, font = FONT_BOLD })

      form.addRow(2)
      form.addLabel({ label = trans8.AlmValVolt, width = 200 })
      form.addIntbox(alarmInitVolt, 0, 450, 0, 2, 1, settingsChanged_voltAlarm)

      form.addRow(2)
      form.addLabel({ label = trans8.selAudio })
      form.addAudioFilebox(alarmInitVoltVoice, settingsChanged_voltAlarmVoice)

      form.addRow(2)
      form.addLabel({ label = trans8.rptAlm, width = 275 })
      alarmInitVoltRptIndex = form.addCheckbox(alarmInitVoltRpt, settingsChanged_voltAlarmRepeat)
      
      --announce settings
      form.addRow(1)
      form.addLabel({ label = trans8.labelAnnounce, font = FONT_BOLD })
      
      form.addRow(2)
      form.addLabel({ label = trans8.annSw, width = 220 })
      form.addInputbox(announceSwitch, true, settingsChanged_announceSwitch)

      form.addRow(2)
      form.addLabel({ label = trans8.annRpt, width = 220 })
      form.addIntbox(announceRepeat, 0, 60, 0, 0, 1, settingsChanged_announceTime)
      
      form.addRow(1)
      form.addLabel({ label = formFooter, font = FONT_MINI, alignRight = true })
      form.addRow(1)
      form.addLabel({ label = formFooter2, font = FONT_MINI, alignRight = true })
      
      form.setFocusedRow(1)
      formID = 1
   end
      
   if (subform == 2) then
      form.setButton(1, ":tools", ENABLED)
      form.setButton(2, "1-5", HIGHLIGHTED)
      form.setButton(3, "6-10", ENABLED)
      form.setButton(4, "11-15", ENABLED)

      form.addRow(1)
      form.addLabel({ label = trans8.labelBatt .. " - " .. modelName, font = FONT_BIG })

      -- Battery #1
      form.addRow(2)
      form.addLabel({ label = string.format("%s 1", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[1], 32, settingsChanged_bat1Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[1], 0, 20, 0, 0, 1, settingsChanged_bat1Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[1], 0, 10000, 0, 0, 50, settingsChanged_bat1Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[1], 0, 1000, 0, 0, 1, settingsChanged_bat1Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      -- Battery #2
      form.addRow(2)
      form.addLabel({ label = string.format("%s 2", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[2], 32, settingsChanged_bat2Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[2], 0, 20, 0, 0, 1, settingsChanged_bat2Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[2], 0, 10000, 0, 0, 50, settingsChanged_bat2Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[2], 0, 1000, 0, 0, 1, settingsChanged_bat2Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      -- Battery #3
      form.addRow(2)
      form.addLabel({ label = string.format("%s 3", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[3], 32, settingsChanged_bat3Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[3], 0, 20, 0, 0, 1, settingsChanged_bat3Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[3], 0, 10000, 0, 0, 50, settingsChanged_bat3Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[3], 0, 1000, 0, 0, 1, settingsChanged_bat3Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      -- Battery #4
      form.addRow(2)
      form.addLabel({ label = string.format("%s 4", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[4], 32, settingsChanged_bat4Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[4], 0, 20, 0, 0, 1, settingsChanged_bat4Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[4], 0, 10000, 0, 0, 50, settingsChanged_bat4Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[4], 0, 1000, 0, 0, 1, settingsChanged_bat4Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      -- Battery #5
      form.addRow(2)
      form.addLabel({ label = string.format("%s 5", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[5], 32, settingsChanged_bat5Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[5], 0, 20, 0, 0, 1, settingsChanged_bat5Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[5], 0, 10000, 0, 0, 50, settingsChanged_bat5Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[5], 0, 1000, 0, 0, 1, settingsChanged_bat5Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      form.addRow(1)
      form.addLabel({ label = formFooter, font = FONT_MINI, alignRight = true })
      form.addRow(1)
      form.addLabel({ label = formFooter2, font = FONT_MINI, alignRight = true })

      form.setFocusedRow(1)
      formID = 2
   end

   if (subform == 3) then
      form.setButton(1, ":tools", ENABLED)
      form.setButton(2, "1-5", ENABLED)
      form.setButton(3, "6-10", HIGHLIGHTED)
      form.setButton(4, "11-15", ENABLED)

      form.addRow(1)
      form.addLabel({ label = trans8.labelBatt .. " - " .. modelName, font = FONT_BIG })

      -- Battery #6
      form.addRow(2)
      form.addLabel({ label = string.format("%s 6", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[6], 32, settingsChanged_bat5Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[6], 0, 20, 0, 0, 1, settingsChanged_bat6Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[6], 0, 10000, 0, 0, 50, settingsChanged_bat6Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[6], 0, 1000, 0, 0, 1, settingsChanged_bat6Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      -- Battery #7
      form.addRow(2)
      form.addLabel({ label = string.format("%s 7", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[7], 32, settingsChanged_bat7Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[7], 0, 20, 0, 0, 1, settingsChanged_bat7Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[7], 0, 10000, 0, 0, 50, settingsChanged_bat7Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[7], 0, 1000, 0, 0, 1, settingsChanged_bat7Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      -- Battery #8
      form.addRow(2)
      form.addLabel({ label = string.format("%s 8", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[8], 32, settingsChanged_bat8Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[8], 0, 20, 0, 0, 1, settingsChanged_bat8Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[8], 0, 10000, 0, 0, 50, settingsChanged_bat8Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[8], 0, 1000, 0, 0, 1, settingsChanged_bat8Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      -- Battery #9
      form.addRow(2)
      form.addLabel({ label = string.format("%s 9", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[9], 32, settingsChanged_bat9Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[9], 0, 20, 0, 0, 1, settingsChanged_bat9Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[9], 0, 10000, 0, 0, 50, settingsChanged_bat9Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[9], 0, 1000, 0, 0, 1, settingsChanged_bat9Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      -- Battery #10
      form.addRow(2)
      form.addLabel({ label = string.format("%s 10", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[10], 32, settingsChanged_bat10Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[10], 0, 20, 0, 0, 1, settingsChanged_bat10Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[10], 0, 10000, 0, 0, 50, settingsChanged_bat10Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[10], 0, 1000, 0, 0, 1, settingsChanged_bat10Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      form.addRow(1)
      form.addLabel({ label = formFooter, font = FONT_MINI, alignRight = true })
      form.addRow(1)
      form.addLabel({ label = formFooter2, font = FONT_MINI, alignRight = true })

      form.setFocusedRow(1)
      formID = 3
   end

   if (subform == 4) then
      form.setButton(1,":tools",ENABLED)
      form.setButton(2,"1-5",ENABLED)
      form.setButton(3,"6-10",ENABLED)
      form.setButton(4,"11-15",HIGHLIGHTED)

      form.addRow(1)
      form.addLabel({ label = trans8.labelBatt .. " - " .. modelName, font = FONT_BIG })

      -- Battery #11
      form.addRow(2)
      form.addLabel({ label = string.format("%s 11", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[11], 32, settingsChanged_bat11Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[11], 0, 20, 0, 0, 1, settingsChanged_bat11Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[11], 0, 10000, 0, 0, 50, settingsChanged_bat11Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[11], 0, 1000, 0, 0, 1, settingsChanged_bat11Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      -- Battery #12
      form.addRow(2)
      form.addLabel({ label = string.format("%s 12", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[12], 32, settingsChanged_bat12Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[12], 0, 20, 0, 0, 1, settingsChanged_bat12Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[12], 0, 10000, 0, 0, 50, settingsChanged_bat12Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[12], 0, 1000, 0, 0, 1, settingsChanged_bat12Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      -- Battery #13
      form.addRow(2)
      form.addLabel({ label = string.format("%s 13", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[13], 32, settingsChanged_bat13Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[13], 0, 20, 0, 0, 1, settingsChanged_bat13Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[13], 0, 10000, 0, 0, 50, settingsChanged_bat13Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[13], 0, 1000, 0, 0, 1, settingsChanged_bat13Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      -- Battery #14
      form.addRow(2)
      form.addLabel({ label = string.format("%s 14", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[14], 32, settingsChanged_bat14Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[14], 0, 20, 0, 0, 1, settingsChanged_bat14Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[14], 0, 10000, 0, 0, 50, settingsChanged_bat14Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[14], 0, 1000, 0, 0, 1, settingsChanged_bat14Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      -- Battery #15
      form.addRow(2)
      form.addLabel({ label = string.format("%s 15", trans8.battName), width = 140 })
      form.addTextbox(batteries.names[15], 32, settingsChanged_bat15Name, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.battCellNum, width = 140 })
      form.addIntbox(batteries.cells[15], 0, 20, 0, 0, 1, settingsChanged_bat15Cells, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCapacity, width = 140 })
      form.addIntbox(batteries.caps[15], 0, 10000, 0, 0, 50, settingsChanged_bat15Cap, { width = 167 })

      form.addRow(2)
      form.addLabel({ label = trans8.telCycles, width = 140 })
      form.addIntbox(batteries.cycles[15], 0, 1000, 0, 0, 1, settingsChanged_bat15Cycles, { width = 167 })

      form.addRow(1)
      form.addLabel({ label = trans8.spacer, font = FONT_MINI })

      form.addRow(1)
      form.addLabel({ label = formFooter, font = FONT_MINI, alignRight = true })
      form.addRow(1)
      form.addLabel({ label = formFooter2, font = FONT_MINI, alignRight = true })

      form.setFocusedRow(1)
      formID = 4
   end

   collectgarbage()
end

-- re-init correct form when nav button is pressed
local function settingsKeyPressed(key)
   if (key == KEY_1) then
      form.reinit(1)
   end

   if (key == KEY_2) then
      form.reinit(2)
   end

   if (key == KEY_3) then
      form.reinit(3)
   end

   if (key == KEY_4) then
      form.reinit(4)
   end
end

------------------------------------------------------------------------
-- UI - battery select form
------------------------------------------------------------------------
local function initBatteryForm()
   form.setButton(1, ":tools", HIGHLIGHTED)
   form.setButton(2, "", DISABLED)

   if (batIndex > 0) then
      form.setButton(3, ":delete", ENABLED)
   else
      form.setButton(3, ":delete", DISABLED)
   end
   
   form.setButton(4, "", DISABLED)

   form.addRow(1)
   form.addLabel({ label = modelName, font = FONT_BIG })

   form.addRow(2)
   form.addLabel({ label = trans8.battSelect })
   form.addSelectbox(truncatedBatteryList(), menuBatIndex, true, selectionBatteryChanged)

   form.addRow(1)
   form.addLabel({ label = formFooter, font = FONT_MINI, alignRight = true })
   form.addRow(1)
   form.addLabel({ label = formFooter2, font = FONT_MINI, alignRight = true })

   form.setFocusedRow(2)
end

local function batteryKeyPressed(key)
   if (key == KEY_3) then
      batIndex = 0
      menuBatIndex = 0
      form.reinit()
      clearLoopValues()
      system.messageBox(trans8.battUnselect)
   end
end

------------------------------------------------------------------------
-- Loop
------------------------------------------------------------------------
local function loop()
   local txTelemetry = system.getTxTelemetry()
   local rxLink = txTelemetry["rx1Percent"] + txTelemetry["rx2Percent"] + txTelemetry["rxBPercent"]
   
   if (rxLink > 0) then -- model on & connected
      if (batIndex == 0) then
	 system.registerForm(2, 0, trans8.battSelName, initBatteryForm, batteryKeyPressed)
      elseif (batIndex > 0) then
         local currentTime = system.getTime()
         local announceGo = (system.getInputsVal(announceSwitch) == 1)

         linkLostTSet = false
         linkLostTStore = 0

         if (logTriggerTime == 0) then
            logTriggerTime = currentTime + 30
         end

         if (logTriggerTime > 0 and logTriggerTime < currentTime) then
            shouldLog = true
         else
            shouldLog = false
         end

         -- get capacity, calculate percentage && check voice alert config
         if (mahSensor > 1) then
            local mahCapa = system.getSensorByID(mahID, mahParam)

            if (mahCapa and mahCapa.valid) then
               mahCapa = mahCapa.value
               logCapacity = mahCapa
               logHaveMah = true

               local currentPercentage = ((batteries.caps[batIndex] - mahCapa) * 100) / batteries.caps[batIndex]

               if (currentPercentage < 0) then
                  currentPercentage = 0
               elseif (currentPercentage > 100) then
                  currentPercentage = 100
               end

               if (lowDisplay) then
                  currentPercentage = 100
               end

               percentage = string.format("%.1f", currentPercentage)

               if (currentPercentage <= alarmCapacity) then
                  redAlert = true
                  if (not capVoicePlayed and alarmCapacityVoice ~= "...") then
                     if (alarmCapacityRpt) then
                        system.playFile(alarmCapacityVoice, AUDIO_QUEUE)
                        system.playFile(alarmCapacityVoice, AUDIO_QUEUE)
                        system.playFile(alarmCapacityVoice, AUDIO_QUEUE)
                     else
                        system.playFile(alarmCapacityVoice, AUDIO_QUEUE)
                     end

                     capVoicePlayed = true
                  end
               else
                  capVoicePlayed = false
               end
            elseif (not lowDisplay) then
               percentage = "-"
               capVoicePlayed = false
               redAlert = false
            end
         end

         -- voltage alarms
         if (voltSensor > 1) then
            local voltValue = system.getSensorByID(voltID, voltParam)

            if (voltValue and voltValue.valid) then
               voltValue = voltValue.value

               if (voltAlarmTStore >= voltAlarmTCurrent) then
                  if (voltAlarmTSet == false) then
                     voltAlarmTCurrent = currentTime
                     voltAlarmTStore = currentTime + 10
                     voltAlarmTSet = true
                  else
                     voltAlarmTCurrent = system.getTime()
                  end

                  if (alarmInitVolt == 0) then
                     voltVoicePlayed = false
                     voltAlarmTStore = 0
                  else
                     local alarmVoltValue = alarmInitVolt / 100
                     local voltLimit = batteries.cells[batIndex] * alarmVoltValue

                     if (voltValue > 0 and voltValue <= voltLimit) then
                        redAlert = true
                        shouldLog = false
                        lowDisplay = true

                        if (voltAlarmTStore >= voltAlarmTCurrent and voltAlarmTSet == true) then
                           if (not voltVoicePlayed and alarmVoltVoice ~= "...") then
                              if (alarmVoltRpt) then
                                 system.playFile(alarmInitVoltVoice, AUDIO_QUEUE)
                                 system.playFile(alarmInitVoltVoice, AUDIO_QUEUE)
                                 system.playFile(alarmInitVoltVoice, AUDIO_QUEUE)
                              else
                                 system.playFile(alarmInitVoltVoice, AUDIO_QUEUE)
                              end

                              voltVoicePlayed = true
                              system.messageBox(trans8.lowFlightpack, 10)
                           end
                        end
                     else
                        voltVoicePlayed = false
                        lowDisplay = false
                     end
                  end
               end
            end
         end

         -- Percentage announce	 
         if (announceGo) then
            local percVal = -1

            if (percentage and percentage ~= "-") then
               percVal = tonumber(percentage)
            end

            if (percVal >= 0 and percVal <= 100 and announceTime <= currentTime) then
               system.playNumber(percVal, 0, "%", trans8.annCap)
               announceTime = currentTime + announceRepeat
            end
         end
      end
   elseif (rxLink == 0) then -- model disconnected
      if (batIndex > 0) then
         linkLostTCurrent = system.getTime()

         if (lastRxLink > rxLink and not linkLostTSet) then
            linkLostTStore = linkLostTCurrent + 5
            linkLostTSet = true
         end

         if (linkLostTSet and linkLostTStore > 0 and linkLostTStore < linkLostTCurrent) then
            if (logHaveMah and shouldLog) then 
               if (batteries.caps[batIndex] == 0 or logCapacity == 0) then
                  shouldLog = false
               else
                  writeLog()
               end
            end

            loopReset = true
            linkLostTStore = 0
         end

         if (loopReset) then
            batIndex = 0
	    menuBatIndex = 0
            clearLoopValues()
         end
      end
   end

   lastRxLink = rxLink
   collectgarbage()
end

------------------------------------------------------------------------
-- init
------------------------------------------------------------------------
local function init(code)
   modelName = system.getProperty("Model")
   batIndex = 0
   menuBatIndex = 0
   
   readSensors()
   
   mahID = system.pLoad("BTL_mAhID", 0)
   mahParam = system.pLoad("BTL_mAhParam", 0)
   mahSensor = system.pLoad("BTL_mAhSensor", 0)

   voltID = system.pLoad("BTL_voltID", 0)
   voltParam = system.pLoad("BTL_voltParam", 0)
   voltSensor = system.pLoad("BTL_voltSensor", 0)

   alarmCapacity = system.pLoad("BTL_capAlarm", 0)
   alarmCapacityVoice = system.pLoad("BTL_capAlarmVoice", "...")
   local alCapRpt = system.pLoad("BTL_capAlarmRpt", 0)
   alarmCapacityRpt = (alCapRpt == 1)

   alarmInitVolt = system.pLoad("BTL_initVoltAlarm", 0)
   alarmInitVoltVoice = system.pLoad("BTL_initVoltAlarmVoice", "...")
   local alVoltRpt = system.pLoad("BTL_initVoltAlarmRpt", 0)
   alarmInitVoltRpt = (alVoltRpt == 1)

   announceSwitch = system.pLoad("BTL_announceSwitch")
   announceRepeat = system.pLoad("BTL_announceTime", 0)

   batteries.names = system.pLoad("BTL_batNames", { "", "", "", "", "", "", "", "", "", "", "", "", "", "", "" })
   batteries.cells = system.pLoad("BTL_batCells", { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 })
   batteries.caps = system.pLoad("BTL_batCaps", { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 })
   batteries.cycles = system.pLoad("BTL_batCycles", { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 })
   
   system.registerForm(1, MENU_APPS, trans8.appName, initSettingsForm, settingsKeyPressed)
   system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
   collectgarbage()
end

setLanguage()
collectgarbage()
return { init = init, loop = loop, author = "Roman Dittrich", version = appVersion, name = trans8.appName }
