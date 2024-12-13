/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick 2.3

import QGroundControl           1.0
import QGroundControl.Controls  1.0
import QGroundControl.Vehicle   1.0

PreFlightCheckButton {
    name:               qsTr("Sensors")
    telemetryFailure:   _unhealthySensors & _allCheckedSensors

    property int    _unhealthySensors:  globals.activeVehicle ? globals.activeVehicle.sensorsUnhealthyBits : 1
    property int    _allCheckedSensors: Vehicle.SysStatusSensor3dMag |
                                        Vehicle.SysStatusSensor3dAccel |
                                        Vehicle.SysStatusSensor3dGyro |
                                        Vehicle.SysStatusSensorAbsolutePressure |
                                        Vehicle.SysStatusSensorDifferentialPressure |
                                        Vehicle.SysStatusSensorGPS |
                                        Vehicle.SysStatusSensorAHRS

    on_UnhealthySensorsChanged: updateTelemetryTextFailure()

    Component.onCompleted: updateTelemetryTextFailure()

    function updateTelemetryTextFailure() {
        if(_unhealthySensors & _allCheckedSensors) {
            if (_unhealthySensors & Vehicle.SysStatusSensor3dMag)                       telemetryTextFailure = qsTr("Thất bại. Vấn đề magnetometer. Kiểm tra console.")
            else if(_unhealthySensors & Vehicle.SysStatusSensor3dAccel)                 telemetryTextFailure = qsTr("Thất bại. Vấn đề accelerometer. Kiểm tra console.")
            else if(_unhealthySensors & Vehicle.SysStatusSensor3dGyro)                  telemetryTextFailure = qsTr("Thất bại. Vấn đề gyroscope. Kiểm tra console.")
            else if(_unhealthySensors & Vehicle.SysStatusSensorAbsolutePressure)        telemetryTextFailure = qsTr("Thất bại. Vấn đề barometer. Kiểm tra console.")
            else if(_unhealthySensors & Vehicle.SysStatusSensorDifferentialPressure)    telemetryTextFailure = qsTr("Thất bại. Vấn đề cảm biến tốc độ không khí. Kiểm tra console.")
            else if(_unhealthySensors & Vehicle.SysStatusSensorAHRS)                    telemetryTextFailure = qsTr("Thất bại. Vấn đề AHRS. Kiểm tra console.")
            else if(_unhealthySensors & Vehicle.SysStatusSensorGPS)                     telemetryTextFailure = qsTr("Thất bại. Vấn đề GPS. Kiểm tra console.")
        }
    }
}
