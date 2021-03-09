# BatLogger for Jeti DC/DS-24 & DS-12 transmitters
Jeti LUA script to log battery usage, display remaining LiPo %, set alarms for capacity used & connecting uncharged battery.

This code is based on [RFID-Battery](https://www.rc-thoughts.com/rfid-battery) - many thanks to Tero from [RC-thougts.com](https://www.rc-thoughts.com)!

### Features
 * One app for all models, up to 15 batteries per model
 * All settings are model-specific
 * Automatic detection of empty battery when powering the model, alarm has user selectable voice-alert, can be repeated once or three times
 * Capacity alarm has user selectable voice-alert, can be repeated once or three times
 * Possibility to assing a switch for remaining percentage announcement
 * Telemetry window changes based on current situation (battery overview, capacity overview, "LOW" warning)
 * Each battery has its name, cell count, capacity and cycle count stored
 * Flight logging to csv file (full battery has to be connected and model has to be powered for at least 30 seconds and consume some mAhs for the logging to take place)

### Changelog
#### Version 1.3
 * Added low battery voltage alarm
  * This will be triggered during the model operation, or may be triggered after main battery is disconnected and the receiver is powered from backup battery.
  * Won't affect the log - if the conditions for the flight to be logged are met, the log will be added to csv even if this alarm was triggered.

#### Version 1.2
 * Tested and working correctly
