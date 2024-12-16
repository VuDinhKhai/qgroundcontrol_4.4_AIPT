/****************************************************************************
 *
 * (c) 2009-2021 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick              2.3
import QtQuick.Controls     1.2
import QtQuick.Dialogs      1.2

import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Controllers   1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0

Item {
    id: _root

    property var  _autotune:   globals.activeVehicle.autotune
    property real _margins:    ScreenTools.defaultFontPixelHeight

    readonly property string dialogTitle: qsTr("Tự động điều chỉnh")

    QGCPalette {
        id:                palette
        colorGroupEnabled: enabled
    }

    Rectangle {
        width:   _root.width
        height:  statusColumn.height + (2 * _margins)
        color:   palette.windowShade
        enabled: _autotune.autotuneEnabled

        QGCButton {
            id:        autotuneButton
            primary:   true
            text:      dialogTitle
            enabled:   !_autotune.autotuneInProgress
            anchors {
                left:             parent.left
                leftMargin:       _margins
                verticalCenter:   parent.verticalCenter
            }

            onClicked: mainWindow.showMessageDialog(dialogTitle,
                                                    qsTr("CẢNH BÁO!\
            \n\nQuy trình tự động điều chỉnh phải được thực hiện một cách thận trọng và yêu cầu phương tiện phải bay đủ ổn định trước khi thực hiện quy trình! \
            \n\nTrước khi bắt đầu quá trình tự động điều chỉnh, hãy đảm bảo rằng: \
            \n1. Bạn đã đọc hướng dẫn tự động điều chỉnh và đã làm theo các bước sơ bộ \
            \n2. Các mức tăng kiểm soát hiện tại đủ tốt để ổn định máy bay không người lái khi có nhiễu động trung bình \
            \n3. Bạn đã sẵn sàng hủy bỏ trình tự điều chỉnh tự động bằng cách di chuyển cần điều khiển RC nếu có bất kỳ điều gì bất ngờ xảy ra. \
            \n\nNhấn vào Ok để bắt đầu quá trình tự động điều chỉnh.\n"),
                                                    StandardButton.Ok | StandardButton.Cancel,
                                                    function() { _autotune.autotuneRequest() })
        }

        Column {
            id:      statusColumn
            spacing: _margins
            anchors  {
                left:             autotuneButton.right
                right:            parent.right
                leftMargin:       _margins
                rightMargin:      _margins
                verticalCenter:   parent.verticalCenter
            }

            QGCLabel {
                text:   _autotune.autotuneStatus

                anchors {
                    left: parent.left
                }
            }

            ProgressBar {
                value:   _autotune.autotuneProgress

                anchors {
                    left:             parent.left
                    right:            parent.right
                }
            }
        }
    }
}
