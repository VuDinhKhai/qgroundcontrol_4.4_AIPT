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

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Palette       1.0

RowLayout {
    spacing: _colSpacing

    function saveSettings() {
        subEditConfig.filename = logField.text
    }

    QGCLabel { text: qsTr("Tệp Nhật ký") }

    QGCTextField {
        id:     logField
        text:   subEditConfig.fileName
        width:  _secondColumnWidth
    }

    QGCButton {
        text:       qsTr("Browse")
        onClicked:  filePicker.openForLoad()
    }

    QGCFileDialog {
        id:                 filePicker
        title:              qsTr("Chọn Nhật ký đo từ xa")
        nameFilters:        [ qsTr("Nhật ký đo từ xa (*.%1)").arg(_logFileExtension), qsTr("Tất cả các tập tin (*)") ]
        selectExisting:     true
        folder:             QGroundControl.settingsManager.appSettings.telemetrySavePath
        onAcceptedForLoad: {
            logField.text = file
            close()
        }

        property string _logFileExtension: QGroundControl.settingsManager.appSettings.telemetryFileExtension
    }
}
