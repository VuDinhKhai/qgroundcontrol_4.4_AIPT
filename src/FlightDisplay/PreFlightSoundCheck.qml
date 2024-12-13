/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick 2.3

import QGroundControl           1.0
import QGroundControl.Controls  1.0

PreFlightCheckButton {
    name:                   qsTr("Đầu ra âm thanh")
    manualText:             qsTr("Đầu ra âm thanh QGC đã được bật. Đầu ra âm thanh hệ thống cũng đã được bật, phải không?")
    telemetryTextFailure:   qsTr("Đầu ra âm thanh QGC đã bị tắt. Vui lòng bật nó dưới cài đặt ứng dụng->chung để nghe các cảnh báo âm thanh!")
    telemetryFailure:       QGroundControl.settingsManager.appSettings.audioMuted.rawValue
}
