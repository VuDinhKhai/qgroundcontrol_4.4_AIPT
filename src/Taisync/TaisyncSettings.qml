/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtGraphicalEffects       1.0
import QtMultimedia             5.5
import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Dialogs          1.2
import QtQuick.Layouts          1.2
import QtLocation               5.3
import QtPositioning            5.3

import QGroundControl                       1.0
import QGroundControl.Controllers           1.0
import QGroundControl.Controls              1.0
import QGroundControl.FactControls          1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.Palette               1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.SettingsManager       1.0

Rectangle {
    id:                 _root
    color:              qgcPal.window
    anchors.fill:       parent
    anchors.margins:    ScreenTools.defaultFontPixelWidth

    property real _labelWidth:                  ScreenTools.defaultFontPixelWidth * 26
    property real _valueWidth:                  ScreenTools.defaultFontPixelWidth * 20
    property real _panelWidth:                  _root.width * _internalWidthRatio
    property Fact _taisyncEnabledFact:          QGroundControl.settingsManager.appSettings.enableTaisync
    property Fact _taisyncVideoEnabledFact:     QGroundControl.settingsManager.appSettings.enableTaisyncVideo
    property bool _taisyncEnabled:              _taisyncEnabledFact.rawValue

    readonly property real _internalWidthRatio:          0.8

    QGCFlickable {
        clip:               true
        anchors.fill:       parent
        contentHeight:      settingsColumn.height
        contentWidth:       settingsColumn.width
        Column {
            id:                 settingsColumn
            width:              _root.width
            spacing:            ScreenTools.defaultFontPixelHeight * 0.5
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            QGCLabel {
                text:           qsTr("Khởi động lại thiết bị mặt đất để thay đổi có hiệu lực.")
                color:          qgcPal.colorOrange
                visible:        QGroundControl.taisyncManager.needReboot
                font.family:    ScreenTools.demiboldFontFamily
                anchors.horizontalCenter:   parent.horizontalCenter
            }
            //-----------------------------------------------------------------
            //-- General
            Item {
                width:                      _panelWidth
                height:                     generalLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                QGCLabel {
                    id:             generalLabel
                    text:           qsTr("Tổng quan")
                    font.family:    ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     generalRow.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                Row {
                    id:                 generalRow
                    spacing:            ScreenTools.defaultFontPixelWidth * 4
                    anchors.centerIn:   parent
                    Column {
                        spacing:        ScreenTools.defaultFontPixelWidth
                        FactCheckBox {
                            text:       qsTr("Bật Taisync")
                            fact:       _taisyncEnabledFact
                            enabled:    !QGroundControl.taisyncManager.needReboot
                            visible:    _taisyncEnabledFact.visible
                        }
                        FactCheckBox {
                            text:       qsTr("Bật Taisync Video")
                            fact:       _taisyncVideoEnabledFact
                            visible:    _taisyncVideoEnabledFact.visible
                            enabled:    _taisyncEnabled && !QGroundControl.taisyncManager.needReboot
                        }
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- Connection Status
            Item {
                width:                      _panelWidth
                height:                     statusLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                visible:                    _taisyncEnabled
                QGCLabel {
                    id:                     statusLabel
                    text:                   qsTr("Trạng thái kết nối")
                    font.family:            ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     statusCol.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                visible:                    _taisyncEnabled
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                Column {
                    id:                     statusCol
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.5
                    width:                  parent.width
                    anchors.centerIn:       parent
                    GridLayout {
                        anchors.margins:    ScreenTools.defaultFontPixelHeight
                        columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: 2
                        QGCLabel {
                            text:           qsTr("Đơn vị mặt đất:")
                            Layout.minimumWidth: _labelWidth
                        }
                        QGCLabel {
                            text:           QGroundControl.taisyncManager.connected ? qsTr("Đã kết nối") : qsTr("Không kết nối")
                            color:          QGroundControl.taisyncManager.connected ? qgcPal.colorGreen : qgcPal.colorRed
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("Đơn vị hàng không:")
                        }
                        QGCLabel {
                            text:           QGroundControl.taisyncManager.linkConnected ? qsTr("Đã kết nối") : qsTr("Không kết nối")
                            color:          QGroundControl.taisyncManager.linkConnected ? qgcPal.colorGreen : qgcPal.colorRed
                        }
                        QGCLabel {
                            text:           qsTr("Liên kết lên RSSI:")
                        }
                        QGCLabel {
                            text:           QGroundControl.taisyncManager.linkConnected ? QGroundControl.taisyncManager.uplinkRSSI : ""
                        }
                        QGCLabel {
                            text:           qsTr("Đường dẫn xuống RSSI:")
                        }
                        QGCLabel {
                            text:           QGroundControl.taisyncManager.linkConnected ? QGroundControl.taisyncManager.downlinkRSSI : ""
                        }
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- Device Info
            Item {
                width:                      _panelWidth
                height:                     devInfoLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                visible:                    _taisyncEnabled && QGroundControl.taisyncManager.connected
                QGCLabel {
                    id:                     devInfoLabel
                    text:                   qsTr("Thông tin thiết bị")
                    font.family:            ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     devInfoCol.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                visible:                    _taisyncEnabled && QGroundControl.taisyncManager.connected
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                Column {
                    id:                     devInfoCol
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.5
                    width:                  parent.width
                    anchors.centerIn:       parent
                    GridLayout {
                        anchors.margins:    ScreenTools.defaultFontPixelHeight
                        columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: 2
                        QGCLabel {
                            text:           qsTr("Số seri:")
                            Layout.minimumWidth: _labelWidth
                        }
                        QGCLabel {
                            text:           QGroundControl.taisyncManager.connected ? QGroundControl.taisyncManager.serialNumber : ""
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("Phiên bản phần mềm:")
                        }
                        QGCLabel {
                            text:           QGroundControl.taisyncManager.connected ? QGroundControl.taisyncManager.fwVersion : ""
                        }
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- Radio Settings
            Item {
                width:                      _panelWidth
                height:                     radioSettingsLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                visible:                    _taisyncEnabled && QGroundControl.taisyncManager.linkConnected
                QGCLabel {
                    id:                     radioSettingsLabel
                    text:                   qsTr("Cài đặt Radio")
                    font.family:            ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     radioSettingsCol.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                visible:                    _taisyncEnabled && QGroundControl.taisyncManager.linkConnected
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                Column {
                    id:                     radioSettingsCol
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.5
                    width:                  parent.width
                    anchors.centerIn:       parent
                    GridLayout {
                        anchors.margins:    ScreenTools.defaultFontPixelHeight
                        columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: 2
                        QGCLabel {
                            text:           qsTr("Chế độ Radio:")
                            Layout.minimumWidth: _labelWidth
                        }
                        FactComboBox {
                            fact:           QGroundControl.taisyncManager.radioMode
                            indexModel:     true
                            enabled:        QGroundControl.taisyncManager.linkConnected && !QGroundControl.taisyncManager.needReboot
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("Tần số vô tuyến:")
                        }
                        FactComboBox {
                            fact:           QGroundControl.taisyncManager.radioChannel
                            indexModel:     true
                            enabled:        QGroundControl.taisyncManager.linkConnected && QGroundControl.taisyncManager.radioMode.rawValue > 0 && !QGroundControl.taisyncManager.needReboot
                            Layout.minimumWidth: _valueWidth
                        }
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- Video Settings
            Item {
                width:                      _panelWidth
                height:                     videoSettingsLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                visible:                    _taisyncEnabled && QGroundControl.taisyncManager.linkConnected
                QGCLabel {
                    id:                     videoSettingsLabel
                    text:                   qsTr("Cài đặt video")
                    font.family:            ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     videoSettingsCol.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                visible:                    _taisyncEnabled && QGroundControl.taisyncManager.linkConnected
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                Column {
                    id:                     videoSettingsCol
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.5
                    width:                  parent.width
                    anchors.centerIn:       parent
                    GridLayout {
                        anchors.margins:    ScreenTools.defaultFontPixelHeight
                        columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: 2
                        QGCLabel {
                            text:           qsTr("Đầu ra video:")
                            Layout.minimumWidth: _labelWidth
                        }
                        FactComboBox {
                            fact:           QGroundControl.taisyncManager.videoOutput
                            indexModel:     true
                            enabled:        QGroundControl.taisyncManager.linkConnected && !QGroundControl.taisyncManager.needReboot
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("Bộ mã hóa:")
                        }
                        FactComboBox {
                            fact:           QGroundControl.taisyncManager.videoMode
                            indexModel:     true
                            enabled:        QGroundControl.taisyncManager.linkConnected && !QGroundControl.taisyncManager.needReboot
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("Tốc độ bit:")
                        }
                        FactComboBox {
                            fact:           QGroundControl.taisyncManager.videoRate
                            indexModel:     true
                            enabled:        QGroundControl.taisyncManager.linkConnected && !QGroundControl.taisyncManager.needReboot
                            Layout.minimumWidth: _valueWidth
                        }
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- RTSP Settings
            Item {
                width:                      _panelWidth
                height:                     rtspSettingsLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                visible:                    _taisyncEnabled && QGroundControl.taisyncManager.connected
                QGCLabel {
                    id:                     rtspSettingsLabel
                    text:                   qsTr("Cài đặt phát trực tuyến")
                    font.family:            ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     rtspSettingsCol.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                visible:                    _taisyncEnabled && QGroundControl.taisyncManager.connected
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                Column {
                    id:                     rtspSettingsCol
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.5
                    width:                  parent.width
                    anchors.centerIn:       parent
                    GridLayout {
                        anchors.margins:    ScreenTools.defaultFontPixelHeight
                        columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: 2
                        QGCLabel {
                            text:           qsTr("RTSP URI:")
                            Layout.minimumWidth: _labelWidth
                        }
                        QGCTextField {
                            id:             rtspURI
                            text:           QGroundControl.taisyncManager.rtspURI
                            enabled:        QGroundControl.taisyncManager.connected && !QGroundControl.taisyncManager.needReboot
                            inputMethodHints:    Qt.ImhUrlCharactersOnly
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("Tài khoản:")
                        }
                        QGCTextField {
                            id:             rtspAccount
                            text:           QGroundControl.taisyncManager.rtspAccount
                            enabled:        QGroundControl.taisyncManager.connected && !QGroundControl.taisyncManager.needReboot
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("Mật khẩu:")
                        }
                        QGCTextField {
                            id:             rtspPassword
                            text:           QGroundControl.taisyncManager.rtspPassword
                            enabled:        QGroundControl.taisyncManager.connected && !QGroundControl.taisyncManager.needReboot
                            inputMethodHints:    Qt.ImhHiddenText
                            Layout.minimumWidth: _valueWidth
                        }
                    }
                    Item {
                        width:  1
                        height: ScreenTools.defaultFontPixelHeight
                    }
                    QGCButton {
                        function testEnabled() {
                            if(!QGroundControl.taisyncManager.connected)
                                return false
                            if(rtspPassword.text === QGroundControl.taisyncManager.rtspPassword &&
                                rtspAccount.text === QGroundControl.taisyncManager.rtspAccount &&
                                rtspURI.text     === QGroundControl.taisyncManager.rtspURI)
                                return false
                            if(rtspURI === "")
                                return false
                            return true
                        }
                        enabled:            testEnabled() && !QGroundControl.taisyncManager.needReboot
                        text:               qsTr("Áp dụng")
                        anchors.horizontalCenter:   parent.horizontalCenter
                        onClicked: {
                            setRTSPDialog.open()
                        }
                        MessageDialog {
                            id:                 setRTSPDialog
                            icon:               StandardIcon.Warning
                            standardButtons:    StandardButton.Yes | StandardButton.No
                            title:              qsTr("Thiết lập cài đặt phát trực tuyến")
                            text:               qsTr("Sau khi thay đổi, bạn sẽ cần khởi động lại thiết bị mặt đất để những thay đổi có hiệu lực.\n\nXác nhận thay đổi?")
                            onYes: {
                                QGroundControl.taisyncManager.setRTSPSettings(rtspURI.text, rtspAccount.text, rtspPassword.text)
                                setRTSPDialog.close()
                            }
                            onNo: {
                                setRTSPDialog.close()
                            }
                        }
                    }
                }
            }
            //-----------------------------------------------------------------
            //-- IP Settings
            Item {
                width:                      _panelWidth
                height:                     ipSettingsLabel.height
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                visible:                    _taisyncEnabled && (!ScreenTools.isiOS && !ScreenTools.isAndroid)
                QGCLabel {
                    id:                     ipSettingsLabel
                    text:                   qsTr("Cài đặt mạng")
                    font.family:            ScreenTools.demiboldFontFamily
                }
            }
            Rectangle {
                height:                     ipSettingsCol.height + (ScreenTools.defaultFontPixelHeight * 2)
                width:                      _panelWidth
                color:                      qgcPal.windowShade
                visible:                    _taisyncEnabled && (!ScreenTools.isiOS && !ScreenTools.isAndroid)
                anchors.margins:            ScreenTools.defaultFontPixelWidth
                anchors.horizontalCenter:   parent.horizontalCenter
                Column {
                    id:                     ipSettingsCol
                    spacing:                ScreenTools.defaultFontPixelHeight * 0.5
                    width:                  parent.width
                    anchors.centerIn:       parent
                    GridLayout {
                        anchors.margins:    ScreenTools.defaultFontPixelHeight
                        columnSpacing:      ScreenTools.defaultFontPixelWidth * 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        columns: 2
                        QGCLabel {
                            text:           qsTr("Địa chỉ IP cục bộ:")
                            Layout.minimumWidth: _labelWidth
                        }
                        QGCTextField {
                            id:             localIP
                            text:           QGroundControl.taisyncManager.localIPAddr
                            enabled:        !QGroundControl.taisyncManager.needReboot
                            inputMethodHints:    Qt.ImhFormattedNumbersOnly
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("Địa chỉ IP của đơn vị mặt đất:")
                        }
                        QGCTextField {
                            id:             remoteIP
                            text:           QGroundControl.taisyncManager.remoteIPAddr
                            enabled:        !QGroundControl.taisyncManager.needReboot
                            inputMethodHints:    Qt.ImhFormattedNumbersOnly
                            Layout.minimumWidth: _valueWidth
                        }
                        QGCLabel {
                            text:           qsTr("Mạng Mask:")
                        }
                        QGCTextField {
                            id:             netMask
                            text:           QGroundControl.taisyncManager.netMask
                            enabled:        !QGroundControl.taisyncManager.needReboot
                            inputMethodHints:    Qt.ImhFormattedNumbersOnly
                            Layout.minimumWidth: _valueWidth
                        }
                    }
                    Item {
                        width:  1
                        height: ScreenTools.defaultFontPixelHeight
                    }
                    QGCButton {
                        function validateIPaddress(ipaddress) {
                            if (/^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(ipaddress))
                                return true
                            return false
                        }
                        function testEnabled() {
                            if(localIP.text   === QGroundControl.taisyncManager.localIPAddr &&
                                remoteIP.text === QGroundControl.taisyncManager.remoteIPAddr &&
                                netMask.text  === QGroundControl.taisyncManager.netMask)
                                return false
                            if(!validateIPaddress(localIP.text))  return false
                            if(!validateIPaddress(remoteIP.text)) return false
                            if(!validateIPaddress(netMask.text))  return false
                            return true
                        }
                        enabled:            testEnabled() && !QGroundControl.taisyncManager.needReboot
                        text:               qsTr("Áp dụng")
                        anchors.horizontalCenter:   parent.horizontalCenter
                        onClicked: {
                            setIPDialog.open()
                        }
                        MessageDialog {
                            id:                 setIPDialog
                            icon:               StandardIcon.Warning
                            standardButtons:    StandardButton.Yes | StandardButton.No
                            title:              qsTr("Thiết lập cài đặt mạng")
                            text:               qsTr("Sau khi thay đổi, bạn sẽ cần khởi động lại thiết bị mặt đất để các thay đổi có hiệu lực. Địa chỉ IP cục bộ phải khớp với địa chỉ đã nhập (%1).\n\nXác nhận thay đổi?").arg(localIP.text)
                            onYes: {
                                QGroundControl.taisyncManager.setIPSettings(localIP.text, remoteIP.text, netMask.text)
                                setIPDialog.close()
                            }
                            onNo: {
                                setIPDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
