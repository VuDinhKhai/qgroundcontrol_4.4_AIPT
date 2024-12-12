/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick              2.3
import QtQuick.Controls     1.2
import QtQuick.Dialogs      1.2
import QtQuick.Layouts      1.2

import QGroundControl               1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.Controllers   1.0
import QGroundControl.ScreenTools   1.0

AnalyzePage {
    id:                 logDownloadPage
    pageComponent:      pageComponent
    pageDescription:    qsTr("Tải nhật ký cho phép bạn tải xuống các tệp nhật ký nhị phân từ thiết bị bay của bạn. Nhấn 'Làm mới' để lấy danh sách các nhật ký có sẵn.")

    property real _margin:          ScreenTools.defaultFontPixelWidth
    property real _butttonWidth:    ScreenTools.defaultFontPixelWidth * 10

    QGCPalette { id: palette; colorGroupEnabled: enabled }

    Component {
        id: pageComponent

        RowLayout {
            width:  availableWidth
            height: availableHeight

            Connections {
                target: logController
                onSelectionChanged: {
                    tableView.selection.clear()
                    for(var i = 0; i < logController.model.count; i++) {
                        var o = logController.model.get(i)
                        if (o && o.selected) {
                            tableView.selection.select(i, i)
                        }
                    }
                }
            }

            TableView {
                id: tableView
                Layout.fillHeight:  true
                model:              logController.model
                selectionMode:      SelectionMode.MultiSelection
                Layout.fillWidth:   true

                TableViewColumn {
                    title: qsTr("Id")
                    width: ScreenTools.defaultFontPixelWidth * 6
                    horizontalAlignment: Text.AlignHCenter
                    delegate : Text  {
                        color: styleData.textColor
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            var o = logController.model.get(styleData.row)
                            return o ? o.id : ""
                        }
                    }
                }

                TableViewColumn {
                    title: qsTr("Ngày")
                    width: ScreenTools.defaultFontPixelWidth * 34
                    horizontalAlignment: Text.AlignHCenter
                    delegate: Text  {
                        color: styleData.textColor
                        text: {
                            var o = logController.model.get(styleData.row)
                            if (o) {
                                //-- Have we received this entry already?
                                if(logController.model.get(styleData.row).received) {
                                    var d = logController.model.get(styleData.row).time
                                    if(d.getUTCFullYear() < 2010)
                                        return qsTr("Ngày không xác định")
                                    else
                                        return d.toLocaleString(undefined, "short")
                                }
                            }
                            return ""
                        }
                    }
                }

                TableViewColumn {
                    title: qsTr("Kích cỡ")
                    width: ScreenTools.defaultFontPixelWidth * 18
                    horizontalAlignment: Text.AlignHCenter
                    delegate : Text  {
                        color: styleData.textColor
                        horizontalAlignment: Text.AlignRight
                        text: {
                            var o = logController.model.get(styleData.row)
                            return o ? o.sizeStr : ""
                        }
                    }
                }

                TableViewColumn {
                    title: qsTr("Trạng thái")
                    width: ScreenTools.defaultFontPixelWidth * 22
                    horizontalAlignment: Text.AlignHCenter
                    delegate : Text  {
                        color: styleData.textColor
                        horizontalAlignment: Text.AlignHCenter
                        text: {
                            var o = logController.model.get(styleData.row)
                            return o ? o.status : ""
                        }
                    }
                }
            }
            Column {
                spacing:            _margin
                Layout.alignment:   Qt.AlignTop | Qt.AlignLeft
                QGCButton {
                    enabled:    !logController.requestingList && !logController.downloadingLogs
                    text:       qsTr("Refresh")
                    width:      _butttonWidth
                    onClicked: {
                        if (!QGroundControl.multiVehicleManager.activeVehicle || QGroundControl.multiVehicleManager.activeVehicle.isOfflineEditingVehicle) {
                            mainWindow.showMessageDialog(qsTr("Làm mới nhật ký"), qsTr("Bạn phải kết nối với thiết bị bay để tải xuống các nhật ký."))
                        } else {
                            logController.refresh()
                        }
                    }
                }
                QGCButton {
                    enabled:    !logController.requestingList && !logController.downloadingLogs && tableView.selection.count > 0
                    text:       qsTr("Tải xuống")
                    width:      _butttonWidth
                    onClicked: {
                        //-- Clear selection
                        for(var i = 0; i < logController.model.count; i++) {
                            var o = logController.model.get(i)
                            if (o) o.selected = false
                        }
                        //-- Flag selected log files
                        tableView.selection.forEach(function(rowIndex){
                            var o = logController.model.get(rowIndex)
                            if (o) o.selected = true
                        })
                        if (ScreenTools.isMobile) {
                            // You can't pick folders in mobile, only default location is used
                            logController.download()
                        } else {
                            fileDialog.title =          qsTr("Chọn thư mục lưu")
                            fileDialog.selectExisting = true
                            fileDialog.folder =         QGroundControl.settingsManager.appSettings.logSavePath
                            fileDialog.selectFolder =   true
                            fileDialog.openForLoad()
                        }
                    }
                    QGCFileDialog {
                        id: fileDialog
                        onAcceptedForLoad: {
                            logController.download(file)
                            close()
                        }
                    }
                }
                QGCButton {
                    enabled:    !logController.requestingList && !logController.downloadingLogs && logController.model.count > 0
                    text:       qsTr("Xóa tất cả")
                    width:      _butttonWidth
                    onClicked:  mainWindow.showMessageDialog(qsTr("Xóa tất cả các tệp nhật ký"),
                                                             qsTr("Tất cả các tập tin nhật ký sẽ bị xóa vĩnh viễn. Đây có thực sự là điều bạn muốn?"),
                                                             StandardButton.Yes | StandardButton.No,
                                                             function() { logController.eraseAll() })
                }
                QGCButton {
                    text:       qsTr("Hủy")
                    width:      _butttonWidth
                    enabled:    logController.requestingList || logController.downloadingLogs
                    onClicked:  logController.cancel()
                }
            }
        }
    }
}
