/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick          2.11
import QtQuick.Controls 2.4
import QtQuick.Layouts  1.11

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.ScreenTools   1.0

Rectangle {
    color:          qgcPal.window
    anchors.fill:   parent

    readonly property real _margins: ScreenTools.defaultFontPixelHeight

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    QGCFlickable {
        anchors.fill:   parent
        contentWidth:   column.width  + (_margins * 2)
        contentHeight:  column.height + (_margins * 2)
        clip:           true

        ColumnLayout {
            id:                 column
            anchors.margins:    _margins
            anchors.left:       parent.left
            anchors.top:        parent.top
            spacing:            ScreenTools.defaultFontPixelHeight

            QGCCheckBox {
                id:             sendStatusText
                text:           qsTr("Gửi trạng thái văn bản + giọng nói")
            }
            QGCButton {
                text:               qsTr("Phương tiện PX4")
                Layout.fillWidth:   true
                onClicked:          QGroundControl.startPX4MockLink(sendStatusText.checked)
            }
            QGCButton {
                text:               qsTr("Phương tiện APM ArduCopter")
                visible:            QGroundControl.hasAPMSupport
                Layout.fillWidth:   true
                onClicked:          QGroundControl.startAPMArduCopterMockLink(sendStatusText.checked)
            }
            QGCButton {
                text:               qsTr("Phương tiện APM ArduPlane")
                visible:            QGroundControl.hasAPMSupport
                Layout.fillWidth:   true
                onClicked:          QGroundControl.startAPMArduPlaneMockLink(sendStatusText.checked)
            }
            QGCButton {
                text:               qsTr("Phương tiện APM ArduSub")
                visible:            QGroundControl.hasAPMSupport
                Layout.fillWidth:   true
                onClicked:          QGroundControl.startAPMArduSubMockLink(sendStatusText.checked)
            }
            QGCButton {
                text:               qsTr("Phương tiện APM ArduRover")
                visible:            QGroundControl.hasAPMSupport
                Layout.fillWidth:   true
                onClicked:          QGroundControl.startAPMArduRoverMockLink(sendStatusText.checked)
            }
            QGCButton {
                text:               qsTr("Phương tiện Generic")
                Layout.fillWidth:   true
                onClicked:          QGroundControl.startGenericMockLink(sendStatusText.checked)
            }
            QGCButton {
                text:               qsTr("Dừng Một MockLink")
                Layout.fillWidth:   true
                onClicked:          QGroundControl.stopOneMockLink()
            }
        }
    }
}
