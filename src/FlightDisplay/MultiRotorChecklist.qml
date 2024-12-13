/****************************************************************************
 *
 *   (c) 2009-2016 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                      2.11
import QtQuick.Controls             2.4
import QtQml.Models                 2.1

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controls      1.0
import QGroundControl.FlightDisplay 1.0
import QGroundControl.Vehicle       1.0

Item {
    property var model: listModel
    PreFlightCheckModel {
        id:     listModel
        PreFlightCheckGroup {
            name: qsTr("Kiểm tra ban đầu cho Multirotor")

            PreFlightCheckButton {
                name:           qsTr("Phần cứng")
                manualText:     qsTr("Cánh quạt đã được lắp đặt và cố định?")
            }

            PreFlightBatteryCheck {
                failurePercent:                 40
                allowFailurePercentOverride:    false
            }

            PreFlightSensorsHealthCheck {
            }

            PreFlightGPSCheck {
                failureSatCount:        9
                allowOverrideSatCount:  true
            }

            PreFlightRCCheck {
            }
        }

        PreFlightCheckGroup {
            name: qsTr("Xin hãy khởi động phương tiện tại đây")

            PreFlightCheckButton {
                name:            qsTr("Động cơ")
                manualText:      qsTr("Cánh quạt có tự do? Sau đó tăng dần ga nhẹ. Hoạt động đúng không?")
            }

            PreFlightCheckButton {
                name:           qsTr("Nhiệm vụ")
                manualText:     qsTr("Xin hãy xác nhận nhiệm vụ là hợp lệ (điểm đến hợp lệ, không va chạm với địa hình).")
            }

            PreFlightSoundCheck {
            }
        }

        PreFlightCheckGroup {
            name: qsTr("Các chuẩn bị cuối cùng trước khi phóng")

            // Nhóm mục kiểm tra 2 - Kiểm tra cuối cùng trước khi phóng
            PreFlightCheckButton {
                name:           qsTr("Hàng hóa")
                manualText:     qsTr("Đã được cấu hình và khởi động? Nắp hàng hóa đã được đóng?")
            }

            PreFlightCheckButton {
                name:           qsTr("Gió & thời tiết")
                manualText:     qsTr("Có phù hợp với nền tảng của bạn không?")
            }

            PreFlightCheckButton {
                name:           qsTr("Khu vực bay")
                manualText:     qsTr("Khu vực phóng và đường bay có tự do khỏi chướng ngại vật/người không?")
            }
        }
    }
}

