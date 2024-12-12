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

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controllers   1.0

SetupPage {
    id:             motorPage
    pageComponent:  pageComponent
    enabled:        true

    readonly property int _barHeight:       10
    readonly property int _barWidth:        5
    readonly property int _sliderHeight:    10

    property int neutralValue: 50;
    property int _lastIndex: 0;
    property bool canRunManualTest: controller.vehicle.flightMode !== 'Motor Detection' && controller.vehicle.armed && motorPage.visible && setupView.visible
    property var shouldRunManualTest: false // Does the operator intend to run the motor test?

    APMSubMotorComponentController {
        id:             controller
    }

    function setMotorDirection(num, reversed) {
        var fact = controller.getParameterFact(-1, "MOT_" + num + "_DIRECTION")
        fact.value = reversed ? -1 : 1;
    }

    Component.onCompleted: controller.vehicle.armed = false

    Component {
        id: pageComponent

        Column {
            spacing: 10

            Row {
                id:         motorSliders
                enabled:    canRunManualTest && shouldRunManualTest
                spacing:    ScreenTools.defaultFontPixelWidth * 4

                Column {
                    spacing:    ScreenTools.defaultFontPixelWidth * 2

                    Row {
                        id: sliderRow
                        spacing:    ScreenTools.defaultFontPixelWidth * 4

                        Repeater {
                            id:         sliderRepeater
                            model:      controller.vehicle.motorCount == -1 ? 8 : controller.vehicle.motorCount

                            Column {
                                property alias motorSlider: slider
                                spacing:    ScreenTools.defaultFontPixelWidth

                                QGCLabel {
                                    anchors.horizontalCenter:   parent.horizontalCenter
                                    text:                       index + 1
                                }

                                QGCSlider {
                                    id:                         slider
                                    height:                     ScreenTools.defaultFontPixelHeight * _sliderHeight
                                    orientation:                Qt.Vertical
                                    maximumValue:               100
                                    value:                      neutralValue

                                    // Give slider 'center sprung' behavior
                                    onPressedChanged: {
                                        if (!slider.pressed) {
                                            slider.value = neutralValue
                                        }
                                        _lastIndex = index
                                    }
                                    // Disable mouse scroll
                                    MouseArea {
                                        anchors.fill: parent
                                        onWheel: {
                                            // do nothing
                                            wheel.accepted = true;
                                        }
                                        onPressed: {
                                            // propogate/accept
                                            mouse.accepted = false;
                                        }
                                        onReleased: {
                                            // propogate/accept
                                            mouse.accepted = false;
                                        }
                                    }
                                }
                            } // Column
                        } // Repeater
                    } // Row

                    QGCLabel {
                        width: parent.width
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        wrapMode:       Text.WordWrap
                        text:           qsTr("Đảo Chiều Động Cơ")
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignBottom
                    }
                    Rectangle {
                        anchors.margins: ScreenTools.defaultFontPixelWidth * 3
                        width:              parent.width
                        height:             1
                        color:              qgcPal.text
                    }

                    Row {
                        anchors.margins: ScreenTools.defaultFontPixelWidth

                        Repeater {
                            id:         cbRepeater
                            model:      controller.vehicle.motorCount == -1 ? 8 : controller.vehicle.motorCount

                            Column {
                                spacing:    ScreenTools.defaultFontPixelWidth

                                QGCCheckBox {
                                    width: sliderRow.width / (controller.vehicle.motorCount - 0.5)
                                    checked: controller.getParameterFact(-1, "MOT_" + (index + 1) + "_DIRECTION").value == -1
                                    onClicked: {
                                        sliderRepeater.itemAt(index).motorSlider.value = neutralValue
                                        setMotorDirection(index + 1, checked)
                                    }
                                }
                            } // Column
                        } // Repeater
                    } // Row
                } // Column

                // Display the frame currently in use with motor numbers
                APMSubMotorDisplay {
                    anchors.top:    parent.top
                    anchors.bottom: parent.bottom
                    width:          height
                    frameType: controller.getParameterFact(-1, "FRAME_CONFIG").value
                }
            } // Row

            QGCLabel {
                anchors.left:   parent.left
                anchors.right:  parent.right
                wrapMode:       Text.WordWrap
                text:           qsTr("Di chuyển thanh trượt sẽ khiến động cơ quay. Đảm bảo động cơ và cánh quạt không bị cản trở! Hướng quay của động cơ phụ thuộc vào cách ba pha của động cơ được kết nối vật lý với ESC (nếu hai dây bất kỳ bị hoán đổi, hướng quay sẽ đảo ngược). Vì chúng tôi không thể đảm bảo thứ tự kết nối các pha, hướng động cơ phải được cấu hình trong phần mềm. Khi thanh trượt được di chuyển XUỐNG, động cơ đẩy phải đẩy không khí/nước HƯỚNG VỀ dây cáp đi vào vỏ. Nhấp vào hộp kiểm để đảo ngược hướng của động cơ đẩy tương ứng.\n\n"
                                     + "Động cơ đẩy Blue Robotics được bôi trơn bằng nước và không được thiết kế để chạy trong không khí. Việc thử nghiệm động cơ đẩy trong không khí ở tốc độ thấp trong thời gian ngắn là được. Vận hành kéo dài Blue Robotics trong không khí có thể dẫn đến quá nhiệt và hư hỏng vĩnh viễn. Không có bôi trơn bằng nước, động cơ đẩy Blue Robotics cũng có thể phát ra một số tiếng ồn khó chịu khi hoạt động trong không khí; điều này là bình thường.")
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth
                Switch {
                    id: safetySwitch
                    onToggled: {
                        if (controller.vehicle.armed) {
                            shouldRunManualTest = false
                            enabled = false
                            coolDownTimer.start()
                        }

                        controller.vehicle.armed = checked
                        checked = controller.vehicle.armed // Makes the switch stay off if it's not possible to arm
                    }
                }

                // Make sure external changes to Armed are reflected on the switch
                Connections {
                    target: controller.vehicle
                    onArmedChanged:
                    {
                        safetySwitch.checked = armed
                            if (!armed) {
                                shouldRunManualTest = false
                                safetySwitch.enabled = false
                                coolDownTimer.start()
                            } else {
                                shouldRunManualTest = true
                            }
                            for (var sliderIndex=0; sliderIndex<sliderRepeater.count; sliderIndex++) {
                                sliderRepeater.itemAt(sliderIndex).motorSlider.value = neutralValue
                            }
                        }
                }

                QGCLabel {
                    anchors.verticalCenter: safetySwitch.verticalCenter
                    color:  qgcPal.warningText
                    text:   coolDownTimer.running
                                ? qsTr("Cần thời gian làm mát 10 giây trước khi thử lại, vui lòng chờ...")
                                : qsTr("Trượt công tắc này để kích hoạt phương tiện và bật thử động cơ (THẬN TRỌNG!)")
                }
            } // Row

            QGCLabel {
                visible:             controller.vehicle.versionCompare(4, 0, 0) >= 0
                width:               parent.width
                anchors.left:        parent.left
                anchors.right:       parent.right
                font.pointSize:      ScreenTools.largeFontPointSize
                text:                qsTr("Tự Động Phát Hiện Hướng Động Cơ")
            }

            QGCLabel {
                visible:        controller.vehicle.versionCompare(4, 0, 0) >= 0
                anchors.left:   parent.left
                anchors.right:  parent.right
                wrapMode:       Text.WordWrap
                text:           qsTr("Điều này sẽ cố gắng tự động phát hiện hướng (bình thường/đảo ngược) của động cơ đẩy của bạn.\n"
                                   + "Vui lòng đặt phương tiện của bạn trong nước, nhấp vào nút và đợi. Lưu ý rằng động cơ đẩy vẫn cần "
                                   + "được kết nối với đầu ra chính xác (ví dụ: động cơ đẩy 2 và 3 không thể hoán đổi cho nhau).")
            }

            Row {
                visible:    controller.vehicle.versionCompare(4, 0, 0) >= 0
                spacing:    ScreenTools.defaultFontPixelWidth

                Column {
                    spacing:    ScreenTools.defaultFontPixelWidth * 2

                    QGCButton {
                        id: startAutoDetection
                        text: "Tự Động Phát Hiện Hướng"
                        enabled: controller.vehicle.flightMode !== 'Motor Detection'

                        onClicked: function() {
                            controller.vehicle.flightMode = "Motor Detection"
                            controller.vehicle.armed = true
                        }
                    }
                }
                Column {
                    spacing:    ScreenTools.defaultFontPixelWidth * 2

                    Flickable {
                        id: flickable
                        width: 500
                        height: Math.min(contentHeight, 200)
                        contentWidth: width
                        contentHeight: textArea.implicitHeight
                        clip: true

                        TextArea {
                            id: textArea
                            anchors.fill: parent
                            color:  qgcPal.text
                            text: controller.motorDetectionMessages
                            wrapMode: Text.WordWrap
                            background: Rectangle {
                                color: qgcPal.window
                            }
                            onTextChanged: function() {
                                flickable.flick(0, -300)
                            }
                        }
                        ScrollBar.vertical: ScrollBar {}
                    }
                }
            }

            // Repeats the command signal and updates the checkbox every 50 ms
            Timer {
                id: timer
                interval:       50
                repeat:         true
                running:        canRunManualTest && shouldRunManualTest

                onTriggered: {
                    if (controller.vehicle.armed) {
                            var slider = sliderRepeater.itemAt(_lastIndex)

                            var reversed = controller.getParameterFact(-1, "MOT_" + (_lastIndex + 1) + "_DIRECTION").value == -1

                            if (reversed) {
                                controller.vehicle.motorTest(_lastIndex, 100 - slider.motorSlider.value, 0, false)
                            } else {
                                controller.vehicle.motorTest(_lastIndex, slider.motorSlider.value, 0, false)
                            }
                    }
                }
            }
            Timer {
                id: coolDownTimer
                interval:       11000
                repeat:         false

                onTriggered: {
                    safetySwitch.enabled = true
                }
            }
        } // Column
    } // Component
} // SetupPahe
