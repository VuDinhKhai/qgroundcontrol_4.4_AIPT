/****************************************************************************
 *
 *   (c) 2009-2016 DỰ ÁN QGROUNDCONTROL <http://www.qgroundcontrol.org>
 *
 * QGroundControl được cấp phép theo các điều khoản trong tệp
 * COPYING.md trong thư mục nguồn mã nguồn.
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
            name: qsTr("Kiểm tra ban đầu của Rover")

            PreFlightCheckButton {
                name:           qsTr("Phần cứng")
                manualText:     qsTr("Pin được gắn và cố định?")
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
            name: qsTr("Vui lòng kích hoạt phương tiện tại đây")

            PreFlightCheckButton {
                name:           qsTr("Nhiệm vụ")
                manualText:     qsTr("Vui lòng xác nhận nhiệm vụ có hợp lệ (điểm đến hợp lệ, không va chạm với địa hình).")
            }

            PreFlightSoundCheck {
            }
        }

        PreFlightCheckGroup {
            name: qsTr("Các chuẩn bị cuối cùng trước khi phóng")

            // Check list item group 2 - Final checks before launch
            PreFlightCheckButton {
                name:           qsTr("Hàng hóa")
                manualText:     qsTr("Đã cấu hình và bắt đầu? Nắp hàng hóa đã đóng?")
            }

            PreFlightCheckButton {
                name:           qsTr("Gió & thời tiết")
                manualText:     qsTr("OK cho nền tảng của bạn?")
            }

            PreFlightCheckButton {
                name:           qsTr("Khu vực nhiệm vụ")
                manualText:     qsTr("Khu vực nhiệm vụ và đường đi không có chướng ngại vật/người?")
            }
        }
    }
}
