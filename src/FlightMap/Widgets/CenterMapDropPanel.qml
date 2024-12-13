/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.3
import QtQuick.Controls 1.2
import QtQuick.Layouts  1.2
import QtPositioning    5.3

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0

ColumnLayout {
    id:         root
    spacing:    ScreenTools.defaultFontPixelWidth * 0.5

    property var    map
    property var    fitFunctions
    property bool   showMission:          true
    property bool   showAllItems:         true

    QGCLabel { text: qsTr("Trung tâm bản đồ trên:") }

    QGCButton {
        text:               qsTr("Nhiệm vụ")
        Layout.fillWidth:   true
        visible:            showMission

        onClicked: {
            dropPanel.hide()
            fitFunctions.fitMapViewportToMissionItems()
        }
    }

    QGCButton {
        text:               qsTr("Tất cả các mục")
        Layout.fillWidth:   true
        visible:            showAllItems

        onClicked: {
            dropPanel.hide()
            fitFunctions.fitMapViewportToAllItems()
        }
    }

    QGCButton {
        text:               qsTr("Khởi động")
        Layout.fillWidth:   true

        onClicked: {
            dropPanel.hide()
            map.center = fitFunctions.fitHomePosition()
        }
    }

    QGCButton {
        text:               qsTr("Phương tiện")
        Layout.fillWidth:   true
        enabled:            globals.activeVehicle && globals.activeVehicle.coordinate.isValid

        onClicked: {
            dropPanel.hide()
            map.center = globals.activeVehicle.coordinate
        }
    }

    QGCButton {
        text:               qsTr("Vị trí hiện tại")
        Layout.fillWidth:   true
        enabled:            map.gcsPosition.isValid

        onClicked: {
            dropPanel.hide()
            map.center = map.gcsPosition
        }
    }

    QGCButton {
        text:               qsTr("Vị trí được chỉ định")
        Layout.fillWidth:   true

        onClicked: {
            dropPanel.hide()
            map.centerToSpecifiedLocation()
        }
    }
} // Column
