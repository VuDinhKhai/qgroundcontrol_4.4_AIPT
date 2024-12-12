/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick 2.3
import QtQuick.Controls 1.2

import QGroundControl.FactSystem 1.0
import QGroundControl.FactControls 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Palette 1.0

Item {
    anchors.fill:   parent
    color:          qgcPal.windowShadeDark

    FactPanelController { id: controller; }

    property Fact _failsafeThrEnable:   controller.getParameterFact(-1, "FS_THR_ENABLE")
    property Fact _failsafeThrValue:    controller.getParameterFact(-1, "FS_THR_VALUE")
    property Fact _failsafeAction:      controller.getParameterFact(-1, "FS_ACTION")
    property Fact _failsafeCrashCheck:  controller.getParameterFact(-1, "FS_CRASH_CHECK")

    property Fact _armingCheck:         controller.getParameterFact(-1, "ARMING_CHECK")

    property string _failsafeActionText
    property string _failsafeCrashCheckText

    Component.onCompleted: {
        setFailsafeActionText()
        setFailsafeCrashCheckText()
    }

    Connections {
        target: _failsafeAction

        onValueChanged: setFailsafeActionText()
    }

    Connections {
        target: _failsafeCrashCheck

        onValueChanged: setFailsafeCrashCheckText()
    }

    function setFailsafeActionText() {
        switch (_failsafeAction.value) {
        case 0:
            _failsafeActionText = qsTr("Vô hiệu hóa")
            break
        case 1:
            _failsafeActionText = qsTr("Luôn RTL")
            break
        case 2:
            _failsafeActionText = qsTr("Luôn giữ")
            break
        default:
            _failsafeActionText = qsTr("Không xác định")
        }
    }

    function setFailsafeCrashCheckText() {
        switch (_failsafeCrashCheck.value) {
        case 0:
            _failsafeCrashCheckText = qsTr("Vô hiệu hóa")
            break
        case 1:
            _failsafeCrashCheckText = qsTr("Giữ")
            break
        case 2:
            _failsafeCrashCheckText = qsTr("Giữ và Tắt động cơ")
            break
        default:
            _failsafeCrashCheckText = qsTr("Không xác định")
        }
    }

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            labelText: qsTr("Kiểm tra vũ trang:")
            valueText:  _armingCheck.value & 1 ? qsTr("Đã bật") : qsTr("Một số đã tắt")
        }

        VehicleSummaryRow {
            labelText: qsTr("An toàn ga:")
            valueText:  _failsafeThrEnable.value != 0 ? _failsafeThrValue.valueString : qsTr("Vô hiệu hóa")
        }

        VehicleSummaryRow {
            labelText: qsTr("Hành động an toàn:")
            valueText: _failsafeActionText
        }

        VehicleSummaryRow {
            labelText: qsTr("Kiểm tra va chạm an toàn:")
            valueText: _failsafeCrashCheckText
        }

    }
}
