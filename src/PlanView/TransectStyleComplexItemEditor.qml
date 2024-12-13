import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Dialogs  1.2
import QtQuick.Extras   1.4
import QtQuick.Layouts  1.2

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Vehicle       1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Palette       1.0
import QGroundControl.FlightMap     1.0

Rectangle {
    id:         _root
    height:     childrenRect.y + childrenRect.height + _margin
    width:      availableWidth
    color:      qgcPal.windowShadeDark
    radius:     _radius

    property bool   transectAreaDefinitionComplete: true
    property string transectAreaDefinitionHelp:     _internalError
    property string transectValuesHeaderName:       _internalError
    property var    transectValuesComponent:        undefined
    property var    presetsTransectValuesComponent: undefined

    readonly property string _internalError: "Lỗi Nội bộ"

    property var    _missionItem:               missionItem
    property real   _margin:                    ScreenTools.defaultFontPixelWidth / 2
    property real   _fieldWidth:                ScreenTools.defaultFontPixelWidth * 10.5
    property var    _vehicle:                   QGroundControl.multiVehicleManager.activeVehicle ? QGroundControl.multiVehicleManager.activeVehicle : QGroundControl.multiVehicleManager.offlineEditingVehicle
    property real   _cameraMinTriggerInterval:  _missionItem.cameraCalc.minTriggerInterval.rawValue
    property string _doneAdjusting:             qsTr("Xong")
    property bool   _presetsAvailable:          _missionItem.presetNames.length !== 0

    function polygonCaptureStarted() {
        _missionItem.clearPolygon()
    }

    function polygonCaptureFinished(coordinates) {
        for (var i=0; i<coordinates.length; i++) {
            _missionItem.addPolygonCoordinate(coordinates[i])
        }
    }

    function polygonAdjustVertex(vertexIndex, vertexCoordinate) {
        _missionItem.adjustPolygonCoordinate(vertexIndex, vertexCoordinate)
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
            id:                     transectAreaDefinitionCompleteLabel
            Layout.fillWidth:       true
            wrapMode:               Text.WordWrap
            horizontalAlignment:    Text.AlignHCenter
            text:                   transectAreaDefinitionHelp
            visible:                !transectAreaDefinitionComplete || _missionItem.wizardMode
        }

        ColumnLayout {
            Layout.fillWidth:   true
            spacing:            _margin
            visible:            transectAreaDefinitionComplete && !_missionItem.wizardMode

            TransectStyleComplexItemTabBar {
                id:                 tabBar
                Layout.fillWidth:   true
            }

            // Grid tab
            ColumnLayout {
                Layout.fillWidth:   true
                spacing:            _margin
                visible:            tabBar.currentIndex === 0

                QGCLabel {
                    Layout.fillWidth:   true
                    text:               qsTr("CẢNH BÁO: Khoảng thời gian chụp ảnh dưới mức tối thiểu (%1 giây) được hỗ trợ bởi máy ảnh.").arg(_cameraMinTriggerInterval.toFixed(1))
                    wrapMode:           Text.WordWrap
                    color:              qgcPal.warningText
                    visible:            _missionItem.cameraShots > 0 && _cameraMinTriggerInterval !== 0 && _cameraMinTriggerInterval > _missionItem.timeBetweenShots
                }

                CameraCalcGrid {
                    Layout.fillWidth:               true
                    cameraCalc:                     _missionItem.cameraCalc
                    vehicleFlightIsFrontal:         true
                    distanceToSurfaceLabel:         qsTr("Độ Cao")
                    frontalDistanceLabel:           qsTr("Khoảng Cách Kích Hoạt")
                    sideDistanceLabel:              qsTr("Khoảng Cách")
                }

                SectionHeader {
                    id:                 transectValuesHeader
                    Layout.fillWidth:   true
                    text:               transectValuesHeaderName
                }

                Loader {
                    Layout.fillWidth:   true
                    visible:            transectValuesHeader.checked
                    sourceComponent:    transectValuesComponent

                    property bool forPresets: false
                }

                QGCButton {
                    Layout.alignment:   Qt.AlignHCenter
                    text:               qsTr("Xoay Điểm Nhập")
                    onClicked:          _missionItem.rotateEntryPoint()
                    visible:            transectValuesHeader.checked
                }

                SectionHeader {
                    id:                 statsHeader
                    Layout.fillWidth:   true
                    text:               qsTr("Thống Kê")
                }

                TransectStyleComplexItemStats {
                    Layout.fillWidth:   true
                    visible:            statsHeader.checked
                }
            } // Grid Column

            // Camera Tab
            CameraCalcCamera {
                Layout.fillWidth:   true
                visible:            tabBar.currentIndex === 1
                cameraCalc:         _missionItem.cameraCalc
            }

            // Terrain Tab
            TransectStyleComplexItemTerrainFollow {
                Layout.fillWidth:   true
                spacing:            _margin
                visible:            tabBar.currentIndex === 2
                missionItem:        _missionItem
            }

            // Presets Tab
            ColumnLayout {
                Layout.fillWidth:   true
                spacing:            _margin
                visible:            tabBar.currentIndex === 3

                QGCLabel {
                    Layout.fillWidth:   true
                    text:               qsTr("Tùy Chỉnh")
                    wrapMode:           Text.WordWrap
                }

                QGCComboBox {
                    id:                 presetCombo
                    Layout.fillWidth:   true
                    model:              _missionItem.presetNames
                }

                RowLayout {
                    Layout.fillWidth:   true

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Áp Dụng Tùy Chỉnh")
                        enabled:            _missionItem.presetNames.length != 0
                        onClicked:          _missionItem.loadPreset(presetCombo.textAt(presetCombo.currentIndex))
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Xóa Tùy Chỉnh")
                        enabled:            _missionItem.presetNames.length != 0
                        onClicked:          deletePresetDialog.createObject(mainWindow, { presetName: presetCombo.textAt(presetCombo.currentIndex) }).open()

                        Component {
                            id: deletePresetDialog

                            QGCSimpleMessageDialog {
                                title:      qsTr("Xóa Tùy Chỉnh")
                                text:       qsTr("Bạn có chắc chắn muốn xóa tùy chỉnh '%1' không?").arg(presetName)
                                buttons:    StandardButton.Yes | StandardButton.No

                                property string presetName

                                onAccepted: { _missionItem.deletePreset(presetName) }
                            }
                        }
                    }
                }

                Item { height: ScreenTools.defaultFontPixelHeight; width: 1 }

                QGCButton {
                    Layout.alignment:   Qt.AlignCenter
                    Layout.fillWidth:   true
                    text:               qsTr("Lưu Cài Đặt Mới Là Tùy Chỉnh")
                    onClicked:          savePresetDialog.createObject(mainWindow).open()
                }

                SectionHeader {
                    id:                 presectsTransectValuesHeader
                    Layout.fillWidth:   true
                    text:               transectValuesHeaderName
                    visible:            !!presetsTransectValuesComponent
                }

                Loader {
                    Layout.fillWidth:   true
                    visible:            presectsTransectValuesHeader.checked && !!presetsTransectValuesComponent
                    sourceComponent:    presetsTransectValuesComponent

                    property bool forPresets: true
                }

                SectionHeader {
                    id:                 presetsStatsHeader
                    Layout.fillWidth:   true
                    text:               qsTr("Thống Kê")
                }

                TransectStyleComplexItemStats {
                    Layout.fillWidth:   true
                    visible:            presetsStatsHeader.checked
                }
            } // Main editing column
        } // Top level  Column

        Component {
            id: savePresetDialog

            QGCPopupDialog {
                id:         popupDialog
                title:      qsTr("Lưu Tùy Chỉnh")
                buttons:    StandardButton.Save | StandardButton.Cancel

                onAccepted: {
                    if (presetNameField.text != "") {
                        _missionItem.savePreset(presetNameField.text.trim())
                    } else {
                        preventClose = true
                    }
                }

                ColumnLayout {
                    width:      ScreenTools.defaultFontPixelWidth * 30
                    spacing:    ScreenTools.defaultFontPixelHeight

                    QGCLabel {
                        Layout.fillWidth:   true
                        text:               qsTr("Lưu các cài đặt hiện tại dưới dạng tùy chỉnh có tên.")
                        wrapMode:           Text.WordWrap
                    }

                    QGCLabel {
                        text: qsTr("Tên Tùy Chỉnh")
                    }

                    QGCTextField {
                        id:                 presetNameField
                        Layout.fillWidth:   true
                        placeholderText:    qsTr("Nhập tên tùy chỉnh")

                        Component.onCompleted:  validateText(presetNameField.text)
                        onTextChanged:          validateText(text)

                        function validateText(text) {
                            if (text.trim() === "") {
                                nameError.text = qsTr("Tên tùy chỉnh không thể trống.")
                                popupDialog.acceptButtonEnabled = false
                            } else if (text.includes("/")) {
                                nameError.text = qsTr("Tên tùy chỉnh không thể bao gồm ký tự \"/\".")
                                popupDialog.acceptButtonEnabled = false
                            } else {
                                nameError.text = ""
                                popupDialog.acceptButtonEnabled = true
                            }
                        }
                    }

                    QGCLabel {
                        id:                 nameError
                        Layout.fillWidth:   true
                        wrapMode:           Text.WordWrap
                        color:              QGroundControl.globalPalette.warningText
                        visible:            text !== ""
                    }
                }
            }
        }
    }
}
