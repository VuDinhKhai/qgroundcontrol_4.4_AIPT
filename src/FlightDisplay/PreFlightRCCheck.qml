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
    name:                   qsTr("Điều khiển Radio")
    manualText:             qsTr("Nhận được tín hiệu. Thực hiện kiểm tra phạm vi và xác nhận.")
    telemetryTextFailure:   qsTr("Không có tín hiệu hoặc cấu hình RC-autopilot không hợp lệ. Kiểm tra RC và console.")
    telemetryFailure:       false//_unhealthySensors & Vehicle.SysStatusSensorRCReceiver

    property int _unhealthySensors: globals.activeVehicle ? globals.activeVehicle.sensorsUnhealthyBits : 0
}
