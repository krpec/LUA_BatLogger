--[[
    --------------------------------------------------------------------
    LiPo Logger & battery management

    Heavily based on RC-Thoughts RFID-Battery, many thanks to Tero!
    --------------------------------------------------------------------
    Released under MIT-license by Roman Dittrich (dittrich.r@gmail.com)
    
    Version 0.1, released 2021-03-01
    --------------------------------------------------------------------
--]]
collectgarbage()

------------------------------------------------------------------------
-- Locals
------------------------------------------------------------------------
local appVersion = "0.1"
local formFooter = "LiPo Logger v." .. appVersion .. ", based on RFID-Battery "
local trans8

local modelName

local sensorLaList = {"..."}
local sensorIdList = {"..."}
local sensorPaList = {"..."}

local batteries = { names = {}, cells = {}, caps = {}, cycles = {} }

local mahSensor, mahParam, mahID
local voltSensor, voltParam, voltID

local alarmCapacity, alarmCapacityTr, alarmCapacityVoice, alarmCapacityRpt, alarmCapacityRptIndex
local alarmVolt, alarmVoltVoice, alarmVoltRpt, alarmVoltRptIndex

local announceSwitch

------------------------------------------------------------------------
-- Read translations
------------------------------------------------------------------------
local function setLanguage()
   local lng = system.getLocale()
   local file = io.readall("Apps/Lang/LiPoLogger.jsn")
   local obj = json.decode(file)
   if (obj) then
      trans8 = obj[lng] or obj[obj.default]
   end
end

------------------------------------------------------------------------
-- Read available sensors for user to select
------------------------------------------------------------------------
local function readSensors()
   local sensors = system.getSensors()
   for i,sensor in ipairs(sensors) do
      if (sensor.label ~= "") then
	 table.insert(sensorLaList, string.format("%s", sensor.label))
	 table.insert(sensorIdList, string.format("%s", sensor.id))
	 table.insert(sensorPaList, string.format("%s", sensor.param))
      end
   end
end

------------------------------------------------------------------------
-- write csv file with the log
------------------------------------------------------------------------
local function writeLog()
   local noBattLog = 0
   local logFile = "/Log/LiPoLogger.csv"
   local dt = system.getDateTime()
   local dtStampLog = string.format("%d%02d%02dT%02d%02d", dt.year, dt.mon, dt.day, dt.hour, dt.min)
   local mahCapaLog = string.format("%.0f", mahCapaLog)
   local battDspCapa = string.format("%.0f", battDspCapa)
   local battDspCount = string.format("%.0f", battDspCount)
   local logLine = string.format("%s,%s,%s,%s,%s,%s,,,", dtStampLog, modName, battLog, battDspCapa, mahCapaLog, battDspCount)
   local writeLog = io.open(logFile, "a")

   if (writeLog) then
      io.write(writeLog, logLine, "\n")
      io.close(writeLog)
   end

   system.messageBox(trans8.logWrite, 5)
end

------------------------------------------------------------------------
-- sensors changes
------------------------------------------------------------------------
local function sensorChanged_mAh(value)
   mahSensor = value
   system.pSave("LPL_mAhSensor", value)

   mahID = string.format("%s", sensorIdList[mahSensor])
   mahParam = string.format("%s", sensorPaList[mahSensor])

   if (mahID == "...") then
      mahID = 0
      mahParam = 0
   end

   system.pSave("LPL_mAhID", mahID)
   system.pSave("LPL_mAhParam", mahParam)
end

local function sensorChanged_volt(value)
   voltSensor = value
   system.pSave("LPL_voltSensor", value)

   voltID = string.format("%s", sensorIdList[voltSensor])
   voltParam = string.format("%s", sensorPaList[voltSensor])

   if (voltID == "...") then
      voltID = 0
      voltParam = 0
   end

   system.pSave("LPL_voltID", voltID)
   system.pSave("LPL_voltParam", voltParam)
end

------------------------------------------------------------------------
-- alarm settings changes
------------------------------------------------------------------------
local function settingsChanged_capacityAlarm(value)
   alarmCapacity = value
   system.pSave("LPL_capAlarm", value)
   alarmCapacityTr = string.format("%.1f", alarmCapacity)
   system.pSave("LPL_capAlarmTr", alarmCapacityTr)
--   system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
end

local function settingsChanged_capacityAlarmVoice(value)
   alarmCapacityVoice = value
   system.pSave("LPL_capAlarmVoice", value)
end

local function settingsChanged_capacityAlarmRepeat(value)
   alarmCapacityRpt = not value
   form.setValue(alarmCapacityRptIndex, alarmCapacityRpt)
   if (alarmCapacityRpt) then
      system.pSave("LPL_capAlarmRpt", 1)
   else
      system.pSave("LPL_capAlarmRpt", 0)
   end
end

local function settingsChanged_voltAlarm(value)
   alarmVolt = value
   system.pSave("LPL_voltAlarm", value)
--   system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
end

local function settingsChanged_voltAlarmVoice(value)
   alarmVoltVoice = value
   system.pSave("LPL_voltAlarmVoice", value)
