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
            name: qsTr("Kiểm tra ban đầu Sải cánh")

            PreFlightCheckButton {
                name:           qsTr("Phần cứng")
                manualText:     qsTr("Cánh quạt đã lắp? Cánh đã được cố định? Đuôi đã được cố định?")
            }

            PreFlightBatteryCheck {
                failurePercent:                  40
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
            name: qsTr("Vui lòng vũ trang phương tiện tại đây")

            PreFlightCheckButton {
                name:            qsTr("Bộ truyền động")
                manualText:      qsTr("Di chuyển tất cả các bề mặt điều khiển. Chúng có hoạt động đúng không?")
            }

            PreFlightCheckButton {
                name:            qsTr("Động cơ")
                manualText:      qsTr("Lưỡi quạt có tự do không? Sau đó tăng dần nhẹ. Hoạt động đúng không?")
            }

            PreFlightCheckButton {
                name:           qsTr("Nhiệm vụ")
                manualText:     qsTr("Vui lòng xác nhận nhiệm vụ là hợp lệ (điểm đến hợp lệ, không va chạm địa hình).")
            }

            PreFlightSoundCheck {
            }
        }

        PreFlightCheckGroup {
            name: qsTr("Sự chuẩn bị cuối cùng trước khi phóng")

            // Nhóm mục kiểm tra 2 - Kiểm tra cuối cùng trước khi phóng
            PreFlightCheckButton {
                name:           qsTr("Tải trọng")
                manualText:     qsTr("Được cấu hình và đã khởi động? Nắp tải trọng đã đóng?")
            }

            PreFlightCheckButton {
                name:           qsTr("Gió & thời tiết")
                manualText:     qsTr("OK cho nền tảng của bạn? Phóng vào gió?")
            }

            PreFlightCheckButton {
                name:           qsTr("Khu vực bay")
                manualText:     qsTr("Khu vực phóng và đường bay có tự do không có vật cản/người không?")
            }
        }
    }
}

