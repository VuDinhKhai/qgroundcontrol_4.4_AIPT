/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.12
import QtQuick.Layouts  1.2
import QtQuick.Controls 2.5
import QtQuick.Dialogs  1.3

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Controllers   1.0

QGCPopupDialog {
    title:      qsTr("RC Đến Param")
    buttons:    StandardButton.Cancel | StandardButton.Ok

    property alias tuningFact: controller.tuningFact

    onAccepted: QGroundControl.multiVehicleManager.activeVehicle.sendParamMapRC(tuningFact.name, scale.text, centerValue.text, tuningID.currentIndex, minValue.text, maxValue.text)

    RCToParamDialogController {
        id: controller
    }

    ColumnLayout {
        spacing: ScreenTools.defaultDialogControlSpacing

        QGCLabel {
            Layout.preferredWidth:  mainGrid.width
            Layout.fillWidth:       true
            wrapMode:               Text.WordWrap
            text:                   qsTr("Liên kết một Kênh RC với một giá trị tham số. ID điều chỉnh có thể được ánh xạ tới một Kênh RC từ trang Thiết lập Radio.")
        }

        QGCLabel {
            Layout.preferredWidth:  mainGrid.width
            Layout.fillWidth:       true
            text:                   qsTr("Đang chờ cập nhật thông số từ phương tiện.")
            visible:                !controller.ready
        }

        GridLayout {
            id:             mainGrid
            columns:        2
            rowSpacing:     ScreenTools.defaultDialogControlSpacing
            columnSpacing:  ScreenTools.defaultDialogControlSpacing
            enabled:        controller.ready

            QGCLabel { text: qsTr("Tham số") }
            QGCLabel { text: tuningFact.name }

            QGCLabel { text: qsTr("ID điều chỉnh") }
            QGCComboBox {
                id:                 tuningID
                Layout.fillWidth:   true
                currentIndex:       0
                model:              [ 1, 2, 3 ]
            }

            QGCLabel { text: qsTr("Tỉ lệ") }
            QGCTextField {
                id:     scale
                text:   controller.scale.valueString
            }

            QGCLabel { text: qsTr("Giá trị trung tâm") }
            QGCTextField {
                id:     centerValue
                text:   controller.center.valueString
            }

            QGCLabel { text: qsTr("Giá trị tối thiểu") }
            QGCTextField {
                id:     minValue
                text:   controller.min.valueString
            }

            QGCLabel { text: qsTr("Giá trị tối đa") }
            QGCTextField {
                id:     maxValue
                text:   controller.max.valueString
            }
        }

        QGCLabel {
            Layout.preferredWidth:  mainGrid.width
            Layout.fillWidth:       true
            wrapMode:               Text.WordWrap
            text:                   qsTr("Kiểm tra lại xem tất cả giá trị có chính xác không trước khi xác nhận hộp thoại.")
        }
    }
}