end

local function settingsChanged_voltAlarmRepeat(value)
   alarmVoltRpt = not value
   form.setValue(alarmVoltRptIndex, alarmVoltRpt)
   if (alarmVoltRpt) then
      system.pSave("LPL_voltAlarmRpt", 1)
   else
      system.pSave("LPL_voltAlarmRpt", 0)
   end
end

local function settingsChanged_announceSwitch(value)
   announceSwitch = value
   system.pSave("LPL_announceSwitch", value)
end

------------------------------------------------------------------------
-- battery settings changes
------------------------------------------------------------------------
local function settingsChanged_batName(i, value)
   batteries.names[i] = value:gsub("[^%w ]", "")
   system.pSave("LPL_batNames", batteries.names)
   -- system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
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
   system.pSave("LPL_batCells", batteries.cells)
   -- system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
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

------------------------------------------------------------------------
-- UI - forms
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
      form.addSelectbox(sensorLaList, mahSensor, true, sensorChanged_mAh)

      form.addRow(2)
      form.addLabel({ label = trans8.sensorVolt })
      form.addSelectbox(sensorLaList, voltSensor, true, sensorChanged_volt)

      --alarm settings
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

      form.addRow(1)
      form.addLabel({ label = trans8.labelAlarmVolt, font = FONT_BOLD })

      form.addRow(2)
      form.addLabel({ label = trans8.AlmValVolt, width = 200 })
      form.addIntbox(alarmVolt, 0, 450, 0, 2, 1, settingsChanged_voltAlarm)

      form.addRow(2)
      form.addLabel({ label = trans8.selAudio })
      form.addAudioFilebox(alarmVoltVoice, settingsChanged_voltAlarmVoice)

      form.addRow(2)
      form.addLabel({ label = trans8.rptAlm, width = 275 })
      alarmVoltRptIndex = form.addCheckbox(alarmVoltRpt, settingsChanged_voltAlarmRepeat)

      form.addRow(2)
      form.addLabel({ label = trans8.annSw, width = 220 })
      form.addInputbox(announceSwitch, true, settingsChanged_announceSwitch)

      form.addRow(1)
      form.addLabel({ label = formFooter, font = FONT_MINI, alignRight = true })
      
      form.setFocusedRow(1)
   else
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

	 form.setFocusedRow(1)
      else
	 if (subform == 3) then
	    	 form.setButton(1, ":tools", ENABLED)
		 form.setButton(2, "1-5", ENABLED)
		 form.setButton(3, "6-10", HIGHLIGHTED)
		 form.setButton(4, "11-15", ENABLED)
	 
	 form.addRow(1)
	 form.addLabel({ label = trans8.labelBatt .. " - " .. modelName, font = FONT_BIG })

	 -- Battery #6
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

	 -- Battery #7
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

	 -- Battery #8
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

	 -- Battery #9
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

	 -- Battery #10
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

	 form.setFocusedRow(1)
	 end
      end
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

   if (key == 4) then
      form.reinit(4)
   end
end

-- Loop
local function loop()

end

-- init
local function init()
   modelName = system.getProperty("Model")
   
   readSensors()
   
   mahID = system.pLoad("LPL_mAhID", 0)
   mahParam = system.pLoad("LPL_mAhParam", 0)
   mahSensor = system.pLoad("LPL_mAhSensor", 0)

   voltID = system.pLoad("LPL_voltID", 0)
   voltParam = system.pLoad("LPL_voltParam", 0)
   voltSensor = system.pLoad("LPL_voltSensor", 0)

   alarmCapacity = system.pLoad("LPL_capAlarm", 0)
   alarmCapacityTr = system.pLoad("LPL_capAlarmTr", 1)
   alarmCapacityVoice = system.pLoad("LPL_capAlarmVoice", "...")
   local alCapRpt = system.pLoad("LPL_capAlarmRpt", 0)
   alarmCapacityRpt = (alCapRpt == 1)

   alarmVolt = system.pLoad("LPL_voltAlarm", 0)
   alarmVoltVoice = system.pLoad("LPL_voltAlarmVoice", "...")
   local alVoltRpt = system.pLoad("LPL_voltAlarmRpt", 0)
   alarmVoltRpt = (alVoltRpt == 1)

   announceSwitch = system.pLoad("LPL_announceSwitch")

   batteries.names = system.pLoad("LPL_batNames", { "", "", "", "", "", "", "", "", "", "", "", "", "", "", "" })
   batteries.cells = system.pLoad("LPL_batCells", { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 })
   batteries.caps = system.pLoad("LPL_batCaps", { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 })
   batteries.cycles = system.pLoad("LPL_batCycles", { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 })
   
   system.registerForm(1, MENU_APPS, trans8.appName, initSettingsForm, settingsKeyPressed)
   --   system.registerTelemetry(1, trans8.telLabel, 2, printBattery)
   collectgarbage()
end

setLanguage()
collectgarbage()
return { init = init, loop = loop, destroy = destroy, author = "krpec", version = appVersion, name = trans8.appName }
