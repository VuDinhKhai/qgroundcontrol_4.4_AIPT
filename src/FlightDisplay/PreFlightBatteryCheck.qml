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

// Lớp này lưu trữ dữ liệu và các chức năng của danh sách kiểm tra nhưng KHÔNG phải là GUI (được xử lý ở đâu đó).
PreFlightCheckButton {
    name:                           qsTr("Pin")
    manualText:                     qsTr("Connector pin đã được cắm chắc chắn?")
    telemetryFailure:               _batLow
    telemetryTextFailure:           allowTelemetryFailureOverride ?
                                        qsTr("Cảnh báo - Dung lượng pin dưới %1%.").arg(failurePercent) :
                                        qsTr("Dung lượng pin dưới %1%. Vui lòng sạc lại.").arg(failurePercent)
    allowTelemetryFailureOverride:  allowFailurePercentOverride

    property int    failurePercent:                 40
    property bool   allowFailurePercentOverride:    false
    property var    _batteryGroup:                  globals.activeVehicle && globals.activeVehicle.batteries.count ? globals.activeVehicle.batteries.get(0) : undefined
    property var    _batteryValue:                  _batteryGroup ? _batteryGroup.percentRemaining.value : 0
    property var    _batPercentRemaining:           isNaN(_batteryValue) ? 0 : _batteryValue
    property bool   _batLow:                        _batPercentRemaining < failurePercent
}
