/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


import QtQuick                  2.3
import QtQuick.Controls         1.2
import QtQuick.Controls.Styles  1.4
import QtQuick.Dialogs          1.2
import QtQuick.Layouts          1.2

import QGroundControl               1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controls      1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controllers   1.0
import QGroundControl.ArduPilot     1.0
import QGroundControl.QGCPositionManager    1.0

SetupPage {
    id:             sensorsPage
    pageComponent:  sensorsPageComponent

    Component {
        id:             sensorsPageComponent

        Item {
            width:  availableWidth
            height: availableHeight

            // Help text which is shown both in the status text area prior to pressing a cal button and in the
            // pre-calibration dialog.

            readonly property string orientationHelpSet:    qsTr("Nếu được gắn theo hướng bay, chọn Không.")
            readonly property string orientationHelpCal:    qsTr("Trước khi hiệu chuẩn hãy đảm bảo cài đặt xoay là chính xác. ") + orientationHelpSet
            readonly property string compassRotationText:   qsTr("Nếu la bàn hoặc mô-đun GPS được gắn theo hướng bay, giữ giá trị mặc định (Không)")

            readonly property string compassHelp:   qsTr("Để hiệu chuẩn La bàn bạn cần xoay phương tiện qua một số vị trí.")
            readonly property string gyroHelp:      qsTr("Để hiệu chuẩn Con quay hồi chuyển bạn cần đặt phương tiện trên bề mặt và giữ yên.")
            readonly property string accelHelp:     qsTr("Để hiệu chuẩn Gia tốc kế bạn cần đặt phương tiện trên cả sáu mặt trên bề mặt hoàn toàn phẳng và giữ yên ở mỗi hướng trong vài giây.")
            readonly property string levelHelp:     qsTr("Để cân bằng đường chân trời bạn cần đặt phương tiện ở vị trí bay cân bằng và nhấn OK.")

            readonly property string statusTextAreaDefaultText: qsTr("Bắt đầu các bước hiệu chuẩn riêng lẻ bằng cách nhấp vào một trong các nút bên trái.")

            // Used to pass help text to the preCalibrationDialog dialog
            property string preCalibrationDialogHelp

            property string _postCalibrationDialogText
            property var    _postCalibrationDialogParams

            readonly property string _badCompassCalText: qsTr("Hiệu chuẩn cho La bàn %1 có vẻ kém. ") +
                                                         qsTr("Kiểm tra vị trí la bàn trong phương tiện của bạn và hiệu chuẩn lại.")

            readonly property int sideBarH1PointSize:  ScreenTools.mediumFontPointSize
            readonly property int mainTextH1PointSize: ScreenTools.mediumFontPointSize // Seems to be unused

            readonly property int rotationColumnWidth: 250

            property Fact noFact: Fact { }

            property bool accelCalNeeded:                   controller.accelSetupNeeded
            property bool compassCalNeeded:                 controller.compassSetupNeeded

            property Fact boardRot:                         controller.getParameterFact(-1, "AHRS_ORIENTATION")

            readonly property int _calTypeCompass:  1   ///< Calibrate compass
            readonly property int _calTypeAccel:    2   ///< Calibrate accel
            readonly property int _calTypeSet:      3   ///< Set orientations only
            readonly property int _buttonWidth:     ScreenTools.defaultFontPixelWidth * 15

            property bool   _orientationsDialogShowCompass: true
            property string _orientationDialogHelp:         orientationHelpSet
            property int    _orientationDialogCalType
            property real   _margins:                       ScreenTools.defaultFontPixelHeight / 2
            property bool   _compassAutoRotAvailable:       controller.parameterExists(-1, "COMPASS_AUTO_ROT")
            property Fact   _compassAutoRotFact:            controller.getParameterFact(-1, "COMPASS_AUTO_ROT", false /* reportMissing */)
            property bool   _compassAutoRot:                _compassAutoRotAvailable ? _compassAutoRotFact.rawValue == 2 : false
            property bool   _showSimpleAccelCalOption:      false
            property bool   _doSimpleAccelCal:              false
            property var    _gcsPosition:                    QGroundControl.qgcPositionManger.gcsPosition
            property var    _mapPosition:                    QGroundControl.flightMapPosition

            function showOrientationsDialog(calType) {
                var dialogTitle
                var dialogButtons = StandardButton.Ok
                _showSimpleAccelCalOption = false

                _orientationDialogCalType = calType
                switch (calType) {
                case _calTypeCompass:
                    _orientationsDialogShowCompass = true
                    _orientationDialogHelp = orientationHelpCal
                    dialogTitle = qsTr("Hiệu chuẩn La bàn")
                    dialogButtons |= StandardButton.Cancel
                    break
                case _calTypeAccel:
                    _orientationsDialogShowCompass = false
                    _orientationDialogHelp = orientationHelpCal
                    dialogTitle = qsTr("Hiệu chuẩn Gia tốc kế")
                    dialogButtons |= StandardButton.Cancel
                    break
                case _calTypeSet:
                    _orientationsDialogShowCompass = true
                    _orientationDialogHelp = orientationHelpSet
                    dialogTitle = qsTr("Cài đặt Cảm biến")
                    break
                }

                orientationsDialogComponent.createObject(mainWindow, { title: dialogTitle, buttons: dialogButtons }).open()
            }

            function showSimpleAccelCalOption() {
                _showSimpleAccelCalOption = true
            }

            function compassLabel(index) {
                var label = qsTr("La bàn %1 ").arg(index+1)
                var addOpenParan = true
                var addComma = false
                if (sensorParams.compassPrimaryFactAvailable) {
                    label += sensorParams.rgCompassPrimary[index] ? qsTr("(chính") : qsTr("(phụ")
                    addComma = true
                    addOpenParan = false
                }
                if (sensorParams.rgCompassExternalParamAvailable[index]) {
                    if (addOpenParan) {
                        label += "("
                    }
                    if (addComma) {
                        label += qsTr(", ")
                    }
                    label += sensorParams.rgCompassExternal[index] ? qsTr("ngoài") : qsTr("trong")
                }
                label += ")"
                return label
            }

            APMSensorParams {
                id:                     sensorParams
                factPanelController:    controller
            }

            APMSensorsComponentController {
                id:                         controller
                statusLog:                  statusTextArea
                progressBar:                progressBar
                nextButton:                 nextButton
                cancelButton:               cancelButton
                orientationCalAreaHelpText: orientationCalAreaHelpText

                property var rgCompassCalFitness: [ controller.compass1CalFitness, controller.compass2CalFitness, controller.compass3CalFitness ]

                onResetStatusTextArea: statusLog.text = statusTextAreaDefaultText

                onWaitingForCancelChanged: {
                    if (controller.waitingForCancel) {
                        waitForCancelDialogComponent.createObject(mainWindow).open()
                    }
                }

                onCalibrationComplete: {
                    switch (calType) {
                    case APMSensorsComponentController.CalTypeAccel:
                    case APMSensorsComponentController.CalTypeOnboardCompass:
                        _singleCompassSettingsComponentShowPriority = true
                        postOnboardCompassCalibrationComponent.createObject(mainWindow).open()
                        break
                    }
                }

                onSetAllCalButtonsEnabled: {
                    buttonColumn.enabled = enabled
                }
            }

            QGCPalette { id: qgcPal; colorGroupEnabled: true }

            Component {
                id: waitForCancelDialogComponent

                QGCSimpleMessageDialog {
                    title:      qsTr("Hủy Hiệu chuẩn")
                    text:       qsTr("Đang đợi Phương tiện phản hồi để Hủy. Điều này có thể mất vài giây.")
                    buttons:    0

                    Connections {
                        target: controller

                        onWaitingForCancelChanged: {
                            if (!controller.waitingForCancel) {
                                close()
                            }
                        }
                    }
                }
            }

            Component {
                id: singleCompassOnboardResultsComponent

                Column {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    spacing:        Math.round(ScreenTools.defaultFontPixelHeight / 2)
                    visible:        sensorParams.rgCompassAvailable[index] && sensorParams.rgCompassUseFact[index].value

                    property int _index: index

                    property real greenMaxThreshold:   8 * (sensorParams.rgCompassExternal[index] ? 1 : 2)
                    property real yellowMaxThreshold:  15 * (sensorParams.rgCompassExternal[index] ? 1 : 2)
                    property real fitnessRange:        25 * (sensorParams.rgCompassExternal[index] ? 1 : 2)

                    Item {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        height:         ScreenTools.defaultFontPixelHeight

                        Row {
                            id:             fitnessRow
                            anchors.fill:   parent

                            Rectangle {
                                width:  parent.width * (greenMaxThreshold / fitnessRange)
                                height: parent.height
                                color:  "green"
                            }
                            Rectangle {
                                width:  parent.width * ((yellowMaxThreshold - greenMaxThreshold) / fitnessRange)
                                height: parent.height
                                color:  "yellow"
                            }
                            Rectangle {
                                width:  parent.width * ((fitnessRange - yellowMaxThreshold) / fitnessRange)
                                height: parent.height
                                color:  "red"
                            }
                        }

                        Rectangle {
                            height:                 fitnessRow.height * 0.66
                            width:                  height
                            anchors.verticalCenter: fitnessRow.verticalCenter
                            x:                      (fitnessRow.width * (Math.min(Math.max(controller.rgCompassCalFitness[index], 0.0), fitnessRange) / fitnessRange)) - (width / 2)
                            radius:                 height / 2
                            color:                  "white"
                            border.color:           "black"
                        }
                    }

                    Loader {
                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        sourceComponent:    singleCompassSettingsComponent

                        property int index: _index
                    }
                }
            }

            Component {
                id: postOnboardCompassCalibrationComponent

                QGCPopupDialog {
                    id:         postOnboardCompassCalibrationDialog
                    title:      qsTr("Hiệu chuẩn hoàn tất")
                    buttons:    StandardButton.Ok

                    Column {
                        width:      40 * ScreenTools.defaultFontPixelWidth
                        spacing:    ScreenTools.defaultFontPixelHeight

                        Repeater {
                            model:      3
                            delegate:   singleCompassOnboardResultsComponent
                        }

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("Hiển thị trong các thanh chỉ báo là chất lượng hiệu chuẩn cho mỗi la bàn.\n\n") +
                                            qsTr("- Màu xanh lá cây chỉ ra la bàn hoạt động tốt.\n") +
                                            qsTr("- Màu vàng chỉ ra la bàn hoặc hiệu chuẩn đáng ngờ.\n") +
                                            qsTr("- Màu đỏ chỉ ra la bàn không nên sử dụng.\n\n") +
                                            qsTr("BẠN PHẢI KHỞI ĐỘNG LẠI PHƯƠNG TIỆN SAU MỖI LẦN HIỆU CHUẨN.")
                        }

                        QGCButton {
                            text:       qsTr("Khởi động lại Phương tiện")
                            onClicked: {
                                controller.vehicle.rebootVehicle()
                                postOnboardCompassCalibrationDialog.close()
                            }
                        }
                    }
                }
            }

            Component {
                id: postCalibrationComponent

                QGCPopupDialog {
                    id:     postCalibrationDialog
                    title:  qsTr("Hiệu chuẩn hoàn tất")

                    Column {
                        width:      40 * ScreenTools.defaultFontPixelWidth
                        spacing:    ScreenTools.defaultFontPixelHeight

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("BẠN PHẢI KHỞI ĐỘNG LẠI PHƯƠNG TIỆN SAU MỖI LẦN HIỆU CHUẨN.")
                        }

                        QGCButton {
                            text:       qsTr("Khởi động lại Phương tiện")
                            onClicked: {
                                controller.vehicle.rebootVehicle()
                                postCalibrationDialog.close()
                            }
                        }
                    }
                }
            }

            property bool _singleCompassSettingsComponentShowPriority: true
            Component {
                id: singleCompassSettingsComponent

                Column {
                    spacing: Math.round(ScreenTools.defaultFontPixelHeight / 2)
                    visible: sensorParams.rgCompassAvailable[index]

                    QGCLabel {
                        text: compassLabel(index)
                    }
                    APMSensorIdDecoder {
                        fact: sensorParams.rgCompassId[index]
                    }

                    Column {
                        anchors.margins:    ScreenTools.defaultFontPixelWidth * 2
                        anchors.left:       parent.left
                        spacing:            Math.round(ScreenTools.defaultFontPixelHeight / 4)

                        RowLayout {
                            spacing: ScreenTools.defaultFontPixelWidth

                            FactCheckBox {
                                id:         useCompassCheckBox
                                text:       qsTr("Sử dụng La bàn")
                                fact:       sensorParams.rgCompassUseFact[index]
                                visible:    sensorParams.rgCompassUseParamAvailable[index] && !sensorParams.rgCompassPrimary[index]
                            }

                            QGCComboBox {
                                model:      [ qsTr("Ưu tiên 1"), qsTr("Ưu tiên 2"), qsTr("Ưu tiên 3"), qsTr("Chưa đặt") ]
                                visible:    _singleCompassSettingsComponentShowPriority && sensorParams.compassPrioFactsAvailable && useCompassCheckBox.visible && useCompassCheckBox.checked

                                property int _compassIndex: index

                                function selectPriorityfromParams() {
                                    currentIndex = 3
                                    var compassId = sensorParams.rgCompassId[_compassIndex].rawValue
                                    for (var prioIndex=0; prioIndex<3; prioIndex++) {
                                        console.log(`comparing ${compassId} with ${sensorParams.rgCompassPrio[prioIndex].rawValue} (index ${prioIndex})`)
                                        if (compassId == sensorParams.rgCompassPrio[prioIndex].rawValue) {
                                            currentIndex = prioIndex
                                            break
                                        }
                                    }
                                }

                                Component.onCompleted: selectPriorityfromParams()

                                onActivated: {
                                    if (index == 3) {
                                        // User cannot select Not Set
                                        selectPriorityfromParams()
                                    } else {
                                        sensorParams.rgCompassPrio[index].rawValue = sensorParams.rgCompassId[_compassIndex].rawValue
                                    }
                                }
                            }
                        }

                        Column {
                            visible: !_compassAutoRot && sensorParams.rgCompassExternal[index] && sensorParams.rgCompassRotParamAvailable[index]

                            QGCLabel { text: qsTr("Hướng:") }

                            FactComboBox {
                                width:      rotationColumnWidth
                                indexModel: false
                                fact:       sensorParams.rgCompassRotFact[index]
                            }
                        }
                    }
                }
            }

            Component {
                id: orientationsDialogComponent

                QGCPopupDialog {
                    function compassMask () {
                        var mask = 0
                        mask |=  (0 + (sensorParams.rgCompassPrio[0].rawValue !== 0)) << 0
                        mask |=  (0 + (sensorParams.rgCompassPrio[1].rawValue !== 0)) << 1
                        mask |=  (0 + (sensorParams.rgCompassPrio[2].rawValue !== 0)) << 2
                        return mask
                    }

                    onAccepted: {
                        if (_orientationDialogCalType == _calTypeAccel) {
                            controller.calibrateAccel(_doSimpleAccelCal)
                        } else if (_orientationDialogCalType == _calTypeCompass) {
                            if (!northCalibrationCheckBox.checked) {
                                controller.calibrateCompass()
                            } else {
                                var lat = parseFloat(northCalLat.text)
                                var lon = parseFloat(northCalLon.text)
                                if (useMapPositionCheckbox.checked) {
                                    lat = _mapPosition.latitude
                                    lon = _mapPosition.longitude
                                }
                                if (useGcsPositionCheckbox.checked) {
                                    lat = _gcsPosition.latitude
                                    lon = _gcsPosition.longitude
                                }
                                if (isNaN(lat) || isNaN(lon)) {
                                    return
                                }
                                controller.calibrateCompassNorth(lat, lon, compassMask())
                            }
                        }
                    }

                    Column {
                        width:      40 * ScreenTools.defaultFontPixelWidth
                        spacing:    ScreenTools.defaultFontPixelHeight

                        QGCLabel {
                            width:      parent.width
                            wrapMode:   Text.WordWrap
                            text:       _orientationDialogHelp
                        }

                        Column {
                            QGCLabel { text: qsTr("Xoay Autopilot:") }

                            FactComboBox {
                                width:      rotationColumnWidth
                                indexModel: false
                                fact:       boardRot
                            }
                        }

                        Column {

                            visible: _orientationDialogCalType == _calTypeAccel
                            spacing: ScreenTools.defaultFontPixelHeight

                            QGCLabel {
                                width:      parent.width
                                wrapMode:   Text.WordWrap
                                text: qsTr("Hiệu chuẩn gia tốc kế đơn giản kém chính xác hơn nhưng cho phép hiệu chuẩn mà không cần xoay phương tiện. Chọn cái này nếu bạn có phương tiện lớn/nặng.")
                            }

                            QGCCheckBox {
                                text: "Hiệu chuẩn Gia tốc kế Đơn giản"
                                onClicked: _doSimpleAccelCal = this.checked
                            }
                        }

                        Repeater {
                            model:      _orientationsDialogShowCompass ? 3 : 0
                            delegate:   singleCompassSettingsComponent
                        }

                        QGCLabel {
                            id:         magneticDeclinationLabel
                            width:      parent.width
                            visible:    globals.activeVehicle.sub && _orientationsDialogShowCompass
                            text:       qsTr("Độ lệch Từ")
                        }

                        Column {
                            visible:            magneticDeclinationLabel.visible
                            anchors.margins:    ScreenTools.defaultFontPixelWidth
                            anchors.left:       parent.left
                            anchors.right:      parent.right
                            spacing:            ScreenTools.defaultFontPixelHeight

                            QGCCheckBox {
                                id:                           manualMagneticDeclinationCheckBox
                                text:                         qsTr("Độ lệch Từ Thủ công")
                                property Fact autoDecFact:    controller.getParameterFact(-1, "COMPASS_AUTODEC")
                                property int manual:          0
                                property int automatic:       1

                                checked:    autoDecFact.rawValue === manual
                                onClicked:  autoDecFact.value = (checked ? manual : automatic)
                            }

                            FactTextField {
                                fact:       sensorParams.declinationFact
                                enabled:    manualMagneticDeclinationCheckBox.checked
                            }
                        }

                        Item { height: ScreenTools.defaultFontPixelHeight; width: 10 } // spacer

                        QGCLabel {
                            id:         northCalibrationLabel
                            width:      parent.width
                            visible:    _orientationsDialogShowCompass
                            wrapMode:   Text.WordWrap
                            text:       qsTr("Hiệu chuẩn la bàn nhanh dựa trên vị trí và hướng phương tiện. Điều này ") +
                                        qsTr("dẫn đến các phần tử đường chéo và ngoài đường chéo bằng không, nên chỉ ") +
                                        qsTr("phù hợp cho phương tiện có từ trường gần như hình cầu. Nó ") +
                                        qsTr("hữu ích cho phương tiện lớn khi việc di chuyển phương tiện để hiệu chuẩn ") +
                                        qsTr("là khó khăn. Hướng phương tiện về phía Bắc trước khi sử dụng.")
                        }

                        Column {
                            visible:            northCalibrationLabel.visible
                            anchors.margins:    ScreenTools.defaultFontPixelWidth
                            anchors.left:       parent.left
                            anchors.right:      parent.right
                            spacing:            ScreenTools.defaultFontPixelHeight

                            QGCCheckBox {
                                id:             northCalibrationCheckBox
                                visible:        northCalibrationLabel.visible
                                text:           qsTr("Hiệu chuẩn Nhanh")
                            }

                            QGCLabel {
                                id:         northCalibrationManualPosition
                                width:      parent.width
                                visible:    northCalibrationCheckBox.checked && !globals.activeVehicle.coordinate.isValid
                                wrapMode:   Text.WordWrap
                                text:       qsTr("Phương tiện không có vị trí Hợp lệ, vui lòng cung cấp")
                            }

                            QGCCheckBox {
                                visible:    northCalibrationManualPosition.visible && _gcsPosition.isValid
                                id:         useGcsPositionCheckbox
                                text:       qsTr("Sử dụng vị trí GCS thay thế")
                                checked:    _gcsPosition.isValid
                            }
                            QGCCheckBox {
                                visible:    northCalibrationManualPosition.visible && !_gcsPosition.isValid
                                id:         useMapPositionCheckbox
                                text:       qsTr("Sử dụng vị trí bản đồ hiện tại thay thế")
                            }

                            QGCLabel {
                                width:      parent.width
                                visible:    useMapPositionCheckbox.checked
                                wrapMode:   Text.WordWrap
                                text:       qsTr(`Vĩ độ: ${_mapPosition.latitude.toFixed(4)} Kinh độ: ${_mapPosition.longitude.toFixed(4)}`)
                            }

                            FactTextField {
                                id:         northCalLat
                                visible:    !useGcsPositionCheckbox.checked && !useMapPositionCheckbox.checked && northCalibrationCheckBox.checked
                                text:       "0.00"
                                textColor:  isNaN(parseFloat(text)) ? qgcPal.warningText: qgcPal.textFieldText
                                enabled:    !useGcsPositionCheckbox.checked
                            }
                            FactTextField {
                                id:         northCalLon
                                visible:    !useGcsPositionCheckbox.checked && !useMapPositionCheckbox.checked && northCalibrationCheckBox.checked
                                text:       "0.00"
                                textColor:  isNaN(parseFloat(text)) ? qgcPal.warningText: qgcPal.textFieldText
                                enabled:    !useGcsPositionCheckbox.checked
                            }

                        }
                    }
                }
            }

            Component {
                id: compassMotDialogComponent

                QGCPopupDialog {
                    title:      qsTr("Hiệu chuẩn Nhiễu động Cơ La bàn")
                    buttons:    StandardButton.Cancel | StandardButton.Ok

                    onAccepted: controller.calibrateMotorInterference()

                    Column {
                        width:      40 * ScreenTools.defaultFontPixelWidth
                        spacing:    ScreenTools.defaultFontPixelHeight

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("Điều này được khuyến nghị cho phương tiện chỉ có la bàn bên trong và trên phương tiện có nhiễu đáng kể trên la bàn từ động cơ, dây điện, v.v. ") +
                                            qsTr("CompassMot chỉ hoạt động tốt nếu bạn có màn hình theo dõi dòng điện pin vì nhiễu từ tỷ lệ thuận với dòng điện tiêu thụ. ") +
                                            qsTr("Về mặt kỹ thuật có thể thiết lập CompassMot bằng ga nhưng điều này không được khuyến nghị.")
                        }

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("Ngắt kết nối cánh quạt, lật ngược chúng và xoay chúng một vị trí quanh khung. ") +
                                            qsTr("Trong cấu hình này chúng nên đẩy máy bay xuống mặt đất khi tăng ga.")
                        }

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("Cố định máy bay (có thể bằng băng dính) để nó không di chuyển.")
                        }

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("Bật bộ phát và giữ ga ở mức không.")
                        }

                        QGCLabel {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            wrapMode:       Text.WordWrap
                            text:           qsTr("Nhấp Ok để bắt đầu hiệu chuẩn CompassMot.")
                        }
                    }
                }
            }

            QGCFlickable {
                id:             buttonFlickable
                anchors.left:   parent.left
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                width:          _buttonWidth
                contentHeight:  nextCancelColumn.y + nextCancelColumn.height + _margins

                // Calibration button column - Calibratin buttons are kept in a separate column from Next/Cancel buttons
                // so we can enable/disable them all as a group
                Column {
                    id:                 buttonColumn
                    spacing:            _margins
                    Layout.alignment:   Qt.AlignLeft | Qt.AlignTop

                    IndicatorButton {
                        width:          _buttonWidth
                        text:           qsTr("Gia tốc kế")
                        indicatorGreen: !accelCalNeeded

                        onClicked: function () {
                            showOrientationsDialog(_calTypeAccel);
                            showSimpleAccelCalOption();
                        }
                    }

                    IndicatorButton {
                        width:          _buttonWidth
                        text:           qsTr("La bàn")
                        indicatorGreen: !compassCalNeeded

                        onClicked: {
                            if (controller.accelSetupNeeded) {
                                mainWindow.showMessageDialog(qsTr("Hiệu chuẩn La bàn"), qsTr("Gia tốc kế phải được hiệu chuẩn trước La bàn."))
                            } else {
                                showOrientationsDialog(_calTypeCompass)
                            }
                        }
                    }

                    QGCButton {
                        width:  _buttonWidth
                        text:   _levelHorizonText

                        readonly property string _levelHorizonText: qsTr("Cân bằng đường chân trời")

                        onClicked: {
                            if (controller.accelSetupNeeded) {
                                mainWindow.showMessageDialog(_levelHorizonText, qsTr("Gia tốc kế phải được hiệu chuẩn trước khi Cân bằng đường chân trời."))
                            } else {
                                mainWindow.showMessageDialog(_levelHorizonText,
                                                             qsTr("Để cân bằng đường chân trời bạn cần đặt phương tiện ở vị trí bay cân bằng và nhấn Ok."),
                                                             StandardButton.Cancel | StandardButton.Ok,
                                                             function() { controller.levelHorizon() })
                            }
                        }
                    }

                    QGCButton {
                        width:      _buttonWidth
                        text:       qsTr("Con quay hồi chuyển")
                        visible:    globals.activeVehicle && (globals.activeVehicle.multiRotor | globals.activeVehicle.rover | globals.activeVehicle.sub)
                        onClicked:  mainWindow.showMessageDialog(qsTr("Hiệu chuẩn Con quay hồi chuyển"),
                                                                 qsTr("Để hiệu chuẩn Con quay hồi chuyển bạn cần đặt phương tiện trên bề mặt và giữ yên.\n\nNhấn Ok để bắt đầu hiệu chuẩn."),
                                                                 StandardButton.Cancel | StandardButton.Ok,
                                                                 function() { controller.calibrateGyro() })
                    }

                    QGCButton {
                        width:      _buttonWidth
                        text:       _calibratePressureText
                        onClicked:  mainWindow.showMessageDialog(_calibratePressureText,
                                                                 qsTr("Hiệu chuẩn áp suất sẽ đặt %1 về không tại chỉ số áp suất hiện tại. %2").arg(_altText).arg(_helpTextFW),
                                                                 StandardButton.Cancel | StandardButton.Ok,
                                                                 function() { controller.calibratePressure() })

                        readonly property string _altText:                  globals.activeVehicle.sub ? qsTr("độ sâu") : qsTr("độ cao")
                        readonly property string _helpTextFW:               globals.activeVehicle.fixedWing ? qsTr("Để hiệu chuẩn cảm biến tốc độ không khí hãy che chắn nó khỏi gió. Không chạm vào cảm biến hoặc chặn bất kỳ lỗ nào trong quá trình hiệu chuẩn.") : ""
                        readonly property string _calibratePressureText:    globals.activeVehicle.fixedWing ? qsTr("Khí áp/Tốc độ không khí") : qsTr("Áp suất")
                    }

                    QGCButton {
                        width:      _buttonWidth
                        text:       qsTr("Nhiễu động Cơ La bàn")
                        visible:    globals.activeVehicle ? globals.activeVehicle.supportsMotorInterference : false
                        onClicked:  compassMotDialogComponent.createObject(mainWindow).open()
                    }

                    QGCButton {
                        width:      _buttonWidth
                        text:       qsTr("Cài đặt Cảm biến")
                        onClicked:  showOrientationsDialog(_calTypeSet)
                    }
                } // Column - Cal Buttons

                Column {
                    id:                 nextCancelColumn
                    anchors.topMargin:  buttonColumn.spacing
                    anchors.top:        buttonColumn.bottom
                    anchors.left:       buttonColumn.left
                    spacing:            buttonColumn.spacing

                    QGCButton {
                        id:         nextButton
                        width:      _buttonWidth
                        text:       qsTr("Tiếp theo")
                        enabled:    false
                        onClicked:  controller.nextClicked()
                    }

                    QGCButton {
                        id:         cancelButton
                        width:      _buttonWidth
                        text:       qsTr("Hủy")
                        enabled:    false
                        onClicked:  controller.cancelCalibration()
                    }
                }
            } // QGCFlickable - buttons

            /// Right column - cal area
            Column {
                anchors.leftMargin: _margins
                anchors.top:        parent.top
                anchors.bottom:     parent.bottom
                anchors.left:       buttonFlickable.right
                anchors.right:      parent.right

                ProgressBar {
                    id:             progressBar
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                }

                Item { height: ScreenTools.defaultFontPixelHeight; width: 10 } // spacer

                Item {
                    id:     centerPanel
                    width:  parent.width
                    height: parent.height - y

                    TextArea {
                        id:             statusTextArea
                        anchors.fill:   parent
                        readOnly:       true
                        frameVisible:   false
                        text:           statusTextAreaDefaultText

                        style: TextAreaStyle {
                            textColor:          qgcPal.text
                            backgroundColor:    qgcPal.windowShade
                        }
                    }

                    Rectangle {
                        id:             orientationCalArea
                        anchors.fill:   parent
                        visible:        controller.showOrientationCalArea
                        color:          qgcPal.windowShade

                        QGCLabel {
                            id:                 orientationCalAreaHelpText
                            anchors.margins:    ScreenTools.defaultFontPixelWidth
                            anchors.top:        orientationCalArea.top
                            anchors.left:       orientationCalArea.left
                            width:              parent.width
                            wrapMode:           Text.WordWrap
                            font.pointSize:     ScreenTools.mediumFontPointSize
                        }

                        Flow {
                            anchors.topMargin:  ScreenTools.defaultFontPixelWidth
                            anchors.top:        orientationCalAreaHelpText.bottom
                            anchors.bottom:     parent.bottom
                            anchors.left:       parent.left
                            anchors.right:      parent.right
                            spacing:            ScreenTools.defaultFontPixelWidth

                            property real indicatorWidth:   (width / 3) - (spacing * 2)
                            property real indicatorHeight:  (height / 2) - spacing

                            VehicleRotationCal {
                                width:              parent.indicatorWidth
                                height:             parent.indicatorHeight
                                visible:            controller.orientationCalDownSideVisible
                                calValid:           controller.orientationCalDownSideDone
                                calInProgress:      controller.orientationCalDownSideInProgress
                                calInProgressText:  controller.orientationCalDownSideRotate ? qsTr("Xoay") : qsTr("Giữ yên")
                                imageSource:        "qrc:///qmlimages/VehicleDown.png"
                            }
                            VehicleRotationCal {
                                width:              parent.indicatorWidth
                                height:             parent.indicatorHeight
                                visible:            controller.orientationCalLeftSideVisible
                                calValid:           controller.orientationCalLeftSideDone
                                calInProgress:      controller.orientationCalLeftSideInProgress
                                calInProgressText:  controller.orientationCalLeftSideRotate ? qsTr("Xoay") : qsTr("Giữ yên")
                                imageSource:        "qrc:///qmlimages/VehicleLeft.png"
                            }
                            VehicleRotationCal {
                                width:              parent.indicatorWidth
                                height:             parent.indicatorHeight
                                visible:            controller.orientationCalRightSideVisible
                                calValid:           controller.orientationCalRightSideDone
                                calInProgress:      controller.orientationCalRightSideInProgress
                                calInProgressText:  controller.orientationCalRightSideRotate ? qsTr("Xoay") : qsTr("Giữ yên")
                                imageSource:        "qrc:///qmlimages/VehicleRight.png"
                            }
                            VehicleRotationCal {
                                width:              parent.indicatorWidth
                                height:             parent.indicatorHeight
                                visible:            controller.orientationCalNoseDownSideVisible
                                calValid:           controller.orientationCalNoseDownSideDone
                                calInProgress:      controller.orientationCalNoseDownSideInProgress
                                calInProgressText:  controller.orientationCalNoseDownSideRotate ? qsTr("Xoay") : qsTr("Giữ yên")
                                imageSource:        "qrc:///qmlimages/VehicleNoseDown.png"
                            }
                            VehicleRotationCal {
                                width:              parent.indicatorWidth
                                height:             parent.indicatorHeight
                                visible:            controller.orientationCalTailDownSideVisible
                                calValid:           controller.orientationCalTailDownSideDone
                                calInProgress:      controller.orientationCalTailDownSideInProgress
                                calInProgressText:  controller.orientationCalTailDownSideRotate ? qsTr("Xoay") : qsTr("Giữ yên")
                                imageSource:        "qrc:///qmlimages/VehicleTailDown.png"
                            }
                            VehicleRotationCal {
                                width:              parent.indicatorWidth
                                height:             parent.indicatorHeight
                                visible:            controller.orientationCalUpsideDownSideVisible
                                calValid:           controller.orientationCalUpsideDownSideDone
                                calInProgress:      controller.orientationCalUpsideDownSideInProgress
                                calInProgressText:  controller.orientationCalUpsideDownSideRotate ? qsTr("Xoay") : qsTr("Giữ yên")
                                imageSource:        "qrc:///qmlimages/VehicleUpsideDown.png"
                            }
                        }
                    }
                } // Item - Cal display area
            } // Column - cal display
        } // Row
    } // Component - sensorsPageComponent
} // SetupPage
