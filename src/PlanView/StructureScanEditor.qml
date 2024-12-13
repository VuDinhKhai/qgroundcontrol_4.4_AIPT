import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Controls.Styles 1.4
import QtQuick.Dialogs  1.2
import QtQuick.Extras   1.4
import QtQuick.Layouts  1.2

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Vehicle       1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Palette       1.0
import QGroundControl.FlightMap     1.0

// Editor for Survery mission items
Rectangle {
    id:         _root
    height:     visible ? (editorColumn.height + (_margin * 2)) : 0
    width:      availableWidth
    color:      qgcPal.windowShadeDark
    radius:     _radius

    // The following properties must be available up the hierarchy chain
    //property real   availableWidth    ///< Width for control
    //property var    missionItem       ///< Mission Item for editor

    property real   _margin:                    ScreenTools.defaultFontPixelWidth / 2
    property real   _fieldWidth:                ScreenTools.defaultFontPixelWidth * 10.5
    property var    _vehicle:                   QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle : QGroundControl.multiVehicleManager.offlineEditingVehicle
    property real   _cameraMinTriggerInterval:  missionItem.cameraCalc.minTriggerInterval.rawValue

    function polygonCaptureStarted() {
        missionItem.clearPolygon()
    }

    function polygonCaptureFinished(coordinates) {
        for (var i=0; i<coordinates.length; i++) {
            missionItem.addPolygonCoordinate(coordinates[i])
        }
    }

    function polygonAdjustVertex(vertexIndex, vertexCoordinate) {
        missionItem.adjustPolygonCoordinate(vertexIndex, vertexCoordinate)
    }

    function polygonAdjustStarted() { }
    function polygonAdjustFinished() { }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    ColumnLayout {
        id:                 editorColumn
        anchors.margins:    _margin
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right

        QGCLabel {
                id:                 wizardLabel
                Layout.fillWidth:   true
                wrapMode:           Text.WordWrap
                horizontalAlignment:    Text.AlignHCenter
                text:               qsTr("Sử dụng các công cụ Polygon để tạo ra đa giác bao quanh cấu trúc.")
                visible:        !missionItem.structurePolygon.isValid || missionItem.wizardMode
            }

        ColumnLayout {
            Layout.fillWidth:   true
            spacing:        _margin
            visible:        !wizardLabel.visible

            QGCTabBar {
                id:             tabBar
                Layout.fillWidth:   true

                Component.onCompleted: currentIndex = 0

                QGCTabButton { text: qsTr("Lưới") }
                QGCTabButton { text: qsTr("Máy ảnh") }
            }

            ColumnLayout {
                Layout.fillWidth:   true
                spacing:            _margin
                visible:            tabBar.currentIndex == 0

                QGCLabel {
                    Layout.fillWidth:   true
                    text:           qsTr("Lưu ý: Đa giác đại diện cho bề mặt cấu trúc không phải là đường bay của phương tiện.")
                    wrapMode:       Text.WordWrap
                    font.pointSize: ScreenTools.smallFontPointSize
                }

                QGCLabel {
                    Layout.fillWidth:   true
                    text:           qsTr("CẢNH BÁO: Khoảng thời gian chụp ảnh dưới mức tối thiểu (%1 giây) được hỗ trợ bởi máy ảnh.").arg(_cameraMinTriggerInterval.toFixed(1))
                    wrapMode:       Text.WordWrap
                    color:          qgcPal.warningText
                    visible:        missionItem.cameraShots > 0 && _cameraMinTriggerInterval !== 0 && _cameraMinTriggerInterval > missionItem.timeBetweenShots
                }

                CameraCalcGrid {
                    Layout.fillWidth:   true
                    cameraCalc:                     missionItem.cameraCalc
                    vehicleFlightIsFrontal:         false
                    distanceToSurfaceLabel:         qsTr("Khoảng cách quét")
                    frontalDistanceLabel:           qsTr("Chiều cao lớp")
                    sideDistanceLabel:              qsTr("Khoảng cách kích hoạt")
                }

                SectionHeader {
                    id:             scanHeader
                    Layout.fillWidth:   true
                    text:           qsTr("Quét")
                }

                ColumnLayout {
                    Layout.fillWidth:   true
                    spacing:        _margin
                    visible:        scanHeader.checked

                    GridLayout {
                        Layout.fillWidth:   true
                        columnSpacing:  _margin
                        rowSpacing:     _margin
                        columns:        2

                        FactComboBox {
                            fact:               missionItem.startFromTop
                            indexModel:         true
                            model:              [ qsTr("Bắt đầu quét từ dưới lên"), qsTr("Bắt đầu quét từ trên xuống") ]
                            Layout.columnSpan:  2
                            Layout.fillWidth:   true
                        }

                        QGCLabel {
                            text:       qsTr("Chiều cao cấu trúc")
                        }
                        FactTextField {
                            fact:               missionItem.structureHeight
                            Layout.fillWidth:   true
                        }

                        QGCLabel { text: qsTr("Alt đáy quét") }
                        AltitudeFactTextField {
                            fact:               missionItem.scanBottomAlt
                            altitudeMode:       QGroundControl.AltitudeModeRelative
                            Layout.fillWidth:   true
                        }

                        QGCLabel { text: qsTr("Alt vào/ra") }
                        AltitudeFactTextField {
                            fact:               missionItem.entranceAlt
                            altitudeMode:       QGroundControl.AltitudeModeRelative
                            Layout.fillWidth:   true
                        }

                        QGCLabel {
                            text:       qsTr("Góc nghiêng gimbal")
                            visible:    missionItem.cameraCalc.isManualCamera
                        }
                        FactTextField {
                            fact:               missionItem.gimbalPitch
                            Layout.fillWidth:   true
                            visible:            missionItem.cameraCalc.isManualCamera
                        }
                    }

                    Item {
                        height: ScreenTools.defaultFontPixelHeight / 2
                        width:  1
                    }

                    QGCButton {
                        text:       qsTr("Xoay điểm vào")
                        onClicked:  missionItem.rotateEntryPoint()
                    }
                } // Column - Scan

                SectionHeader {
                    id:             statsHeader
                    Layout.fillWidth:   true
                    text:           qsTr("Thống kê")
                }

                Grid {
                    columns:        2
                    columnSpacing:  ScreenTools.defaultFontPixelWidth
                    visible:        statsHeader.checked

                    QGCLabel { text: qsTr("Lớp") }
                    QGCLabel { text: missionItem.layers.valueString }

                    QGCLabel { text: qsTr("Chiều cao lớp") }
                    QGCLabel { text: missionItem.cameraCalc.adjustedFootprintFrontal.valueString + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString }

                    QGCLabel { text: qsTr("Alt lớp trên") }
                    QGCLabel { text: QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(missionItem.topFlightAlt).toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString }

                    QGCLabel { text: qsTr("Alt lớp dưới") }
                    QGCLabel { text: QGroundControl.unitsConversion.metersToAppSettingsHorizontalDistanceUnits(missionItem.bottomFlightAlt).toFixed(1) + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString }

                    QGCLabel { text: qsTr("Số ảnh") }
                    QGCLabel { text: missionItem.cameraShots }

                    QGCLabel { text: qsTr("Khoảng thời gian ảnh") }
                    QGCLabel { text: missionItem.timeBetweenShots.toFixed(1) + " " + qsTr("giây") }

                    QGCLabel { text: qsTr("Khoảng cách kích hoạt") }
                    QGCLabel { text: missionItem.cameraCalc.adjustedFootprintSide.valueString + " " + QGroundControl.unitsConversion.appSettingsHorizontalDistanceUnitsString }
                }
            } // Grid Column

            ColumnLayout {
                Layout.fillWidth:   true
                spacing:            _margin
                visible:            tabBar.currentIndex == 1

                CameraCalcCamera {
                    Layout.fillWidth:   true
                    cameraCalc: missionItem.cameraCalc
                }
            }
        }
    }
}
