import QtQuick 2.3
import QtQuick.Controls 1.2

import QGroundControl.FactSystem 1.0
import QGroundControl.FactControls 1.0
import QGroundControl.Controls 1.0
import QGroundControl.Palette 1.0

Item {
    anchors.fill:   parent

    FactPanelController { id: controller; }

    property Fact _copterFenceAction:       controller.getParameterFact(-1, "FENCE_ACTION", false /* reportMissing */)
    property Fact _copterFenceEnable:       controller.getParameterFact(-1, "FENCE_ENABLE", false /* reportMissing */)
    property Fact _copterFenceType:         controller.getParameterFact(-1, "FENCE_TYPE", false /* reportMissing */)

    property Fact _batt1Monitor:            controller.getParameterFact(-1, "BATT_MONITOR")
    property Fact _batt2Monitor:            controller.getParameterFact(-1, "BATT2_MONITOR", false /* reportMissing */)
    property bool _batt2MonitorAvailable:   controller.parameterExists(-1, "BATT2_MONITOR")
    property bool _batt1MonitorEnabled:     _batt1Monitor.rawValue !== 0
    property bool _batt2MonitorEnabled:     _batt2MonitorAvailable && _batt2Monitor.rawValue !== 0

    property Fact _batt1FSLowAct:           controller.getParameterFact(-1, "r.BATT_FS_LOW_ACT", false /* reportMissing */)
    property Fact _batt1FSCritAct:          controller.getParameterFact(-1, "BATT_FS_CRT_ACT", false /* reportMissing */)
    property Fact _batt2FSLowAct:           controller.getParameterFact(-1, "BATT2_FS_LOW_ACT", false /* reportMissing */)
    property Fact _batt2FSCritAct:          controller.getParameterFact(-1, "BATT2_FS_CRT_ACT", false /* reportMissing */)
    property bool _batt1FSCritActAvailable: controller.parameterExists(-1, "BATT_FS_CRT_ACT")

    property bool _roverFirmware:           controller.parameterExists(-1, "MODE1") // This catches all usage of ArduRover firmware vehicle types: Rover, Boat...


    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
            labelText: qsTr("Kiểm tra vũ trang:")
            valueText: fact ? (fact.value & 1 ? qsTr("Đã bật") : qsTr("Một số đã tắt")) : ""

            property Fact fact: controller.getParameterFact(-1, "ARMING_CHECK")
        }

        VehicleSummaryRow {
            labelText:  qsTr("An toàn ga:")
            valueText:  fact ? fact.enumStringValue : ""
            visible:    controller.vehicle.multiRotor

            property Fact fact: controller.getParameterFact(-1, "FS_THR_ENABLE", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText:  qsTr("An toàn ga:")
            valueText:  fact ? fact.enumStringValue : ""
            visible:    controller.vehicle.fixedWing

            property Fact fact: controller.getParameterFact(-1, "THR_FAILSAFE", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText:  qsTr("An toàn ga:")
            valueText:  fact ? fact.enumStringValue : ""
            visible:    _roverFirmware

            property Fact fact: controller.getParameterFact(-1, "FS_THR_ENABLE", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText:  qsTr("Hành động an toàn:")
            valueText:  fact ? fact.enumStringValue : ""
            visible:    _roverFirmware

            property Fact fact: controller.getParameterFact(-1, "FS_ACTION", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText:  qsTr("Kiểm tra sự cố an toàn:")
            valueText:  fact ? fact.enumStringValue : ""
            visible:    _roverFirmware

            property Fact fact: controller.getParameterFact(-1, "FS_CRASH_CHECK", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText:  qsTr("An toàn pin 1 thấp:")
            valueText:  _batt1MonitorEnabled ? _batt1FSLowAct.enumStringValue : ""
            visible:    _batt1MonitorEnabled
        }

        VehicleSummaryRow {
            labelText:  qsTr("An toàn pin 1 nguy kịch:")
            valueText:  _batt1FSCritActAvailable ? _batt1FSCritAct.enumStringValue : ""
            visible:    _batt1FSCritActAvailable
        }

        VehicleSummaryRow {
            labelText:  qsTr("An toàn pin 2 thấp:")
            valueText:  _batt2MonitorEnabled ? _batt2FSLowAct.enumStringValue : ""
            visible:    _batt2MonitorEnabled
        }

        VehicleSummaryRow {
            labelText:  qsTr("An toàn pin 2 nguy kịch:")
            valueText:  _batt2MonitorEnabled ? _batt2FSCritAct.enumStringValue : ""
            visible:    _batt2MonitorEnabled
        }

        VehicleSummaryRow {
            labelText: qsTr("Hàng rào địa lý:")
            valueText: {
                if(_copterFenceEnable && _copterFenceType) {
                    if(_copterFenceEnable.value == 0 || _copterFenceType == 0) {
                        return qsTr("Vô hiệu hóa")
                    } else {
                        if(_copterFenceType.value == 1) {
                            return qsTr("Độ cao")
                        }
                        if(_copterFenceType.value == 2) {
                            return qsTr("Vòng tròn")
                        }
                        return qsTr("Độ cao,Vòng tròn")
                    }
                }
                return ""
            }
            visible: controller.vehicle.multiRotor
        }

        VehicleSummaryRow {
            labelText: qsTr("Hàng rào địa lý:")
            valueText: _copterFenceAction.value == 0 ?
                           qsTr("Chỉ báo cáo") :
                           (_copterFenceAction.value == 1 ? qsTr("RTL hoặc hạ cánh") : qsTr("Không xác định"))
            visible: controller.vehicle.multiRotor && _copterFenceEnable.value !== 0
        }

        VehicleSummaryRow {
            labelText:  qsTr("Độ cao tối thiểu RTL:")
            valueText:  fact ? (fact.value == 0 ? qsTr("hiện tại") : fact.valueString + " " + fact.units) : ""
            visible:    controller.vehicle.multiRotor

            property Fact fact: controller.getParameterFact(-1, "RTL_ALT", false /* reportMissing */)
        }

        VehicleSummaryRow {
            labelText:  qsTr("Độ cao tối thiểu RTL:")
            valueText:  fact ? (fact.value < 0 ? qsTr("hiện tại") : fact.valueString + " " + fact.units) : ""
            visible:    controller.vehicle.fixedWing

            property Fact fact: controller.getParameterFact(-1, "ALT_HOLD_RTL", false /* reportMissing */)
        }
    }
}
