/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.3
import QtQuick.Controls 2.4
import QtQuick.Dialogs  1.2
import QtQuick.Layouts  1.11

import QGroundControl               1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controllers   1.0
import QGroundControl.Palette       1.0

SetupPage {
    id:             radioPage
    pageComponent:  pageComponent

    Component {
        id: pageComponent

        Item {
            width:  availableWidth
            height: Math.max(leftColumn.height, rightColumn.height)

            function setupPageCompleted() {
                controller.start()
                updateChannelCount()
            }

            function updateChannelCount()
            {
            }

            QGCPalette { id: qgcPal; colorGroupEnabled: radioPage.enabled }

            RadioComponentController {
                id:             controller
                statusText:     statusText
                cancelButton:   cancelButton
                nextButton:     nextButton
                skipButton:     skipButton
                onChannelCountChanged:              updateChannelCount()
                onFunctionMappingChangedAPMReboot:  mainWindow.showMessageDialog(qsTr("Yêu cầu khởi động lại"), qsTr("Cấu hình điều khiển của bạn đã thay đổi, bạn phải khởi động lại phương tiện để hoạt động chính xác."))
                onThrottleReversedCalFailure:       mainWindow.showMessageDialog(qsTr("Kênh ga bị đảo ngược"), qsTr("Hiệu chuẩn thất bại. Kênh ga trên bộ phát của bạn bị đảo ngược. Bạn phải sửa lỗi này trên bộ phát để hoàn tất hiệu chuẩn."))
            }

            Component {
                id: spektrumBindDialogComponent

                QGCPopupDialog {
                    title:      qsTr("Ghép nối Spektrum")
                    buttons:    StandardButton.Ok | StandardButton.Cancel

                    onAccepted: { controller.spektrumBindMode(radioGroup.checkedButton.bindMode) }

                    ButtonGroup { id: radioGroup }

                    ColumnLayout {
                        spacing: ScreenTools.defaultFontPixelHeight / 2

                        QGCLabel {
                            wrapMode:   Text.WordWrap
                            text:       qsTr("Nhấn Ok để đặt bộ thu Spektrum vào chế độ ghép nối.")
                        }

                        QGCLabel {
                            wrapMode:   Text.WordWrap
                            text:       qsTr("Chọn loại bộ thu cụ thể bên dưới:")
                        }

                        QGCRadioButton {
                            text:               qsTr("Chế độ DSM2")
                            ButtonGroup.group:  radioGroup
                            property int bindMode: RadioComponentController.DSM2
                        }

                        QGCRadioButton {
                            text:               qsTr("DSMX (7 kênh hoặc ít hơn)")
                            ButtonGroup.group:  radioGroup
                            property int bindMode: RadioComponentController.DSMX7
                        }

                        QGCRadioButton {
                            checked:            true
                            text:               qsTr("DSMX (8 kênh hoặc nhiều hơn)")
                            ButtonGroup.group:  radioGroup
                            property int bindMode: RadioComponentController.DSMX8
                        }
                    }
                }
            }

            // Live channel monitor control component
            Component {
                id: channelMonitorDisplayComponent

                Item {
                    property int    rcValue:    1500


                    property int            __lastRcValue:      1500
                    readonly property int   __rcValueMaxJitter: 2
                    property color          __barColor:         qgcPal.windowShade

                    readonly property int _pwmMin:      800
                    readonly property int _pwmMax:      2200
                    readonly property int _pwmRange:    _pwmMax - _pwmMin

                    // Bar
                    Rectangle {
                        id:                     bar
                        anchors.verticalCenter: parent.verticalCenter
                        width:                  parent.width
                        height:                 parent.height / 2
                        color:                  __barColor
                    }

                    // Center point
                    Rectangle {
                        anchors.horizontalCenter:   parent.horizontalCenter
                        width:                      globals.defaultTextWidth / 2
                        height:                     parent.height
                        color:                      qgcPal.window
                    }

                    // Indicator
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width:                  parent.height * 0.75
                        height:                 width
                        radius:                 width / 2
                        color:                  qgcPal.text
                        visible:                mapped
                        x:                      (((reversed ? _pwmMax - rcValue : rcValue - _pwmMin) / _pwmRange) * parent.width) - (width / 2)
                    }

                    QGCLabel {
                        anchors.fill:           parent
                        horizontalAlignment:    Text.AlignHCenter
                        verticalAlignment:      Text.AlignVCenter
                        text:                   qsTr("Chưa được ánh xạ")
                        visible:                !mapped
                    }

                    ColorAnimation {
                        id:         barAnimation
                        target:     bar
                        property:   "color"
                        from:       "yellow"
                        to:         __barColor
                        duration:   1500
                    }
                }
            } // Component - channelMonitorDisplayComponent

            // Left side column
            Column {
                id:             leftColumn
                anchors.left:   parent.left
                anchors.right:  columnSpacer.left
                spacing:        10

                // Attitude Controls
                Column {
                    width:      parent.width
                    spacing:    5
                    QGCLabel { text: qsTr("Điều khiển góc độ") }

                    Item {
                        width:  parent.width
                        height: globals.defaultTextHeight * 2
                        QGCLabel {
                            id:     rollLabel
                            width:  globals.defaultTextWidth * 10
                            text:   qsTr("Lăn")
                        }

                        Loader {
                            id:                 rollLoader
                            anchors.left:       rollLabel.right
                            anchors.right:      parent.right
                            height:             globals.defaultTextHeight
                            width:              100
                            sourceComponent:    channelMonitorDisplayComponent

                            property bool mapped:           controller.rollChannelMapped
                            property bool reversed:         controller.rollChannelReversed
                        }

                        Connections {
                            target: controller

                            onRollChannelRCValueChanged: rollLoader.item.rcValue = rcValue
                        }
                    }

                    Item {
                        width:  parent.width
                        height: globals.defaultTextHeight * 2

                        QGCLabel {
                            id:     pitchLabel
                            width:  globals.defaultTextWidth * 10
                            text:   qsTr("Nghiêng")
                        }

                        Loader {
                            id:                 pitchLoader
                            anchors.left:       pitchLabel.right
                            anchors.right:      parent.right
                            height:             globals.defaultTextHeight
                            width:              100
                            sourceComponent:    channelMonitorDisplayComponent

                            property bool mapped:           controller.pitchChannelMapped
                            property bool reversed:         controller.pitchChannelReversed
                        }

                        Connections {
                            target: controller

                            onPitchChannelRCValueChanged: pitchLoader.item.rcValue = rcValue
                        }
                    }

                    Item {
                        width:  parent.width
                        height: globals.defaultTextHeight * 2

                        QGCLabel {
                            id:     yawLabel
                            width:  globals.defaultTextWidth * 10
                            text:   qsTr("Quay")
                        }

                        Loader {
                            id:                 yawLoader
                            anchors.left:       yawLabel.right
                            anchors.right:      parent.right
                            height:             globals.defaultTextHeight
                            width:              100
                            sourceComponent:    channelMonitorDisplayComponent

                            property bool mapped:           controller.yawChannelMapped
                            property bool reversed:         controller.yawChannelReversed
                        }

                        Connections {
                            target: controller

                            onYawChannelRCValueChanged: yawLoader.item.rcValue = rcValue
                        }
                    }

                    Item {
                        width:  parent.width
                        height: globals.defaultTextHeight * 2

                        QGCLabel {
                            id:     throttleLabel
                            width:  globals.defaultTextWidth * 10
                            text:   qsTr("Ga")
                        }

                        Loader {
                            id:                 throttleLoader
                            anchors.left:       throttleLabel.right
                            anchors.right:      parent.right
                            height:             globals.defaultTextHeight
                            width:              100
                            sourceComponent:    channelMonitorDisplayComponent

                            property bool mapped:           controller.throttleChannelMapped
                            property bool reversed:         controller.throttleChannelReversed
                        }

                        Connections {
                            target:                             controller
                            onThrottleChannelRCValueChanged:    throttleLoader.item.rcValue = rcValue
                        }
                    }
                } // Column - Attitude Control labels

                // Command Buttons
                Row {
                    spacing: 10

                    QGCButton {
                        id:         skipButton
                        text:       qsTr("Bỏ qua")
                        onClicked:  controller.skipButtonClicked()
                    }

                    QGCButton {
                        id:         cancelButton
                        text:       qsTr("Hủy")
                        onClicked:  controller.cancelButtonClicked()
                    }

                    QGCButton {
                        id:         nextButton
                        primary:    true
                        text:       qsTr("Hiệu chuẩn")

                        onClicked: {
                            if (text === qsTr("Hiệu chuẩn")) {
                                if (controller.channelCount < controller.minChannelCount) {
                                    mainWindow.showMessageDialog(qsTr("Radio chưa sẵn sàng"),
                                                                 controller.channelCount == 0 ? qsTr("Vui lòng bật bộ phát.") :
                                                                                                (controller.channelCount < controller.minChannelCount ?
                                                                                                     qsTr("Cần %1 kênh hoặc nhiều hơn để bay.").arg(controller.minChannelCount) :
                                                                                                     qsTr("Sẵn sàng hiệu chuẩn.")))
                                } else {
                                    mainWindow.showMessageDialog(qsTr("Đặt lại cân bằng"),
                                                                 qsTr("Trước khi hiệu chuẩn, bạn nên đặt lại tất cả các cân bằng và cân bằng phụ về không. Nhấn Ok để bắt đầu hiệu chuẩn.\n\n%1").arg(
                                                                     (QGroundControl.multiVehicleManager.activeVehicle.px4Firmware ? "" : qsTr("Vui lòng đảm bảo tất cả nguồn động cơ đã được ngắt kết nối VÀ tất cả cánh quạt đã được tháo khỏi phương tiện."))),
                                                                 StandardButton.Ok,
                                                                 function() { controller.nextButtonClicked() })
                                }
                            } else {
                                controller.nextButtonClicked()
                            }
                        }
                    }
                } // Row - Buttons

                // Status Text
                QGCLabel {
                    id:         statusText
                    width:      parent.width
                    wrapMode:   Text.WordWrap
                }

                Rectangle {
                    width:          parent.width
                    height:         1
                    border.color:   qgcPal.text
                    border.width:   1
                }

                QGCLabel { text: qsTr("Cài đặt Radio bổ sung:") }

                GridLayout {
                    id:                 switchSettingsGrid
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    columns:            2
                    columnSpacing:      ScreenTools.defaultFontPixelWidth

                    Repeater {
                        model: QGroundControl.multiVehicleManager.activeVehicle.px4Firmware ?
                                   (QGroundControl.multiVehicleManager.activeVehicle.multiRotor ?
                                        [ "RC_MAP_AUX1", "RC_MAP_AUX2", "RC_MAP_PARAM1", "RC_MAP_PARAM2", "RC_MAP_PARAM3"] :
                                        [ "RC_MAP_FLAPS", "RC_MAP_AUX1", "RC_MAP_AUX2", "RC_MAP_PARAM1", "RC_MAP_PARAM2", "RC_MAP_PARAM3"]) :
                                   0

                        RowLayout {
                            Layout.fillWidth: true

                            property Fact fact: controller.getParameterFact(-1, modelData)

                            QGCLabel {
                                Layout.fillWidth:   true
                                text:               fact.shortDescription
                            }
                            FactComboBox {
                                width:      ScreenTools.defaultFontPixelWidth * 15
                                fact:       parent.fact
                                indexModel: false
                            }
                        }
                    }
                }

                RowLayout {
                    QGCButton {
                        id:         bindButton
                        text:       qsTr("Ghép nối Spektrum")
                        onClicked:  spektrumBindDialogComponent.createObject(mainWindow).open()
                    }

                    QGCButton {
                        text:       qsTr("Sao chép cân bằng")
                        onClicked:  mainWindow.showMessageDialog(qsTr("Sao chép cân bằng"),
                                                                 qsTr("Đặt các cần điều khiển vào giữa và đẩy ga xuống hoàn toàn, sau đó nhấn Ok để sao chép cân bằng. Sau khi nhấn Ok, đặt lại cân bằng trên radio của bạn về không."),
                                                                 StandardButton.Ok | StandardButton.Cancel,
                                                                 function() { controller.copyTrims() })
                    }
                }
            } // Column - Left Column

            Item {
                id:             columnSpacer
                anchors.right:  rightColumn.left
                width:         20
            }

            // Right side column
            Column {
                id:             rightColumn
                anchors.top:    parent.top
                anchors.right:  parent.right
                width:          ScreenTools.defaultFontPixelWidth * 40
                spacing:        ScreenTools.defaultFontPixelHeight / 2

                Row {
                    spacing: ScreenTools.defaultFontPixelWidth

                    QGCRadioButton {
                        text:       qsTr("Chế độ 1")
                        checked:    controller.transmitterMode == 1
                        onClicked:  controller.transmitterMode = 1
                    }

                    QGCRadioButton {
                        text:       qsTr("Chế độ 2")
                        checked:    controller.transmitterMode == 2
                        onClicked:  controller.transmitterMode = 2
                    }
                }

                Image {
                    width:      parent.width
                    fillMode:   Image.PreserveAspectFit
                    smooth:     true
                    source:     controller.imageHelp
                }

                RCChannelMonitor {
                    width:      parent.width
                    twoColumn:  true
                }
            } // Column - Right Column
        } // Item
    } // Component - pageComponent
} // SetupPage
