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

TransectStyleComplexItemEditor {
    transectAreaDefinitionComplete: missionItem.surveyAreaPolygon.isValid
    transectAreaDefinitionHelp:     qsTr("Sử dụng các công cụ Polygon để tạo ra đa giác bao quanh khu vực khảo sát của bạn.")
    transectValuesHeaderName:       qsTr("Transects")
    transectValuesComponent:        _transectValuesComponent
    presetsTransectValuesComponent: _transectValuesComponent

    // The following properties must be available up the hierarchy chain
    //  property real   availableWidth    ///< Width for control
    //  property var    missionItem       ///< Mission Item for editor

    property real   _margin:        ScreenTools.defaultFontPixelWidth / 2
    property var    _missionItem:   missionItem

    Component {
        id: _transectValuesComponent

        GridLayout {
            Layout.fillWidth:   true
            columnSpacing:      _margin
            rowSpacing:         _margin
            columns:            2

            QGCLabel { text: qsTr("Góc") }
            FactTextField {
                fact:                   missionItem.gridAngle
                Layout.fillWidth:       true
                onUpdated:              angleSlider.value = missionItem.gridAngle.value
            }

            QGCSlider {
                id:                     angleSlider
                minimumValue:           0
                maximumValue:           359
                stepSize:               1
                tickmarksEnabled:       false
                Layout.fillWidth:       true
                Layout.columnSpan:      2
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.5
                onValueChanged:         missionItem.gridAngle.value = value
                Component.onCompleted:  value = missionItem.gridAngle.value
                updateValueWhileDragging: true
            }

            QGCLabel {
                text:       qsTr("Khoảng cách quay lại")
                visible:    !forPresets
            }
            FactTextField {
                Layout.fillWidth:   true
                fact:               missionItem.turnAroundDistance
                visible:            !forPresets
            }

            QGCOptionsComboBox {
                Layout.columnSpan:  2
                Layout.fillWidth:   true
                visible:            !forPresets

                model: [
                    {
                        text:       qsTr("Lơ lửng và chụp ảnh"),
                        fact:       missionItem.hoverAndCapture,
                        enabled:    missionItem.cameraCalc.distanceMode === QGroundControl.AltitudeModeRelative || missionItem.cameraCalc.distanceMode === QGroundControl.AltitudeModeAbsolute,
                        visible:    missionItem.hoverAndCaptureAllowed
                    },
                    {
                        text:       qsTr("Bay lại với độ lệch 90 độ"),
                        fact:       missionItem.refly90Degrees,
                        enabled:    missionItem.cameraCalc.distanceMode !== QGroundControl.AltitudeModeCalcAboveTerrain,
                        visible:    true
                    },
                    {
                        text:       qsTr("Ảnh trong các lượt quay lại"),
                        fact:       missionItem.cameraTriggerInTurnAround,
                        enabled:    missionItem.hoverAndCaptureAllowed ? !missionItem.hoverAndCapture.rawValue : true,
                        visible:    true
                    },
                    {
                        text:       qsTr("Bay các transects xen kẽ"),
                        fact:       missionItem.flyAlternateTransects,
                        enabled:    true,
                        visible:    _vehicle ? (_vehicle.fixedWing || _vehicle.vtol) : false
                    }
                ]
            }
        }
    }

    KMLOrSHPFileDialog {
        id:             kmlOrSHPLoadDialog
        title:          qsTr("Chọn Tệp Polygon")
        selectExisting: true

        onAcceptedForLoad: {
            missionItem.surveyAreaPolygon.loadKMLOrSHPFile(file)
            missionItem.resetState = false
            //editorMap.mapFitFunctions.fitMapViewportTomissionItems()
            close()
        }
    }
}
