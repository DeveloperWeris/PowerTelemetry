#Requires AutoHotkey v2.0
#SingleInstance Force

global DesignCap := 0
global FullCap := 0

GetStaticHardwareInfo()

MyGui := Gui("+AlwaysOnTop -MaximizeBox +Owner +ToolWindow", "Power Telemetry")
MyGui.Color := "White"
MyGui.SetFont("s10 w700", "Segoe UI")

MyGui.Add("Text", "x15 y12 w270 c0078D7", "POWER MONITOR")
MyGui.Add("Progress", "x15 y32 w270 h1 c0078D7", 100)

MyGui.SetFont("s9 w400 c555555")
MyGui.Add("Text", "x15 y45 w110", "Power Source:")
MyGui.Add("Text", "x15 y70 w110", "Net Flow Rate:")
MyGui.Add("Text", "x15 y95 w110", "Charge Level:")
MyGui.Add("Text", "x15 y120 w110", "Time Remaining:")
MyGui.Add("Text", "x15 y145 w110", "Battery Voltage:")
MyGui.Add("Text", "x15 y170 w110", "Battery Health:")
MyGui.Add("Text", "x15 y195 w110", "Capacity Status:")

MyGui.SetFont("s9 w600 c111111")
StatusDisplay  := MyGui.Add("Text", "x135 y45 w150", "Checking...")
RateDisplay    := MyGui.Add("Text", "x135 y70 w150", "-- mW")
PercentDisplay := MyGui.Add("Text", "x135 y95 w150", "-- %")
TimeDisplay    := MyGui.Add("Text", "x135 y120 w150", "--")
VoltageDisplay := MyGui.Add("Text", "x135 y145 w150", "-- V")
HealthDisplay  := MyGui.Add("Text", "x135 y170 w150", "-- %")
CapDisplay     := MyGui.Add("Text", "x135 y195 w150", "-- mWh")

MyGui.OnEvent("Close", (*) => ExitApp())
MyGui.Show("w300 h225")

SetTimer(RefreshStats, 1000)
return

GetStaticHardwareInfo() {
    global DesignCap, FullCap
    
    try {
        wmiWmi := ComObjGet("winmgmts:\\.\root\wmi")
        for item in wmiWmi.ExecQuery("SELECT DesignedCapacity FROM BatteryStaticData")
            DesignCap := item.DesignedCapacity
        for item in wmiWmi.ExecQuery("SELECT FullChargedCapacity FROM BatteryFullChargedCapacity")
            FullCap := item.FullChargedCapacity
        
        if (!DesignCap) {
            for item in wmiWmi.ExecQuery("SELECT DesignCapacity FROM BatteryStaticData")
                DesignCap := item.DesignCapacity
        }
        if (!FullCap) {
            for item in wmiWmi.ExecQuery("SELECT FullCapacity FROM BatteryFullCapacity")
                FullCap := item.FullCapacity
        }
    }
    
    if (!DesignCap || !FullCap) {
        try {
            wmiCim := ComObjGet("winmgmts:\\.\root\cimv2")
            for item in wmiCim.ExecQuery("SELECT DesignCapacity, FullChargeCapacity FROM Win32_Battery") {
                if (!DesignCap && item.DesignCapacity)
                    DesignCap := item.DesignCapacity
                if (!FullCap && item.FullChargeCapacity)
                    FullCap := item.FullChargeCapacity
            }
            if (!DesignCap) {
                for item in wmiCim.ExecQuery("SELECT DesignCapacity FROM Win32_PortableBattery")
                    DesignCap := item.DesignCapacity
            }
        }
    }
}

RefreshStats() {
    global DesignCap, FullCap
    
    powerStatus := Buffer(12, 0)
    if !DllCall("GetSystemPowerStatus", "Ptr", powerStatus)
        return
        
    acStatus           := NumGet(powerStatus, 0, "UChar")
    batteryFlag        := NumGet(powerStatus, 1, "UChar")
    batteryLifePercent := NumGet(powerStatus, 2, "UChar")
    batteryLifeTime    := NumGet(powerStatus, 4, "UInt")

    if (batteryFlag = 128 || (acStatus = 1 && batteryLifePercent = 255)) {
        StatusDisplay.Value  := "Continuous AC Power"
        RateDisplay.Value    := "N/A (Desktop)"
        PercentDisplay.Value := "100% (Mains)"
        TimeDisplay.Value    := "Unlimited"
        VoltageDisplay.Value := "Stable AC Grid"
        HealthDisplay.Value  := "100% (No Degradation)"
        CapDisplay.Value     := "N/A"
        return
    }

    chargeRate := 0
    dischargeRate := 0
    voltage := 0
    remCap := 0
    isCharging := false
    isDischarging := false
    
    try {
        wmi := ComObjGet("winmgmts:{impersonationLevel=impersonate}!\\.\root\wmi")
        for item in wmi.ExecQuery("SELECT * FROM BatteryStatus") {
            try chargeRate := item.ChargeRate
            try dischargeRate := item.DischargeRate
            try voltage := item.Voltage
            try remCap := item.RemainingCapacity
            try isCharging := item.Charging
            try isDischarging := item.Discharging
        }
    }

    rateStr := "0 mW"
    if (isCharging && chargeRate > 0)
        rateStr := "+" . chargeRate . " mW"
    else if (isDischarging && dischargeRate > 0)
        rateStr := "-" . dischargeRate . " mW"
    else if (chargeRate > 0)
        rateStr := "+" . chargeRate . " mW"
    else if (dischargeRate > 0)
        rateStr := "-" . dischargeRate . " mW"
    else if (acStatus = 1)
        rateStr := (batteryFlag & 8) ? "Driver Restricted" : "0 mW (Fully Charged)"
    else if (acStatus = 0)
        rateStr := "Driver Restricted"

    statusStr := "Idle"
    if (acStatus = 1 && (isCharging || (batteryFlag & 8)))
        statusStr := "Charging"
    else if (acStatus = 1)
        statusStr := "AC Power (Mains)"
    else if (acStatus = 0 || isDischarging)
        statusStr := "Discharging"

    pctStr := (batteryLifePercent = 255) ? "Unknown" : batteryLifePercent . "%"

    timeStr := "Calculating..."
    if (acStatus = 1) {
        timeStr := "Continuous Power"
    } else if (batteryLifeTime != 4294967295 && batteryLifeTime != -1) {
        hr := Floor(batteryLifeTime / 3600)
        mn := Floor(Mod(batteryLifeTime, 3600) / 60)
        timeStr := hr . "h " . mn . "m remaining"
    }

    voltStr := "N/A"
    if (voltage > 0)
        voltStr := Round(voltage / 1000, 2) . " V"

    if (DesignCap > 0 && FullCap > 0) {
        healthVal := Round((FullCap / DesignCap) * 100, 1)
        healthStr := healthVal . "% (" . (healthVal >= 80 ? "Healthy" : "Degraded") . ")"
        capStr := remCap . " / " . FullCap . " mWh"
    } else {
        healthStr := "Driver Restricted"
        capStr := (remCap > 0 ? remCap . " mWh" : "N/A")
    }

    StatusDisplay.Value  := statusStr
    RateDisplay.Value    := rateStr
    PercentDisplay.Value := pctStr
    TimeDisplay.Value    := timeStr
    VoltageDisplay.Value := voltStr
    HealthDisplay.Value  := healthStr
    CapDisplay.Value     := capStr
}
