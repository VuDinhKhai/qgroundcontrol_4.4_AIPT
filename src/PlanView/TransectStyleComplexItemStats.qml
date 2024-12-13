import QtQuick          2.3
import QtQuick.Controls 1.2

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controls      1.0

// Phần thống kê cho các mục TransectStyleComplexItems
Grid {
    // Các thuộc tính sau phải có sẵn trong chuỗi phân cấp
    //property var    missionItem       ///< Mục nhiệm vụ cho biên tập viên

    columns:        2
    columnSpacing:  ScreenTools.defaultFontPixelWidth

    QGCLabel { text: qsTr("Diện Tích Khảo Sát") }
    QGCLabel { text: QGroundControl.unitsConversion.squareMetersToAppSettingsAreaUnits(missionItem.coveredArea).toFixed(2) + " " + QGroundControl.unitsConversion.appSettingsAreaUnitsString }

    QGCLabel { text: qsTr("Số Ảnh") }
    QGCLabel { text: missionItem.cameraShots }

    QGCLabel { text: qsTr("Khoảng Thời Gian Ảnh") }
    QGCLabel { text: missionItem.timeBetweenShots.toFixed(1) + " " + qsTr("giây") }

    QGCLabel { text: qsTr("Khoảng Cách Kích Hoạt") }
    QGCLabel { text: missionItem.cameraCalc.adjustedFootprintFrontal.valueString + " " + missionItem.cameraCalc.adjustedFootprintFrontal.units }
}
