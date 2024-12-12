import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Layouts  1.2
import QtPositioning    5.2

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0

QGCFlickable {
    id:             root
    contentHeight:  geoFenceEditorRect.height
    clip:           true

    property var    myGeoFenceController
    property var    flightMap

    readonly property real  _editFieldWidth:    Math.min(width - _margin * 2, ScreenTools.defaultFontPixelWidth * 15)
    readonly property real  _margin:            ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _radius:            ScreenTools.defaultFontPixelWidth / 2

    Rectangle {
        id:     geoFenceEditorRect
        anchors.left:   parent.left
        anchors.right:  parent.right
        height: geoFenceItems.y + geoFenceItems.height + (_margin * 2)
        radius: _radius
        color:  qgcPal.missionItemEditor

        QGCLabel {
            id:                 geoFenceLabel
            anchors.margins:    _margin
            anchors.left:       parent.left
            anchors.top:        parent.top
            text:               qsTr("GeoFence (Hàng rào địa lý)")
            anchors.leftMargin: ScreenTools.defaultFontPixelWidth
        }

        Rectangle {
            id:                 geoFenceItems
            anchors.margins:    _margin
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        geoFenceLabel.bottom
            height:             fenceColumn.y + fenceColumn.height + (_margin * 2)
            color:              qgcPal.windowShadeDark
            radius:             _radius

            Column {
                id:                 fenceColumn
                anchors.margins:    _margin
                anchors.top:        parent.top
                anchors.left:       parent.left
                anchors.right:      parent.right
                spacing:            _margin

                QGCLabel {
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    wrapMode:           Text.WordWrap
                    font.pointSize:     myGeoFenceController.supported ? ScreenTools.smallFontPointSize : ScreenTools.defaultFontPointSize
                    text:               myGeoFenceController.supported ?
                                            qsTr("GeoFencing cho phép bạn thiết lập một hàng rào ảo xung quanh khu vực bạn muốn bay.") :
                                            qsTr("Thiết bị bay này không hỗ trợ GeoFence.")
                }

                Column {
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    spacing:            _margin
                    visible:            myGeoFenceController.supported

                    Repeater {
                        model: myGeoFenceController.params

                        Item {
                            width:  fenceColumn.width
                            height: textField.height

                            property bool showCombo: modelData.enumStrings.length > 0

                            QGCLabel {
                                id:                 textFieldLabel
                                anchors.baseline:   textField.baseline
                                text:               myGeoFenceController.paramLabels[index]
                            }

                            FactTextField {
                                id:             textField
                                anchors.right:  parent.right
                                width:          _editFieldWidth
                                showUnits:      true
                                fact:           modelData
                                visible:        !parent.showCombo
                            }

                            FactComboBox {
                                id:             comboField
                                anchors.right:  parent.right
                                width:          _editFieldWidth
                                indexModel:     false
                                fact:           showCombo ? modelData : _nullFact
                                visible:        parent.showCombo

                                property var _nullFact: Fact { }
                            }
                        }
                    }

                    SectionHeader {
                        id:             insertSection
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        text:           qsTr("Chèn GeoFence")
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Rào chắn đa giác")

                        onClicked: {
                            var rect = Qt.rect(flightMap.centerViewport.x, flightMap.centerViewport.y, flightMap.centerViewport.width, flightMap.centerViewport.height)
                            var topLeftCoord = flightMap.toCoordinate(Qt.point(rect.x, rect.y), false /* clipToViewPort */)
                            var bottomRightCoord = flightMap.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height), false /* clipToViewPort */)
                            myGeoFenceController.addInclusionPolygon(topLeftCoord, bottomRightCoord)
                        }
                    }

                    QGCButton {
                        Layout.fillWidth:   true
                        text:               qsTr("Rào chắn hình tròn")

                        onClicked: {
                            var rect = Qt.rect(flightMap.centerViewport.x, flightMap.centerViewport.y, flightMap.centerViewport.width, flightMap.centerViewport.height)
                            var topLeftCoord = flightMap.toCoordinate(Qt.point(rect.x, rect.y), false /* clipToViewPort */)
                            var bottomRightCoord = flightMap.toCoordinate(Qt.point(rect.x + rect.width, rect.y + rect.height), false /* clipToViewPort */)
                            myGeoFenceController.addInclusionCircle(topLeftCoord, bottomRightCoord)
                        }
                    }

                    SectionHeader {
                        id:             polygonSection
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        text:           qsTr("Rào chắn đa giác")
                    }

                    QGCLabel {
                        text:       qsTr("Không có")
                        visible:    polygonSection.checked && myGeoFenceController.polygons.count === 0
                    }

                    GridLayout {
                        Layout.fillWidth:   true
                        columns:            3
                        flow:               GridLayout.TopToBottom
                        visible:            polygonSection.checked && myGeoFenceController.polygons.count > 0

                        QGCLabel {
                            text:               qsTr("Bao gồm")
                            Layout.column:      0
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.polygons

                            QGCCheckBox {
                                checked:            object.inclusion
                                onClicked:          object.inclusion = checked
                                Layout.alignment:   Qt.AlignHCenter
                            }
                        }

                        QGCLabel {
                            text:               qsTr("Sửa")
                            Layout.column:      1
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.polygons

                            QGCRadioButton {
                                checked:            _interactive
                                Layout.alignment:   Qt.AlignHCenter

                                property bool _interactive: object.interactive

                                on_InteractiveChanged: checked = _interactive

                                onClicked: {
                                    myGeoFenceController.clearAllInteractive()
                                    object.interactive = checked
                                }
                            }
                        }

                        QGCLabel {
                            text:               qsTr("Xóa")
                            Layout.column:      2
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.polygons

                            QGCButton {
                                text:               qsTr("Del")
                                Layout.alignment:   Qt.AlignHCenter
                                onClicked:          myGeoFenceController.deletePolygon(index)
                            }
                        }
                    } // GridLayout

                    SectionHeader {
                        id:             circleSection
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        text:           qsTr("Hàng rào tròn")
                    }

                    QGCLabel {
                        text:       qsTr("Không có")
                        visible:    circleSection.checked && myGeoFenceController.circles.count === 0
                    }

                    GridLayout {
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        columns:            4
                        flow:               GridLayout.TopToBottom
                        visible:            polygonSection.checked && myGeoFenceController.circles.count > 0

                        QGCLabel {
                            text:               qsTr("Bao gồm")
                            Layout.column:      0
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.circles

                            QGCCheckBox {
                                checked:            object.inclusion
                                onClicked:          object.inclusion = checked
                                Layout.alignment:   Qt.AlignHCenter
                            }
                        }

                        QGCLabel {
                            text:               qsTr("Sửa")
                            Layout.column:      1
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.circles

                            QGCRadioButton {
                                checked:            _interactive
                                Layout.alignment:   Qt.AlignHCenter

                                property bool _interactive: object.interactive

                                on_InteractiveChanged: checked = _interactive

                                onClicked: {
                                    myGeoFenceController.clearAllInteractive()
                                    object.interactive = checked
                                }
                            }
                        }

                        QGCLabel {
                            text:               qsTr("Bán kính")
                            Layout.column:      2
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.circles

                            FactTextField {
                                fact:               object.radius
                                Layout.fillWidth:   true
                                Layout.alignment:   Qt.AlignHCenter
                            }
                        }

                        QGCLabel {
                            text:               qsTr("Xóa")
                            Layout.column:      3
                            Layout.alignment:   Qt.AlignHCenter
                        }

                        Repeater {
                            model: myGeoFenceController.circles

                            QGCButton {
                                text:               qsTr("Del")
                                Layout.alignment:   Qt.AlignHCenter
                                onClicked:          myGeoFenceController.deleteCircle(index)
                            }
                        }
                    } // GridLayout

                    SectionHeader {
                        id:             breachReturnSection
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        text:           qsTr("Điểm quay về khi vi phạm")
                    }

                    QGCButton {
                        text:               qsTr("Thêm điểm quay về khi vi phạm")
                        visible:            breachReturnSection.visible && !myGeoFenceController.breachReturnPoint.isValid
                        anchors.left:       parent.left
                        anchors.right:      parent.right

                        onClicked: myGeoFenceController.breachReturnPoint = flightMap.center
                    }

                    QGCButton {
                        text:               qsTr("Xóa điểm quay về khi vi phạm")
                        visible:            breachReturnSection.visible && myGeoFenceController.breachReturnPoint.isValid
                        anchors.left:       parent.left
                        anchors.right:      parent.right

                        onClicked: myGeoFenceController.breachReturnPoint = QtPositioning.coordinate()
                    }

                    ColumnLayout {
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        spacing:            _margin
                        visible:            breachReturnSection.visible && myGeoFenceController.breachReturnPoint.isValid

                        QGCLabel {
                            text: qsTr("Độ cao")
                        }

                        FactTextField {
                            fact: myGeoFenceController.breachReturnAltitude
                        }
                    }

                }
            }
        }
    } // Rectangle
}
