# BatLogger for Jeti DC/DS-24 & DS-12 transmitters
Jeti LUA script to log battery usage, display remaining LiPo %, set alarms for capacity used, low battery voltage & connecting uncharged battery.

This code is based on [RFID-Battery](https://www.rc-thoughts.com/rfid-battery) - many thanks to Tero from [RC-thougts.com](https://www.rc-thoughts.com)!

**Disclaimer:** Author is not liable for any damages made on batteries and/or models caused by using this script!

### Features
 * One app for all models, up to 15 batteries per model
 * All settings are model-specific
 * Automatic detection of empty battery when powering the model, alarm has user selectable voice-alert, can be repeated once or three times (alarm is disabled when the alarm voltage is set to 0.00V)
 * Capacity alarm has user selectable voice-alert, can be repeated once or three times
 * Possibility to assing a switch for remaining percentage announcement
 * Telemetry window changes based on current situation (battery overview, capacity overview, "LOW" warning)
 * Each battery has its name, cell count, capacity and cycle count stored
 * Flight logging to csv file (~~full battery has to be connected and model has to be powered for at least 30 seconds and consume some mAhs for the logging to take place~~ from version 1.5 the minimal time and consumed capacity can be set by user)

### Changelog

#### Version 1.5
 * _Release date: 2021-06-04_
 * Added miminal time & capacity settings for the logger.

#### Version 1.4
 * _Release date: 2021-03-15_ 
 * Battery selection form is no longer present in the main menu, it'll appear automatically after powering on the model
 * Low voltage alarm introduced in v1.3 removed after much consideration. All Jeti radios are capable of doing alarm such as this one by themselves, so all users are advised to set up one as a backup to capacity measuring.
 * Tested, working

#### Version 1.3 - _untested_
 * _Release date: 2021-03-09_
 * **The alarm is not working correctly, needs to be fixed. It's recommended to use v1.2 for the time being**
 * Added low battery voltage alarm
   * This will be triggered during the model operation, or may be triggered after main battery is disconnected and the receiver is powered from backup battery.
   * Won't affect the log - if the conditions for the flight to be logged are met, the log will be added to csv even if this alarm was triggered.

#### Version 1.2
 * _Release date: 2021-03-07_
 * Tested and working correctly
