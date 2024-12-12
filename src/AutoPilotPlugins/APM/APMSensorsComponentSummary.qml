import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Layouts          1.2

import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controllers   1.0
import QGroundControl.ArduPilot     1.0

/*
    IMPORTANT NOTE: Any changes made here must also be made to SensorsComponentSummary.qml
*/

Item {
    anchors.fill:   parent

    APMSensorsComponentController { id: controller; }

    APMSensorParams {
        id:                     sensorParams
        factPanelController:    controller
    }

    Column {
        anchors.fill:       parent

        VehicleSummaryRow {
        labelText:  qsTr("La bàn:")
        valueText: ""
        }

        Repeater {
            model: sensorParams.rgCompassAvailable.length
            RowLayout {
                Layout.fillWidth: true
                width: parent.width

                QGCLabel {

                    text:  sensorParams.rgCompassAvailable[index] ?
                                (sensorParams.rgCompassCalibrated[index] ?
                                     getPriority(index) +
                                     (sensorParams.rgCompassExternalParamAvailable[index] ?
                                          (sensorParams.rgCompassExternal[index] ? ", Bên ngoài" : ", Bên trong" ) :
                                          "") :
                                     qsTr("Yêu cầu thiết lập")) :
                                qsTr("Chưa cài đặt")

                    function getPriority (index) {
                        if (sensorParams.rgCompassId[index].value == sensorParams.rgCompassPrio[0].value) {
                            return "Chính"
                        }
                        if (sensorParams.rgCompassId[index].value == sensorParams.rgCompassPrio[1].value) {
                            return "Phụ"
                        }
                        if (sensorParams.rgCompassId[index].value == sensorParams.rgCompassPrio[2].value) {
                            return "Thứ ba"
                        }
                        return "Không sử dụng"
                    }
                }

                APMSensorIdDecoder {
                    horizontalAlignment:    Text.AlignRight
                    Layout.alignment:       Qt.AlignRight

                    fact: sensorParams.rgCompassPrio[index]
                }
            }
        }

        VehicleSummaryRow {
            labelText: qsTr("Gia tốc kế:")
            valueText: controller.accelSetupNeeded ? qsTr("Yêu cầu thiết lập") : qsTr("Sẵn sàng")
        }

        Repeater {
            model: sensorParams.rgInsId.length
            APMSensorIdDecoder {
                fact:          sensorParams.rgInsId[index]
                anchors.right: parent.right
            }
        }

        VehicleSummaryRow {
            labelText: qsTr("Áp kế:")
            valueText: sensorParams.baroIdAvailable ? "" : qsTr("Không hỗ trợ (Trên APM 4.1)")
        }

        Repeater {
            model: sensorParams.rgBaroId.length
            APMSensorIdDecoder {
                fact:          sensorParams.rgBaroId[index]
                anchors.right: parent.right
            }
        }
    }
}
