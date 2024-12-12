/****************************************************************************
 *
 *   (c) 2009-2016 DỰ ÁN QGROUNDCONTROL <http://www.qgroundcontrol.org>
 *
 * QGroundControl được cấp phép theo các điều khoản trong tệp
 * COPYING.md trong thư mục nguồn mã nguồn.
 *
 ****************************************************************************/


import QtQuick              2.3
import QtQuick.Controls     1.2
import QtGraphicalEffects   1.0
import QtQuick.Layouts      1.2

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

            property Fact _failsafeGCSEnable:               controller.getParameterFact(-1, "FS_GCS_ENABLE")
            property Fact _failsafeBattLowAct:              controller.getParameterFact(-1, "r.BATT_FS_LOW_ACT", false /* reportMissing */)
            property Fact _failsafeBattMah:                 controller.getParameterFact(-1, "r.BATT_LOW_MAH", false /* reportMissing */)
            property Fact _failsafeBattVoltage:             controller.getParameterFact(-1, "r.BATT_LOW_VOLT", false /* reportMissing */)
            property Fact _failsafeThrEnable:               controller.getParameterFact(-1, "FS_THR_ENABLE")
            property Fact _failsafeThrValue:                controller.getParameterFact(-1, "FS_THR_VALUE")

            property Fact _batt1Monitor:                    controller.getParameterFact(-1, "BATT_MONITOR")
            property Fact _batt2Monitor:                    controller.getParameterFact(-1, "BATT2_MONITOR", false /* reportMissing */)
            property bool _batt2MonitorAvailable:           controller.parameterExists(-1, "BATT2_MONITOR")
            property bool _batt1MonitorEnabled:             _batt2MonitorAvailable ? _batt2Monitor.rawValue !== 0 : false
            property bool _batt2MonitorEnabled:             _batt2MonitorAvailable ? _batt2Monitor.rawValue !== 0 : false
            property bool _batt1ParamsAvailable:            controller.parameterExists(-1, "BATT_CAPACITY")
            property bool _batt2ParamsAvailable:            controller.parameterExists(-1, "BATT2_CAPACITY")

            property Fact _failsafeBattCritAct:             controller.getParameterFact(-1, "BATT_FS_CRT_ACT", false /* reportMissing */)
            property Fact _failsafeBatt2LowAct:             controller.getParameterFact(-1, "BATT2_FS_LOW_ACT", false /* reportMissing */)
            property Fact _failsafeBatt2CritAct:            controller.getParameterFact(-1, "BATT2_FS_CRT_ACT", false /* reportMissing */)
            property Fact _failsafeBatt2Mah:                controller.getParameterFact(-1, "BATT2_LOW_MAH", false /* reportMissing */)
            property Fact _failsafeBatt2Voltage:            controller.getParameterFact(-1, "BATT2_LOW_VOLT", false /* reportMissing */)

            property Fact _fenceAction: controller.getParameterFact(-1, "FENCE_ACTION")
            property Fact _fenceAltMax: controller.getParameterFact(-1, "FENCE_ALT_MAX")
            property Fact _fenceEnable: controller.getParameterFact(-1, "FENCE_ENABLE")
            property Fact _fenceMargin: controller.getParameterFact(-1, "FENCE_MARGIN")
            property Fact _fenceRadius: controller.getParameterFact(-1, "FENCE_RADIUS")
            property Fact _fenceType:   controller.getParameterFact(-1, "FENCE_TYPE")

            property Fact _landSpeedFact:   controller.getParameterFact(-1, "LAND_SPEED")
            property Fact _rtlAltFact:      controller.getParameterFact(-1, "RTL_ALT")
            property Fact _rtlLoitTimeFact: controller.getParameterFact(-1, "RTL_LOIT_TIME")
            property Fact _rtlAltFinalFact: controller.getParameterFact(-1, "RTL_ALT_FINAL")

            property Fact _armingCheck: controller.getParameterFact(-1, "ARMING_CHECK")

            property real _margins:     ScreenTools.defaultFontPixelHeight
            property bool _showIcon:    !ScreenTools.isTinyScreen

            ExclusiveGroup { id: fenceActionRadioGroup }
            ExclusiveGroup { id: landLoiterRadioGroup }
            ExclusiveGroup { id: returnAltRadioGroup }

            Column {
                spacing: _margins / 2
                visible: _batt1MonitorEnabled && _batt1ParamsAvailable

                QGCLabel {
                    text:       qsTr("Kích hoạt an toàn pin 1")
                    font.family: ScreenTools.demiboldFontFamily
                }

                Rectangle {
                    width:  batteryFailsafeColumn.x + batteryFailsafeColumn.width + _margins
                    height: batteryFailsafeColumn.y + batteryFailsafeColumn.height + _margins
                    color:  ggcPal.windowShade

                    Column {
                        id:                 batteryFailsafeColumn
                        anchors.margins:    _margins
                        anchors.top:        parent.top
                        anchors.left:       parent.left
                        spacing:            _margins

                        GridLayout {
                            id:             gridLayout
                            columnSpacing:  _margins
                            rowSpacing:     _margins
                            columns:        2
                            QGCLabel { text: qsTr("Hành động khi pin yếu:") }
                            FactComboBox {
                                fact:               _failsafeBattLowAct
                                indexModel:         false
                                Layout.fillWidth:   true
                            }

                            QGCLabel {
                                text:       qsTr("Hành động khi pin nguy kịch:")
                                visible:    _failsafeBattCritActAvailable
                            }
                            FactComboBox {
                                fact:               _failsafeBattCritAct
                                visible:            _failsafeBattCritActAvailable
                                indexModel:         false
                                Layout.fillWidth:   true
                            }

                            QGCCheckBox {
                                text:      qsTr("Ngưỡng điện áp:")
                                checked:   _failsafeBattVoltage.value != 0
                                onClicked: _failsafeBattVoltage.value = checked ? 10.5 : 0
                            }
                            FactTextField {
                                fact:               _failsafeBattVoltage
                                showUnits:          true
                                Layout.fillWidth:   true
                            }

                            QGCCheckBox {
                                text:       qsTr("Ngưỡng MAH:")
                                checked:    _failsafeBattMah.value != 0
                                onClicked:  _failsafeBattMah.value = checked ? 600 : 0
                            }
                            FactTextField {
                                fact:               _failsafeBattMah
                                showUnits:          true
                                Layout.fillWidth:   true
                            }
                        } // GridLayout
                    } // Column
                } // Rectangle
            } // Column - Battery Failsafe Settings

            Column {
                spacing: _margins / 2
                visible:    _batt2MonitorEnabled && _batt2ParamsAvailable

                QGCLabel {
                    text:       qsTr("Kích hoạt an toàn pin 2")
                    font.family: ScreenTools.demiboldFontFamily
                }

                Rectangle {
                    id:     failsafeSettings
                    width:  battery2FailsafeColumn.x + battery2FailsafeColumn.width + _margins
                    height: battery2FailsafeColumn.y + battery2FailsafeColumn.height + _margins
                    color:  ggcPal.windowShade

                    Column {
                        id:                 battery2FailsafeColumn
                        anchors.margins:    _margins
                        anchors.top:        parent.top
                        anchors.left:       parent.left
                        spacing:            _margins

                        GridLayout {
                            columnSpacing:  _margins
                            rowSpacing:     _margins
                            columns:        2
                            visible:        _batt2MonitorEnabled && _failsafeBatt2LowActAvailable

                            QGCLabel { text: qsTr("Hành động khi pin yếu:") }
                            FactComboBox {
                                fact:               _failsafeBatt2LowAct
                                indexModel:         false
                                Layout.fillWidth:   true
                            }

                            QGCLabel {
                                text:       qsTr("Hành động khi pin nguy kịch:")
                            }
                            FactComboBox {
                                fact:               _failsafeBatt2CritAct
                                indexModel:         false
                                Layout.fillWidth:   true
                            }

                            QGCCheckBox {
                                text:      qsTr("Ngưỡng điện áp:")
                                checked:   _failsafeBatt2Voltage.value != 0
                                onClicked: _failsafeBatt2Voltage.value = checked ? 10.5 : 0
                            }
                            FactTextField {
                                fact:               _failsafeBatt2Voltage
                                showUnits:          true
                                Layout.fillWidth:   true
                            }

                            QGCCheckBox {
                                text:       qsTr("Ngưỡng MAH:")
                                checked:    _failsafeBatt2Mah.value != 0
                                onClicked:  _failsafeBatt2Mah.value = checked ? 600 : 0
                            }
                            FactTextField {
                                fact:               _failsafeBatt2Mah
                                showUnits:          true
                                Layout.fillWidth:   true
                            }
                        } // GridLayout
                    } // Column
                } // Rectangle
            } // Column - Battery2 Failsafe Settings

            Column {
                spacing: _margins / 2

                QGCLabel {
                    text:       qsTr("Kích hoạt an toàn chung")
                    font.family: ScreenTools.demiboldFontFamily
                }

                Rectangle {
                    width:  generalFailsafeColumn.x + generalFailsafeColumn.width + _margins
                    height: generalFailsafeColumn.y + generalFailsafeColumn.height + _margins
                    color:  ggcPal.windowShade

                    Column {
                        id:                 generalFailsafeColumn
                        anchors.margins:    _margins
                        anchors.top:        parent.top
                        anchors.left:       parent.left
                        spacing:            _margins

                        GridLayout {
                            columnSpacing:  _margins
                            rowSpacing:     _margins
                            columns:        2

                            QGCLabel { text: qsTr("An toàn trạm mặt đất:") }
                            FactComboBox {
                                fact:               _failsafeGCSEnable
                                indexModel:         false
                                Layout.fillWidth:   true
                            }

                            QGCLabel { text: qsTr("An toàn bộ điều tốc:") }
                            QGCComboBox {
                                model:              [qsTr("Vô hiệu"), qsTr("Luôn RTL"),
                                    qsTr("Tiếp tục nhiệm vụ ở chế độ tự động"), qsTr("Luôn hạ cánh")]
                                currentIndex:       _failsafeThrEnable.value
                                Layout.fillWidth:   true

                                onActivated: _failsafeThrEnable.value = index
                            }

                            QGCLabel { text: qsTr("Ngưỡng PWM:") }
                            FactTextField {
                                fact:               _failsafeThrValue
                                showUnits:          true
                                Layout.fillWidth:   true
                            }
                        } // GridLayout
                    } // Column
                } // Rectangle - Failsafe Settings
            } // Column - General Failsafe Settings

            Column {
                spacing: _margins / 2

                QGCLabel {
                    id:             geoFenceLabel
                    text:           qsTr("Hàng rào địa lý")
                    font.family:    ScreenTools.demiboldFontFamily
                }

                Rectangle {
                    id:     geoFenceSettings
                    width:  fenceAltMaxField.x + fenceAltMaxField.width + _margins
                    height: fenceAltMaxField.y + fenceAltMaxField.height + _margins
                    color:  ggcPal.windowShade

                    QGCCheckBox {
                        id:                 circleGeo
                        anchors.margins:    _margins
                        anchors.left:       parent.left
                        anchors.top:        parent.top
                        text:               qsTr("Bật hàng rào địa lý hình tròn")
                        checked:            _fenceEnable.value != 0 && _fenceType.value & 2

                        onClicked: {
                            if (checked) {
                                if (_fenceEnable.value == 1) {
                                    _fenceType.value |= 2
                                } else {
                                    _fenceEnable.value = 1
                                    _fenceType.value = 2
                                }
                            } else if (altitudeGeo.checked) {
                                _fenceType.value &= ~2
                            } else {
                                _fenceEnable.value = 0
                                _fenceType.value = 0
                            }
                        }
                    }

                    QGCCheckBox {
                        id:                 altitudeGeo
                        anchors.topMargin:  _margins / 2
                        anchors.left:       circleGeo.left
                        anchors.top:        circleGeo.bottom
                        text:               qsTr("Bật hàng rào địa lý độ cao")
                        checked:            _fenceEnable.value != 0 && _fenceType.value & 1

                        onClicked: {
                            if (checked) {
                                if (_fenceEnable.value == 1) {
                                    _fenceType.value |= 1
                                } else {
                                    _fenceEnable.value = 1
                                    _fenceType.value = 1
                                }
                            } else if (circleGeo.checked) {
                                _fenceType.value &= ~1
                            } else {
                                _fenceEnable.value = 0
                                _fenceType.value = 0
                            }
                        }
                    }

                    QGCRadioButton {
                        id:                 geoReportRadio
                        anchors.margins:    _margins
                        anchors.left:       parent.left
                        anchors.top:        altitudeGeo.bottom
                        text:               qsTr("Chỉ báo cáo")
                        exclusiveGroup:     fenceActionRadioGroup
                        checked:            _fenceAction.value == 0

                        onClicked: _fenceAction.value = 0
                    }

                    QGCRadioButton {
                        id:                 geoRTLRadio
                        anchors.topMargin:  _margins / 2
                        anchors.left:       circleGeo.left
                        anchors.top:        geoReportRadio.bottom
                        text:               qsTr("RTL hoặc hạ cánh")
                        exclusiveGroup:     fenceActionRadioGroup
                        checked:            _fenceAction.value == 1

                        onClicked: _fenceAction.value = 1
                    }

                    QGCLabel {
                        id:                 fenceRadiusLabel
                        anchors.left:       circleGeo.left
                        anchors.baseline:   fenceRadiusField.baseline
                        text:               qsTr("Bán kính tối đa:")
                    }

                    FactTextField {
                        id:                 fenceRadiusField
                        anchors.topMargin:  _margins
                        anchors.left:       fenceAltMaxField.left
                        anchors.top:        geoRTLRadio.bottom
                        fact:               _fenceRadius
                        showUnits:          true
                    }

                    QGCLabel {
                        id:                 fenceAltMaxLabel
                        anchors.left:       circleGeo.left
                        anchors.baseline:   fenceAltMaxField.baseline
                        text:               qsTr("Độ cao tối đa:")
                    }

                    FactTextField {
                        id:                 fenceAltMaxField
                        anchors.topMargin:  _margins / 2
                        anchors.leftMargin: _margins
                        anchors.left:       fenceAltMaxLabel.right
                        anchors.top:        fenceRadiusField.bottom
                        fact:               _fenceAltMax
                        showUnits:          true
                    }
                } // Rectangle - GeoFence Settings
            } // Column - GeoFence Settings

            Column {
                spacing: _margins / 2

                QGCLabel {
                    id:             rtlLabel
                    text:           qsTr("Trở về điểm phóng")
                    font.family:    ScreenTools.demiboldFontFamily
                }

                Rectangle {
                    id:     rtlSettings
                    width:  rltAltFinalField.x + rltAltFinalField.width + _margins
                    height: rltAltFinalField.y + rltAltFinalField.height + _margins
                    color:  ggcPal.windowShade

                    Image {
                        id:                 icon
                        anchors.margins:    _margins
                        anchors.left:       parent.left
                        anchors.top:        parent.top
                        height:             ScreenTools.defaultFontPixelWidth * 20
                        width:              ScreenTools.defaultFontPixelWidth * 20
                        sourceSize.width:   width
                        mipmap:             true
                        fillMode:           Image.PreserveAspectFit
                        visible:            false
                        source:             "/qmlimages/ReturnToHomeAltitude.svg"
                    }

                    ColorOverlay {
                        anchors.fill:   icon
                        source:         icon
                        color:          ggcPal.text
                        visible:        _showIcon
                    }

                    QGCRadioButton {
                        id:                 returnAtCurrentRadio
                        anchors.margins:    _margins
                        anchors.left:       _showIcon ? icon.right : parent.left
                        anchors.top:        parent.top
                        text:               qsTr("Trở về ở độ cao hiện tại")
                        checked:            _rtlAltFact.value == 0
                        exclusiveGroup:     returnAltRadioGroup

                        onClicked: _rtlAltFact.value = 0
                    }

                    QGCRadioButton {
                        id:                 returnAltRadio
                        anchors.topMargin:  _margins
                        anchors.left:       returnAtCurrentRadio.left
                        anchors.top:        returnAtCurrentRadio.bottom
                        text:               qsTr("Trở về ở độ cao chỉ định:")
                        exclusiveGroup:     returnAltRadioGroup
                        checked:            _rtlAltFact.value != 0

                        onClicked: _rtlAltFact.value = 1500
                    }

                    FactTextField {
                        id:                 rltAltField
                        anchors.leftMargin: _margins
                        anchors.left:       returnAltRadio.right
                        anchors.baseline:   returnAltRadio.baseline
                        fact:               _rtlAltFact
                        showUnits:          true
                        enabled:            returnAltRadio.checked
                    }

                    QGCCheckBox {
                        id:                 homeLoiterCheckbox
                        anchors.left:       returnAtCurrentRadio.left
                        anchors.baseline:   landDelayField.baseline
                        checked:            _rtlLoitTimeFact.value > 0
                        text:               qsTr("Bay lượn trên điểm Home trong:")

                        onClicked: _rtlLoitTimeFact.value = (checked ? 60 : 0)
                    }

                    FactTextField {
                        id:                 landDelayField
                        anchors.topMargin:  _margins * 1.5
                        anchors.left:       rltAltField.left
                        anchors.top:        rltAltField.bottom
                        fact:               _rtlLoitTimeFact
                        showUnits:          true
                        enabled:            homeLoiterCheckbox.checked === true
                    }

                    QGCRadioButton {
                        id:                 landRadio
                        anchors.left:       returnAtCurrentRadio.left
                        anchors.baseline:   landSpeedField.baseline
                        text:               qsTr("Hạ cánh với tốc độ giảm:")
                        checked:            _rtlAltFinalFact.value == 0
                        exclusiveGroup:     landLoiterRadioGroup

                        onClicked: _rtlAltFinalFact.value = 0
                    }

                    FactTextField {
                        id:                 landSpeedField
                        anchors.topMargin:  _margins * 1.5
                        anchors.top:        landDelayField.bottom
                        anchors.left:       rltAltField.left
                        fact:               _landSpeedFact
                        showUnits:          true
                        enabled:            landRadio.checked
                    }

                    QGCRadioButton {
                        id:                 finalLoiterRadio
                        anchors.left:       returnAtCurrentRadio.left
                        anchors.baseline:   rltAltFinalField.baseline
                        text:               qsTr("Độ cao bay lượn cuối cùng:")
                        exclusiveGroup:     landLoiterRadioGroup

                        onClicked: _rtlAltFinalFact.value = _rtlAltFact.value
                    }

                    FactTextField {
                        id:                 rltAltFinalField
                        anchors.topMargin:  _margins / 2
                        anchors.left:       rltAltField.left
                        anchors.top:        landSpeedField.bottom
                        fact:               _rtlAltFinalFact
                        enabled:            finalLoiterRadio.checked
                        showUnits:          true
                    }
                } // Rectangle - RTL Settings
            } // Column - RTL Settings

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
