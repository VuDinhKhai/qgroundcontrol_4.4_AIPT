/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick 2.3
import QtQuick.Controls 1.2
import QtQuick.Controls.Styles 1.4
import QtQuick.Dialogs 1.2
import QtQuick.Layouts 1.3

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controllers   1.0
import QGroundControl.ScreenTools   1.0

SetupPage {
    id:             firmwarePage
    pageComponent:  firmwarePageComponent
    pageName:       qsTr("Firmware")
    showAdvanced:   globals.activeVehicle && globals.activeVehicle.apmFirmware

    Component {
        id: firmwarePageComponent

        ColumnLayout {
            width:   availableWidth
            height:  availableHeight
            spacing: ScreenTools.defaultFontPixelHeight

            // Those user visible strings are hard to translate because we can't send the
            // HTML strings to translation as this can create a security risk. we need to find
            // a better way to hightlight them, or use less highlights.

            // User visible strings
            //readonly property string title:             qsTr("Firmware Setup") // Popup dialog title
            //readonly property string highlightPrefix:   "<font color=\"" + qgcPal.warningText + "\">"
            //readonly property string highlightSuffix:   "</font>"
            //readonly property string welcomeText:       qsTr("%1 can upgrade the firmware on Pixhawk devices, SiK Radios and PX4 Flow Smart Cameras.").arg(QGroundControl.appName)
            //readonly property string welcomeTextSingle: qsTr("Update the autopilot firmware to the latest version")
            //readonly property string plugInText:        "<big>" + highlightPrefix + qsTr("Plug in your device") + highlightSuffix + qsTr(" via USB to ") + highlightPrefix + qsTr("start") + highlightSuffix + qsTr(" firmware upgrade.") + "</big>"
            //readonly property string flashFailText:     qsTr("If upgrade failed, make sure to connect ") + highlightPrefix + qsTr("directly") + highlightSuffix + qsTr(" to a powered USB port on your computer, not through a USB hub. ") +
            //                                            qsTr("Also make sure you are only powered via USB ") + highlightPrefix + qsTr("not battery") + highlightSuffix + "."
            //readonly property string qgcUnplugText1:    qsTr("All %1 connections to vehicles must be ").arg(QGroundControl.appName) + highlightPrefix + qsTr(" disconnected ") + highlightSuffix + qsTr("prior to firmware upgrade.")
            //readonly property string qgcUnplugText2:    highlightPrefix + "<big>" + qsTr("Please unplug your Pixhawk and/or Radio from USB.") + "</big>" + highlightSuffix
            readonly property string title:             qsTr("Cài đặt Firmware") // Tiêu đề hộp thoại pop-up
            readonly property string highlightPrefix:   "<font color=\"" + qgcPal.warningText + "\">"
            readonly property string highlightSuffix:   "</font>"
            readonly property string welcomeText:       qsTr("%1 có thể nâng cấp firmware trên các thiết bị Pixhawk, Radio SiK và Camera thông minh PX4 Flow.").arg(QGroundControl.appName)
            readonly property string welcomeTextSingle: qsTr("Cập nhật firmware của autopilot lên phiên bản mới nhất")
            readonly property string plugInText:        "<big>" + highlightPrefix + qsTr("Cắm thiết bị của bạn vào") + highlightSuffix + qsTr(" qua USB để ") + highlightPrefix + qsTr("bắt đầu") + highlightSuffix + qsTr(" nâng cấp firmware.") + "</big>"
            readonly property string flashFailText:     qsTr("Nếu việc nâng cấp không thành công, hãy đảm bảo kết nối ") + highlightPrefix + qsTr("trực tiếp") + highlightSuffix + qsTr(" vào cổng USB có nguồn điện trên máy tính của bạn, không phải qua hub USB. ") +
                                                        qsTr("Ngoài ra, hãy đảm bảo rằng bạn chỉ cấp nguồn qua USB ") + highlightPrefix + qsTr("không phải từ pin") + highlightSuffix + "."
            readonly property string qgcUnplugText1:    qsTr("Tất cả các kết nối %1 với phương tiện phải được ").arg(QGroundControl.appName) + highlightPrefix + qsTr("ngắt kết nối") + highlightSuffix + qsTr(" trước khi nâng cấp firmware.")
            readonly property string qgcUnplugText2:    highlightPrefix + "<big>" + qsTr("Vui lòng ngắt kết nối Pixhawk và/hoặc Radio khỏi USB.") + "</big>" + highlightSuffix

            readonly property int _defaultFimwareTypePX4:   12
            readonly property int _defaultFimwareTypeAPM:   3

            property var    _firmwareUpgradeSettings:   QGroundControl.settingsManager.firmwareUpgradeSettings
            property var    _defaultFirmwareFact:       _firmwareUpgradeSettings.defaultFirmwareType
            property bool   _defaultFirmwareIsPX4:      true

            property string firmwareWarningMessage
            property bool   firmwareWarningMessageVisible:  false
            property bool   initialBoardSearch:             true
            property string firmwareName

            property bool _singleFirmwareMode:          QGroundControl.corePlugin.options.firmwareUpgradeSingleURL.length != 0   ///< true: running in special single firmware download mode

            function setupPageCompleted() {
                controller.startBoardSearch()
                _defaultFirmwareIsPX4 = _defaultFirmwareFact.rawValue === _defaultFimwareTypePX4 // we don't want this to be bound and change as radios are selected
            }

            QGCFileDialog {
                id:                 customFirmwareDialog
                //title:              qsTr("Select Firmware File")
                //nameFilters:        [qsTr("Firmware Files (*.px4 *.apj *.bin *.ihx)"), qsTr("All Files (*)")]
                title:              qsTr("Chọn Tệp Firmware")
                nameFilters:        [qsTr("Tệp Firmware (*.px4 *.apj *.bin *.ihx)"), qsTr("Tất cả Tệp (*)")]

                selectExisting:     true
                folder:             QGroundControl.settingsManager.appSettings.logSavePath
                onAcceptedForLoad: {
                    controller.flashFirmwareUrl(file)
                    close()
                }
            }

            FirmwareUpgradeController {
                id:             controller
                progressBar:    progressBar
                statusLog:      statusTextArea

                property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

                onActiveVehicleChanged: {
                    if (!globals.activeVehicle) {
                        statusTextArea.append(plugInText)
                    }
                }

                onNoBoardFound: {
                    initialBoardSearch = false
                    if (!QGroundControl.multiVehicleManager.activeVehicleAvailable) {
                        statusTextArea.append(plugInText)
                    }
                }

                onBoardGone: {
                    initialBoardSearch = false
                    if (!QGroundControl.multiVehicleManager.activeVehicleAvailable) {
                        statusTextArea.append(plugInText)
                    }
                }

                onBoardFound: {
                    if (initialBoardSearch) {
                        // Board was found right away, so something is already plugged in before we've started upgrade
                        statusTextArea.append(qgcUnplugText1)
                        statusTextArea.append(qgcUnplugText2)

                        var availableDevices = controller.availableBoardsName()
                        if (availableDevices.length > 1) {
                        //    statusTextArea.append(highlightPrefix + qsTr("Multiple devices detected! Remove all detected devices to perform the firmware upgrade."))
                        //    statusTextArea.append(qsTr("Detected [%1]: ").arg(availableDevices.length) + availableDevices.join(", "))
                        statusTextArea.append(highlightPrefix + qsTr("Phát hiện nhiều thiết bị! Hãy ngắt kết nối tất cả các thiết bị được phát hiện để thực hiện nâng cấp firmware."));
                        statusTextArea.append(qsTr("Đã phát hiện [%1]: ").arg(availableDevices.length) + availableDevices.join(", "));
                        }
                        if (QGroundControl.multiVehicleManager.activeVehicle) {
                            QGroundControl.multiVehicleManager.activeVehicle.vehicleLinkManager.autoDisconnect = true
                        }
                    } else {
                        // We end up here when we detect a board plugged in after we've started upgrade
                        statusTextArea.append(highlightPrefix + qsTr("Đã tìm thấy thiết bị") + highlightSuffix + ": " + controller.boardType)
                    }
                }

                onShowFirmwareSelectDlg:    firmwareSelectDialogComponent.createObject(mainWindow).open()
                onError:                    statusTextArea.append(flashFailText)
            }

            Component {
                id: firmwareSelectDialogComponent

                QGCPopupDialog {
                    id:         firmwareSelectDialog
                    title:      qsTr("Thiết lập Firmware")
                    buttons:    StandardButton.Ok | StandardButton.Cancel

                    property bool showFirmwareTypeSelection:    _advanced.checked
                    property bool px4Flow:                      controller.px4FlowBoard

                    function firmwareVersionChanged(model) {
                        firmwareWarningMessageVisible = false
                        // All of this bizarre, setting model to null and index to 1 and then to 0 is to work around
                        // strangeness in the combo box implementation. This sequence of steps correctly changes the combo model
                        // without generating any warnings and correctly updates the combo text with the new selection.
                        firmwareBuildTypeCombo.model = null
                        firmwareBuildTypeCombo.model = model
                        firmwareBuildTypeCombo.currentIndex = 1
                        firmwareBuildTypeCombo.currentIndex = 0
                    }

                    function updatePX4VersionDisplay() {
                        var versionString = ""
                        if (_advanced.checked) {
                            switch (controller.selectedFirmwareBuildType) {
                            case FirmwareUpgradeController.StableFirmware:
                                versionString = controller.px4StableVersion
                                break
                            case FirmwareUpgradeController.BetaFirmware:
                                versionString = controller.px4BetaVersion
                                break
                            }
                        } else {
                            versionString = controller.px4StableVersion
                        }
                        px4FlightStackRadio.text = qsTr("PX4 Pro ") + versionString
                        //px4FlightStackRadio2.text = qsTr("PX4 Pro ") + versionString
                    }

                    Component.onCompleted: {
                        firmwarePage.advanced = false
                        firmwarePage.showAdvanced = false
                        updatePX4VersionDisplay()
                    }

                    Connections {
                        target:     controller
                        onError:    reject()
                    }

                    onAccepted: {
                        if (_singleFirmwareMode) {
                            controller.flashSingleFirmwareMode(controller.selectedFirmwareBuildType)
                        } else {
                            var stack
                            var firmwareBuildType = firmwareBuildTypeCombo.model.get(firmwareBuildTypeCombo.currentIndex).firmwareType
                            var vehicleType = FirmwareUpgradeController.DefaultVehicleFirmware

                            if (px4Flow) {
                                stack = px4FlowTypeSelectionCombo.model.get(px4FlowTypeSelectionCombo.currentIndex).stackType
                                vehicleType = FirmwareUpgradeController.DefaultVehicleFirmware
                            } else {
                                stack = apmFlightStack.checked ? FirmwareUpgradeController.AutoPilotStackAPM : FirmwareUpgradeController.AutoPilotStackPX4
                                if (apmFlightStack.checked) {
                                    if (firmwareBuildType === FirmwareUpgradeController.CustomFirmware) {
                                        vehicleType = apmVehicleTypeCombo.currentIndex
                                    } else {
                                        if (controller.apmFirmwareNames.length === 0) {
                                            // Not ready yet, or no firmware available
                                            mainWindow.showMessageDialog(firmwareSelectDialog.title, qsTr("Danh sách chương trình cơ sở vẫn đang được tải xuống hoặc không có chương trình cơ sở nào cho lựa chọn hiện tại."))
                                            firmwareSelectDialog.preventClose = true
                                            return
                                        }
                                        if (ardupilotFirmwareSelectionCombo.currentIndex == -1) {
                                            mainWindow.showMessageDialog(firmwareSelectDialog.title, qsTr("Bạn phải chọn một loại bảng."))
                                            firmwareSelectDialog.preventClose = true
                                            return
                                        }

                                        var firmwareUrl = controller.apmFirmwareUrls[ardupilotFirmwareSelectionCombo.currentIndex]
                                        if (firmwareUrl == "") {
                                            mainWindow.showMessageDialog(firmwareSelectDialog.title, qsTr("Không tìm thấy firmware nào cho lựa chọn hiện tại"))
                                            firmwareSelectDialog.preventClose = true
                                            return
                                        }
                                        controller.flashFirmwareUrl(controller.apmFirmwareUrls[ardupilotFirmwareSelectionCombo.currentIndex])
                                        return
                                    }
                                }
                            }
                            //-- If custom, get file path
                            if (firmwareBuildType === FirmwareUpgradeController.CustomFirmware) {
                                customFirmwareDialog.openForLoad()
                            } else {
                                controller.flash(stack, firmwareBuildType, vehicleType)
                            }
                        }
                    }

                    function reject() {
                        statusTextArea.append(highlightPrefix + qsTr("Đã hủy nâng cấp") + highlightSuffix)
                        statusTextArea.append("------------------------------------------")
                        controller.cancel()
                        close()
                    }

                    ListModel {
                        id: firmwareBuildTypeList

                        ListElement {
                            text:           qsTr("Phiên bản tiêu chuẩn (Stable)")
                            firmwareType:   FirmwareUpgradeController.StableFirmware
                        }
                        ListElement {
                            text:           qsTr("Thử nghiệm beta (beta)")
                            firmwareType:   FirmwareUpgradeController.BetaFirmware
                        }
                        ListElement {
                            text:           qsTr("Bản dựng dành cho nhà phát triển (master)")
                            firmwareType:   FirmwareUpgradeController.DeveloperFirmware
                        }
                        ListElement {
                            text:           qsTr("Tệp Firmware tùy chỉnh...")
                            firmwareType:   FirmwareUpgradeController.CustomFirmware
                        }
                    }

                    ListModel {
                        id: px4FlowFirmwareList

                        ListElement {
                            text:           qsTr("PX4 Pro")
                            stackType:   FirmwareUpgradeController.PX4FlowPX4
                        }
                        ListElement {
                            text:           qsTr("ArduPilot")
                            stackType:   FirmwareUpgradeController.PX4FlowAPM
                        }
                    }

                    ListModel {
                        id: px4FlowTypeList

                        ListElement {
                            text:           qsTr("Phiên bản tiêu chuẩn  (stable)")
                            firmwareType:   FirmwareUpgradeController.StableFirmware
                        }
                        ListElement {
                            text:           qsTr("Tệp firmware tùy chỉnh...")
                            firmwareType:   FirmwareUpgradeController.CustomFirmware
                        }
                    }

                    ListModel {
                        id: singleFirmwareModeTypeList

                        ListElement {
                            text:           qsTr("Phiên bản tiêu chuẩn ")
                            firmwareType:   FirmwareUpgradeController.StableFirmware
                        }
                        ListElement {
                            text:           qsTr("Tệp firmware tùy chỉnh...")
                            firmwareType:   FirmwareUpgradeController.CustomFirmware
                        }
                    }

                    ColumnLayout {
                        width:      Math.max(ScreenTools.defaultFontPixelWidth * 40, firmwareRadiosColumn.width)
                        spacing:    globals.defaultTextHeight / 2

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               (_singleFirmwareMode || !QGroundControl.apmFirmwareSupported) ? _singleFirmwareLabel : (px4Flow ? _px4FlowLabel : _pixhawkLabel)

                            //readonly property string _px4FlowLabel:          qsTr("Detected PX4 Flow board. The firmware you use on the PX4 Flow must match the AutoPilot firmware type you are using on the vehicle:")
                            //readonly property string _pixhawkLabel:          qsTr("Detected Pixhawk board. You can select from the following flight stacks:")
                            //readonly property string _singleFirmwareLabel:   qsTr("Press Ok to upgrade your vehicle.")
                            readonly property string _px4FlowLabel:          qsTr("Phát hiện bo mạch PX4 Flow. Firmware bạn sử dụng trên PX4 Flow phải phù hợp với loại firmware AutoPilot bạn đang sử dụng trên phương tiện:")
                            readonly property string _pixhawkLabel:          qsTr("Phát hiện bo mạch Pixhawk. Bạn có thể chọn từ các flight stack sau:")
                            readonly property string _singleFirmwareLabel:   qsTr("Nhấn Ok để nâng cấp phương tiện của bạn.")
                        
                        }

                        Column {
                            id:         firmwareRadiosColumn
                            spacing:    0

                            visible: !_singleFirmwareMode && !px4Flow && QGroundControl.apmFirmwareSupported

                            Component.onCompleted: {
                                if(!QGroundControl.apmFirmwareSupported) {
                                    _defaultFirmwareFact.rawValue = _defaultFimwareTypePX4
                                    firmwareVersionChanged(firmwareBuildTypeList)
                                }
                            }

                            QGCRadioButton {
                                id:             px4FlightStackRadio
                                text:           qsTr("PX4 Pro ")
                                font.bold:      _defaultFirmwareIsPX4
                                checked:        _defaultFirmwareIsPX4

                                onClicked: {
                                    _defaultFirmwareFact.rawValue = _defaultFimwareTypePX4
                                    firmwareVersionChanged(firmwareBuildTypeList)
                                }
                            }

                            QGCRadioButton {
                                id:             apmFlightStack
                                text:           qsTr("ArduPilot")
                                font.bold:      !_defaultFirmwareIsPX4
                                checked:        !_defaultFirmwareIsPX4

                                onClicked: {
                                    _defaultFirmwareFact.rawValue = _defaultFimwareTypeAPM
                                    firmwareVersionChanged(firmwareBuildTypeList)
                                }
                            }
                        }

                        FactComboBox {
                            Layout.fillWidth:   true
                            visible:            !px4Flow && apmFlightStack.checked
                            fact:               _firmwareUpgradeSettings.apmChibiOS
                            indexModel:         false
                        }

                        FactComboBox {
                            id:                 apmVehicleTypeCombo
                            Layout.fillWidth:   true
                            visible:            !px4Flow && apmFlightStack.checked
                            fact:               _firmwareUpgradeSettings.apmVehicleType
                            indexModel:         false
                        }

                        QGCComboBox {
                            id:                 ardupilotFirmwareSelectionCombo
                            Layout.fillWidth:   true
                            visible:            !px4Flow && apmFlightStack.checked && !controller.downloadingFirmwareList && controller.apmFirmwareNames.length !== 0
                            model:              controller.apmFirmwareNames
                            onModelChanged:     currentIndex = controller.apmFirmwareNamesBestIndex
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               qsTr("Đang tải danh sách các firmware có sẵn...")
                            visible:            controller.downloadingFirmwareList
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            text:               qsTr("Không có firmware nào có sẵn")
                            visible:            !controller.downloadingFirmwareList && (QGroundControl.apmFirmwareSupported && controller.apmFirmwareNames.length === 0)
                        }

                        QGCComboBox {
                            id:                 px4FlowTypeSelectionCombo
                            Layout.fillWidth:   true
                            visible:            px4Flow
                            model:              px4FlowFirmwareList
                            textRole:           "text"
                            currentIndex:       _defaultFirmwareIsPX4 ? 0 : 1
                        }

                        QGCCheckBox {
                            id:         _advanced
                            text:       qsTr("Cài đặt nâng cao")
                            checked:    px4Flow ? true : false
                            visible:    !px4Flow

                            onClicked: {
                                firmwareBuildTypeCombo.currentIndex = 0
                                firmwareWarningMessageVisible = false
                                updatePX4VersionDisplay()
                            }
                        }

                        QGCLabel {
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            visible:            showFirmwareTypeSelection
                            //text:               _singleFirmwareMode ?  qsTr("Select the standard version or one from the file system (previously downloaded):") :
                            //                                          (px4Flow ? qsTr("Select which version of the firmware you would like to install:") :
                            //                                                     qsTr("Select which version of the above flight stack you would like to install:"))
                            text:               _singleFirmwareMode ?  qsTr("Chọn phiên bản chuẩn hoặc một phiên bản từ hệ thống tệp (đã tải xuống trước đó):") :
                                                                        (px4Flow ? qsTr("Chọn phiên bản firmware mà bạn muốn cài đặt:") :
                                                                                    qsTr("Chọn phiên bản của flight stack trên mà bạn muốn cài đặt:"))

                        }

                        QGCComboBox {
                            id:                 firmwareBuildTypeCombo
                            Layout.fillWidth:   true
                            visible:            showFirmwareTypeSelection
                            textRole:           "text"
                            model:              _singleFirmwareMode ? singleFirmwareModeTypeList : (px4Flow ? px4FlowTypeList : firmwareBuildTypeList)

                            onActivated: {
                                controller.selectedFirmwareBuildType = model.get(index).firmwareType
                                if (model.get(index).firmwareType === FirmwareUpgradeController.BetaFirmware) {
                                    firmwareWarningMessageVisible = true
                                //    firmwareVersionWarningLabel.text = qsTr("WARNING: BETA FIRMWARE. ") +
                                //            qsTr("This firmware version is ONLY intended for beta testers. ") +
                                //            qsTr("Although it has received FLIGHT TESTING, it represents actively changed code. ") +
                                //            qsTr("Do NOT use for normal operation.")
                                //} else if (model.get(index).firmwareType === FirmwareUpgradeController.DeveloperFirmware) {
                                //    firmwareWarningMessageVisible = true
                                //    firmwareVersionWarningLabel.text = qsTr("WARNING: CONTINUOUS BUILD FIRMWARE. ") +
                                //            qsTr("This firmware has NOT BEEN FLIGHT TESTED. ") +
                                //           qsTr("It is only intended for DEVELOPERS. ") +
                                //            qsTr("Run bench tests without props first. ") +
                                //            qsTr("Do NOT fly this without additional safety precautions. ") +
                                //            qsTr("Follow the forums actively when using it.")


                                firmwareVersionWarningLabel.text = qsTr("CẢNH BÁO: FIRMWARE BETA. ") +
                                        qsTr("Phiên bản firmware này CHỈ dành cho những người thử nghiệm beta. ") +
                                        qsTr("Mặc dù đã được KIỂM TRA BAY, nó đại diện cho mã đang thay đổi liên tục. ") +
                                        qsTr("KHÔNG sử dụng cho hoạt động bình thường.")
                                } else if (model.get(index).firmwareType === FirmwareUpgradeController.DeveloperFirmware) {
                                    firmwareWarningMessageVisible = true
                                    firmwareVersionWarningLabel.text = qsTr("CẢNH BÁO: FIRMWARE XÂY DỰNG LIÊN TỤC. ") +
                                            qsTr("Phiên bản firmware này CHƯA ĐƯỢC KIỂM TRA BAY. ") +
                                            qsTr("Nó chỉ dành cho CÁC NHÀ PHÁT TRIỂN. ") +
                                            qsTr("Hãy thực hiện kiểm tra trên bàn mà không gắn cánh quạt trước. ") +
                                            qsTr("KHÔNG bay nếu không có các biện pháp an toàn bổ sung. ") +
                                            qsTr("Hãy theo dõi các diễn đàn khi sử dụng nó.")

                                } else {
                                    firmwareWarningMessageVisible = false
                                }
                                updatePX4VersionDisplay()
                            }
                        }

                        QGCLabel {
                            id:                 firmwareVersionWarningLabel
                            Layout.fillWidth:   true
                            wrapMode:           Text.WordWrap
                            visible:            firmwareWarningMessageVisible
                        }
                    } // ColumnLayout
                } // QGCPopupDialog
            } // Component - firmwareSelectDialogComponent

            ProgressBar {
                id:                     progressBar
                Layout.preferredWidth:  parent.width
                visible:                !flashBootloaderButton.visible
            }

            QGCButton {
                id:         flashBootloaderButton
                text:       qsTr("Flash ChibiOS Bootloader")
                visible:    firmwarePage.advanced
                onClicked:  globals.activeVehicle.flashBootloader()
            }

            TextArea {
                id:                 statusTextArea
                Layout.preferredWidth:              parent.width
                Layout.fillHeight:  true
                readOnly:           true
                frameVisible:       false
                font.pointSize:     ScreenTools.defaultFontPointSize
                textFormat:         TextEdit.RichText
                text:               _singleFirmwareMode ? welcomeTextSingle : welcomeText

                style: TextAreaStyle {
                    textColor:          qgcPal.text
                    backgroundColor:    qgcPal.windowShade
                }
            }
        } // ColumnLayout
    } // Component
} // SetupPage
