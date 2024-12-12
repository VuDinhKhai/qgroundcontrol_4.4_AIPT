/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick              2.3
import QtQuick.Controls     1.2
import QtGraphicalEffects   1.0

import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0

SetupPage {
    id:             safetyPage
    pageComponent:  safetyPageComponent

    Component {
        id: safetyPageComponent

        Flow {
            id:         flowLayout
            width:      availableWidth
            spacing:    _margins

            FactPanelController { id: controller; factPanel: safetyPage.viewPanel }

            QGCPalette { id: ggcPal; colorGroupEnabled: true }

            property Fact _failsafeGCSEnable:   controller.getParameterFact(-1, "FS_GCS_ENABLE")
            property Fact _failsafeThrEnable:   controller.getParameterFact(-1, "FS_THR_ENABLE")
            property Fact _failsafeThrValue:    controller.getParameterFact(-1, "FS_THR_VALUE")
            property Fact _failsafeAction:      controller.getParameterFact(-1, "FS_ACTION")
            property Fact _failsafeCrashCheck:  controller.getParameterFact(-1, "FS_CRASH_CHECK")

            property Fact _armingCheck: controller.getParameterFact(-1, "ARMING_CHECK")

            property real _margins:     ScreenTools.defaultFontPixelHeight
            property bool _showIcon:    !ScreenTools.isTinyScreen

            Column {
                spacing: _margins / 2

                QGCLabel {
                    id:         failsafeLabel
                    text:       qsTr("Kích hoạt an toàn")
                    font.family: ScreenTools.demiboldFontFamily
                }

                Rectangle {
                    id:     failsafeSettings
                    width:  throttleEnableCombo.x + throttleEnableCombo.width + _margins
                    height: crashCheckCombo.y + crashCheckCombo.height + _margins
                    color:  ggcPal.windowShade

                    QGCLabel {
                        id:                 gcsEnableLabel
                        anchors.margins:    _margins
                        anchors.left:       parent.left
                        anchors.baseline:   gcsEnableCombo.baseline
                        text:               qsTr("An toàn trạm mặt đất:")
                    }

                    FactComboBox {
                        id:                 gcsEnableCombo
                        anchors.topMargin:  _margins
                        anchors.leftMargin: _margins
                        anchors.left:       gcsEnableLabel.right
                        anchors.top:        parent.top
                        width:              throttlePWMField.width
                        fact:               _failsafeGCSEnable
                        indexModel:         false
                    }

                    QGCLabel {
                        id:                 throttleEnableLabel
                        anchors.margins:    _margins
                        anchors.left:       parent.left
                        anchors.baseline:   throttleEnableCombo.baseline
                        text:               qsTr("An toàn ga:")
                    }

                    FactComboBox {
                        id:                 throttleEnableCombo
                        anchors.topMargin:  _margins
                        anchors.left:       gcsEnableCombo.left
                        anchors.top:        gcsEnableCombo.bottom
                        width:              throttlePWMField.width
                        fact:               _failsafeThrEnable
                        indexModel:         false
                    }

                    QGCLabel {
                        id:                 throttlePWMLabel
                        anchors.margins:    _margins
                        anchors.left:       parent.left
                        anchors.baseline:   throttlePWMField.baseline
                        text:               qsTr("Ngưỡng PWM:")
                    }

                    FactTextField {
                        id:                 throttlePWMField
                        anchors.topMargin:  _margins / 2
                        anchors.left:       gcsEnableCombo.left
                        anchors.top:        throttleEnableCombo.bottom
                        fact:               _failsafeThrValue
                        showUnits:          true
                    }

                    QGCLabel {
                        id:                 crashCheckLabel
                        anchors.margins:    _margins
                        anchors.left:       parent.left
                        anchors.baseline:   crashCheckCombo.baseline
                        text:               qsTr("Kiểm tra sự cố an toàn:")
                    }

                    QGCComboBox {
                        id:                 crashCheckCombo
                        anchors.topMargin:  _margins
                        anchors.left:       gcsEnableCombo.left
                        anchors.top:        throttlePWMField.bottom
                        width:              throttlePWMField.width
                        model:              [qsTr("Vô hiệu hóa"), qsTr("Giữ"), qsTr("Giữ và Tắt động cơ")]
                        currentIndex:       _failsafeCrashCheck.value

                        onActivated: _failsafeCrashCheck.value = index
                    }
                 } // Rectangle - Failsafe Settings
            } // Column - Failsafe Settings

            Column {
                spacing: _margins / 2

                QGCLabel {
                    text:           qsTr("Kiểm tra vũ trang")
                    font.family:    ScreenTools.demiboldFontFamily
                }

                Rectangle {
                    width:  flowLayout.width
                    height: armingCheckInnerColumn.height + (_margins * 2)
                    color:  ggcPal.windowShade

                    Column {
                        id:                 armingCheckInnerColumn
                        anchors.margins:    _margins
                        anchors.top:        parent.top
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        spacing: _margins

                        FactBitmask {
                            id:                 armingCheckBitmask
                            anchors.left:       parent.left
                            anchors.right:      parent.right
                            firstEntryIsAll:    true
                            fact:               _armingCheck
                        }

                        QGCLabel {
                            id:             armingCheckWarning
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            color:          qgcPal.warningText
                            text:            qsTr("Cảnh báo: Tắt kiểm tra vũ trang có thể dẫn đến mất kiểm soát phương tiện.")
                            visible:        _armingCheck.value != 1
                        }
                    }
                } // Rectangle - Arming checks
            } // Column - Arming Checks
        } // Flow
    } // Component - safetyPageComponent
} // SetupView
