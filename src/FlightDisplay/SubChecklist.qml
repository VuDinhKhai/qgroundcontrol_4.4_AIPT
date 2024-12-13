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
            name: qsTr("Kiểm tra ban đầu của tàu ngầm")

            PreFlightCheckButton {
                name:           qsTr("Phần cứng")
                manualText:     qsTr("Tất cả các phong bì đều ở đúng vị trí?")
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
                name:            qsTr("Bộ điều khiển")
                manualText:      qsTr("Di chuyển tất cả các bề mặt điều khiển. Chúng hoạt động đúng cách chứ?")
            }

            PreFlightCheckButton {
                name:            qsTr("Động cơ")
                manualText:      qsTr("Cánh quạt tự do? Sau đó, tăng ga nhẹ. Hoạt động đúng cách chứ?")
            }

            PreFlightCheckButton {
                name:           qsTr("Nhiệm vụ")
                manualText:     qsTr("Vui lòng xác nhận nhiệm vụ có hợp lệ không (điểm đến hợp lệ, không va chạm với địa hình).")
            }

            PreFlightSoundCheck {
            }
        }

        PreFlightCheckGroup {
            name: qsTr("Các chuẩn bị cuối cùng trước khi phóng")

            // Check list item group 2 - Final checks before launch
            PreFlightCheckButton {
                name:           qsTr("Hàng hóa")
                manualText:     qsTr("Đã cấu hình và bắt đầu? Nắp hàng hóa đã đóng chưa?")
            }

        }
    }
}
