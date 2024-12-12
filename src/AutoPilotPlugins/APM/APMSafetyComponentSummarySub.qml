import QtQuick 2.3
import QtQuick.Controls 1.2

import QGroundControl              1.0
import QGroundControl.FactSystem   1.0
import QGroundControl.FactControls 1.0
import QGroundControl.Controls     1.0
import QGroundControl.Palette      1.0

Item {
    anchors.fill:   parent

    property bool   _firmware34: globals.activeVehicle.versionCompare(3, 5, 0) < 0

    FactPanelController { id: controller; }

    // Enable/Action parameters
    property Fact _failsafeBatteryEnable:     controller.getParameterFact(-1, "r.BATT_FS_LOW_ACT", false)
    property Fact _failsafeEKFEnable:         controller.getParameterFact(-1, "FS_EKF_ACTION")
    property Fact _failsafeGCSEnable:         controller.getParameterFact(-1, "FS_GCS_ENABLE")
    property Fact _failsafeLeakEnable:        controller.getParameterFact(-1, "FS_LEAK_ENABLE")
    property Fact _failsafePilotEnable:       _firmware34 ? null : controller.getParameterFact(-1, "FS_PILOT_INPUT")
    property Fact _failsafePressureEnable:    controller.getParameterFact(-1, "FS_PRESS_ENABLE")
    property Fact _failsafeTemperatureEnable: controller.getParameterFact(-1, "FS_TEMP_ENABLE")

    // Threshold parameters
    property Fact _failsafePressureThreshold:    controller.getParameterFact(-1, "FS_PRESS_MAX")
    property Fact _failsafeTemperatureThreshold: controller.getParameterFact(-1, "FS_TEMP_MAX")
    property Fact _failsafePilotTimeout:         _firmware34 ? null : controller.getParameterFact(-1, "FS_PILOT_TIMEOUT")
    property Fact _failsafeLeakPin:              controller.getParameterFact(-1, "LEAK1_PIN")
    property Fact _failsafeLeakLogic:            controller.getParameterFact(-1, "LEAK1_LOGIC")
    property Fact _failsafeEKFThreshold:         controller.getParameterFact(-1, "FS_EKF_THRESH")
    property Fact _failsafeBatteryVoltage:       controller.getParameterFact(-1, "r.BATT_LOW_VOLT", false)
    property Fact _failsafeBatteryCapacity:      controller.getParameterFact(-1, "r.BATT_LOW_MAH", false)

    property Fact _armingCheck: controller.getParameterFact(-1, "ARMING_CHECK")

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            labelText: qsTr("Kiểm tra vũ trang:")
            valueText:  _armingCheck.value & 1 ? qsTr("Đã bật") : qsTr("Một số đã tắt")
        }
        VehicleSummaryRow {
            labelText: qsTr("An toàn GCS:")
            valueText: _failsafeGCSEnable.enumOrValueString
        }
        VehicleSummaryRow {
            labelText: qsTr("An toàn rò rỉ:")
            valueText:  _failsafeLeakEnable.enumOrValueString
        }
        VehicleSummaryRow {
            visible: !_firmware34
            labelText: qsTr("An toàn pin:")
            valueText: {
                if(_firmware34) {
                    return "Firmware không được hỗ trợ"
                }

                if (!_failsafeBatteryEnable) {
                    return "Vô hiệu hóa"
                }

                return _failsafeBatteryEnable.enumOrValueString
            }
        }
        VehicleSummaryRow {
            visible: !_firmware34
            labelText: qsTr("An toàn EKF:")
            valueText: _firmware34 ? "" : _failsafeEKFEnable.enumOrValueString
        }
        VehicleSummaryRow {
            visible: !_firmware34
            labelText: qsTr("An toàn đầu vào phi công:")
            valueText: _firmware34 ? "" : _failsafePilotEnable.enumOrValueString
        }
        VehicleSummaryRow {
            labelText: qsTr("An toàn nhiệt độ trong:")
            valueText:  _failsafeTemperatureEnable.enumOrValueString
        }
        VehicleSummaryRow {
            labelText: qsTr("An toàn áp suất trong:")
            valueText:  _failsafePressureEnable.enumOrValueString
        }
    }
}
