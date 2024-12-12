import QtQuick          2.3
import QtQuick.Controls 1.2

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controls      1.0

QGCFlickable {
    height:         outerEditorRect.height
    contentHeight:  outerEditorRect.height
    clip:           true

    property var controller ///< RallyPointController

    readonly property real  _margin: ScreenTools.defaultFontPixelWidth / 2
    readonly property real  _radius: ScreenTools.defaultFontPixelWidth / 2

    Rectangle {
        id:     outerEditorRect
        width:  parent.width
        height: innerEditorRect.y + innerEditorRect.height + (_margin * 2)
        radius: _radius
        color:  qgcPal.missionItemEditor

        QGCLabel {
            id:                 editorLabel
            anchors.margins:    _margin
            anchors.left:       parent.left
            anchors.top:        parent.top
            text:               qsTr("Điểm Rally")
        }

        Rectangle {
            id:                 innerEditorRect
            anchors.margins:    _margin
            anchors.left:       parent.left
            anchors.right:      parent.right
            anchors.top:        editorLabel.bottom
            height:             infoLabel.height + (_margin * 2)
            color:              qgcPal.windowShadeDark
            radius:             _radius

            QGCLabel {
                id:                 infoLabel
                anchors.margins:    _margin
                anchors.top:        parent.top
                anchors.left:       parent.left
                anchors.right:      parent.right
                wrapMode:           Text.WordWrap
                font.pointSize:     ScreenTools.smallFontPointSize
                text:               qsTr("Rally Points cung cấp các điểm hạ cánh thay thế khi thực hiện tính năng Quay lại điểm khởi hành (RTL).")
            }

            /*
            QGCLabel {
                id:                 helpLabel
                anchors.margins:    _margin
                anchors.left:       parent.left
                anchors.right:      parent.right
                anchors.top:        infoLabel.bottom
                wrapMode:           Text.WordWrap
                text:               controller.supported ?
                                        qsTr("Nhấn vào bản đồ để thêm các điểm rally mới.") :
                                        qsTr("Thiết bị bay này không hỗ trợ các điểm rally.")
            }
            */
        }
    }
}
