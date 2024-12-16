/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick          2.3
import QtQuick.Controls 2.15
import QtQuick.Layouts  1.15
import QtQuick.Dialogs  1.3

import QGroundControl               1.0
import QGroundControl.Controls      1.0
import QGroundControl.Palette       1.0
import QGroundControl.Controllers   1.0
import QGroundControl.FactSystem    1.0
import QGroundControl.FactControls  1.0
import QGroundControl.ScreenTools   1.0

QGCPopupDialog {
    id:         root
    title:      qsTr("Trình biên tập tham số")
    buttons:    StandardButton.Cancel | StandardButton.Save

    property Fact   fact
    property bool   showRCToParam:  false
    property bool   validate:       false
    property string validateValue
    property bool   setFocus:       true    ///< true: focus is set to text field on display, false: focus not set (works around strange virtual keyboard bug with FactValueSlider

    signal valueChanged

    property real   _editFieldWidth:            ScreenTools.defaultFontPixelWidth * 20
    property bool   _longDescriptionAvailable:  fact.longDescription != ""
    property bool   _editingParameter:          fact.componentId != 0
    property bool   _allowForceSave:            QGroundControl.corePlugin.showAdvancedUI || !_editingParameter
    property bool   _allowDefaultReset:         fact.defaultValueAvailable && (QGroundControl.corePlugin.showAdvancedUI || !_editingParameter)
    property bool   _showCombo:                 fact.enumStrings.length !== 0 && fact.bitmaskStrings.length === 0 && !validate

    ParameterEditorController { id: controller; }

    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    onAccepted: {
        if (bitmaskColumn.visible && !manualEntry.checked) {
            fact.value = bitmaskValue();
            fact.valueChanged(fact.value)
            valueChanged()
        } else if (factCombo.visible && !manualEntry.checked) {
            fact.enumIndex = factCombo.currentIndex
            valueChanged()
        } else {
            var errorString = fact.validate(valueField.text, forceSave.checked)
            if (errorString === "") {
                fact.value = valueField.text
                fact.valueChanged(fact.value)
                valueChanged()
            } else {
                validationError.text = errorString
                if (_allowForceSave) {
                    forceSave.visible = true
                }
                preventClose = true
            }
        }
    }

    function reject() {
        fact.valueChanged(fact.value)
        close()
    }

    function bitmaskValue() {
        var value = 0;
        for (var i = 0; i < fact.bitmaskValues.length; ++i) {
            var checkbox = bitmaskRepeater.itemAt(i)
            if (checkbox.checked) {
                value |= fact.bitmaskValues[i];
            }
        }
        return value
    }

    Component.onCompleted: {
        if (validate) {
            validationError.text = fact.validate(validateValue, false /* convertOnly */)
            if (_allowForceSave) {
                forceSave.visible = true
            }
        }
    }

    ColumnLayout {
        width:      editRow.width
        spacing:    globals.defaultTextHeight

        QGCLabel {
            id:                 validationError
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            color:              qgcPal.warningText
            visible:            text !== ""
        }

        RowLayout {
            id:         editRow
            spacing:    ScreenTools.defaultFontPixelWidth

            QGCTextField {
                id:                 valueField
                width:              _editFieldWidth
                text:               validate ? validateValue : fact.valueString
                unitsLabel:         fact.units
                showUnits:          fact.units != ""
                focus:              setFocus && visible
                inputMethodHints:   (fact.typeIsString || ScreenTools.isiOS) ? // iOS numeric keyboard has no done button, we can't use it
                                        Qt.ImhNone :
                                        Qt.ImhFormattedNumbersOnly  // Forces use of virtual numeric keyboard
                visible:            !_showCombo || validate || manualEntry.checked
            }

            QGCComboBox {
                id:         factCombo
                width:      _editFieldWidth
                model:      fact.enumStrings
                visible:    _showCombo
                focus:      setFocus && visible

                Component.onCompleted: {
                    // We can't bind directly to fact.enumIndex since that would add an unknown value
                    // if there are no enum strings.
                    if (_showCombo) {
                        currentIndex = fact.enumIndex
                    }
                }

                onCurrentIndexChanged: {
                    if (currentIndex >=0 && currentIndex < model.length) {
                        valueField.text = fact.enumValues[currentIndex]
                    }
                }
            }

            QGCButton {
                visible:    _allowDefaultReset
                text:       qsTr("Đặt lại về mặc định")

                onClicked: {
                    fact.value = fact.defaultValue
                    fact.valueChanged(fact.value)
                    close()
                }
            }
        }

        Column {
            id:         bitmaskColumn
            spacing:    ScreenTools.defaultFontPixelHeight / 2
            visible:    fact.bitmaskStrings.length > 0

            Repeater {
                id:     bitmaskRepeater
                model:  fact.bitmaskStrings

                delegate : QGCCheckBox {
                    text : modelData
                    checked : fact.value & fact.bitmaskValues[index]

                    onClicked: {
                        valueField.text = bitmaskValue()
                    }
                }
            }
        }

        QGCLabel {
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            visible:            !longDescriptionLabel.visible
            text:               fact.shortDescription
        }

        QGCLabel {
            id:                 longDescriptionLabel
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            visible:            fact.longDescription != ""
            text:               fact.longDescription
        }

        Row {
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                id:         minValueDisplay
                text:       qsTr("Tối thiểu: ") + fact.minString
                visible:    !fact.minIsDefaultForType
            }

            QGCLabel {
                text:       qsTr("Tối đa: ") + fact.maxString
                visible:    !fact.maxIsDefaultForType
            }

            QGCLabel {
                text:       qsTr("Mặc định: ") + fact.defaultValueString
                visible:    _allowDefaultReset
            }
        }

        QGCLabel {
            text:       qsTr("Tên tham số: ") + fact.name
            visible:    fact.componentId > 0 // > 0 means it's a parameter fact
        }

        QGCLabel {
            visible:    fact.vehicleRebootRequired
            text:       qsTr("Phương tiện phải khởi động lại sau khi thay đổi")
        }

        QGCLabel {
            visible:    fact.qgcRebootRequired
            text:       qsTr("Ứng dụng cần khởi động lại sau khi thay đổi")
        }

        QGCLabel {
            Layout.fillWidth:   true
            wrapMode:   Text.WordWrap
            text:       qsTr("Cảnh báo: Việc thay đổi giá trị khi phương tiện đang bay có thể khiến phương tiện mất ổn định và có thể mất phương tiện.") +
                        qsTr("Hãy đảm bảo bạn biết mình đang làm gì và kiểm tra lại các giá trị trước khi Lưu!")
            visible:    fact.componentId != -1
        }

        QGCCheckBox {
            id:         forceSave
            visible:    false
            text:       qsTr("Buộc lưu (nguy hiểm!)")
        }

        QGCCheckBox {
            id:         _advanced
            text:       qsTr("Cài đặt nâng cao")
            visible:    showRCToParam || factCombo.visible || bitmaskColumn.visible
        }

        // Checkbox to allow manual entry of enumerated or bitmask parameters
        QGCCheckBox {
            id:         manualEntry
            visible:    _advanced.checked && (factCombo.visible || bitmaskColumn.visible)
            text:       qsTr("Nhập thủ công")

            onClicked: {
                valueField.text = fact.valueString
            }
        }

        QGCButton {
            text:       qsTr("Đặt RC thành Param")
            visible:    _advanced.checked && !validate && showRCToParam
            onClicked:  rcToParamDialog.createObject(mainWindow).open()
        }
    } // Column

    Component {
        id: rcToParamDialog

        RCToParamDialog {
            tuningFact: fact
        }
    }
}
