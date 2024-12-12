/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

import QtQuick                  2.11
import QtQuick.Controls         2.4
import QtQuick.Layouts          1.11
import QtQuick.Dialogs          1.3
import QtQuick.Controls.Styles  1.4
import QtLocation               5.3
import QtPositioning            5.3

import QGroundControl                       1.0
import QGroundControl.Controls              1.0
import QGroundControl.ScreenTools           1.0
import QGroundControl.Palette               1.0
import QGroundControl.FlightMap             1.0
import QGroundControl.QGCMapEngineManager   1.0
import QGroundControl.FactSystem            1.0
import QGroundControl.FactControls          1.0

Item {
    id:             offlineMapView
    anchors.fill:   parent

    property var    _currentSelection:  null

    property string mapKey:             "lastMapType"

    property var    _settingsManager:   QGroundControl.settingsManager
    property var    _settings:          _settingsManager ? _settingsManager.offlineMapsSettings : null
    property var    _fmSettings:        _settingsManager ? _settingsManager.flightMapSettings : null
    property var    _appSettings:       _settingsManager.appSettings
    property Fact   _mapboxFact:        _settingsManager ? _settingsManager.appSettings.mapboxToken : null
    property Fact   _mapboxAccountFact: _settingsManager ? _settingsManager.appSettings.mapboxAccount : null
    property Fact   _mapboxStyleFact:   _settingsManager ? _settingsManager.appSettings.mapboxStyle : null
    property Fact   _esriFact:          _settingsManager ? _settingsManager.appSettings.esriToken : null
    property Fact   _customURLFact:     _settingsManager ? _settingsManager.appSettings.customURL : null
    property Fact   _vworldFact:        _settingsManager ? _settingsManager.appSettings.vworldToken : null

    property string mapType:            _fmSettings ? (_fmSettings.mapProvider.value + " " + _fmSettings.mapType.value) : ""
    property bool   isMapInteractive:   false
    property var    savedCenter:        undefined
    property real   savedZoom:          3
    property string savedMapType:       ""
    property bool   _showPreview:       true
    property bool   _defaultSet:        offlineMapView && offlineMapView._currentSelection && offlineMapView._currentSelection.defaultSet
    property real   _margins:           ScreenTools.defaultFontPixelWidth * 0.5
    property real   _buttonSize:        ScreenTools.defaultFontPixelWidth * 12
    property real   _bigButtonSize:     ScreenTools.defaultFontPixelWidth * 16

    property bool   _saveRealEstate:          ScreenTools.isTinyScreen || ScreenTools.isShortScreen
    property real   _adjustableFontPointSize: _saveRealEstate ? ScreenTools.smallFontPointSize : ScreenTools.defaultFontPointSize

    property var    _mapAdjustedColor:  _map.isSatelliteMap ? "white" : "black"
    property bool   _tooManyTiles:      QGroundControl.mapEngineManager.tileCount > _maxTilesForDownload

    readonly property real minZoomLevel:    1
    readonly property real maxZoomLevel:    20
    readonly property real sliderTouchArea: ScreenTools.defaultFontPixelWidth * (ScreenTools.isTinyScreen ? 5 : (ScreenTools.isMobile ? 6 : 3))

    readonly property int _maxTilesForDownload: _settings ? _settings.maxTilesForDownload.rawValue : 0

    QGCPalette { id: qgcPal }

    Component.onCompleted: {
        QGroundControl.mapEngineManager.loadTileSets()
        updateMap()
        savedCenter = _map.toCoordinate(Qt.point(_map.width / 2, _map.height / 2), false /* clipToViewPort */)
    }

    Connections {
        target: QGroundControl.mapEngineManager
        onTileSetsChanged: {
            setName.text = QGroundControl.mapEngineManager.getUniqueName()
        }
        onErrorMessageChanged: {
            errorDialog.visible = true
        }
    }

    function handleChanges() {
        if(isMapInteractive) {
            var xl = 0
            var yl = 0
            var xr = _map.width.toFixed(0) - 1  // Must be within boundaries of visible map
            var yr = _map.height.toFixed(0) - 1 // Must be within boundaries of visible map
            var c0 = _map.toCoordinate(Qt.point(xl, yl), false /* clipToViewPort */)
            var c1 = _map.toCoordinate(Qt.point(xr, yr), false /* clipToViewPort */)
            QGroundControl.mapEngineManager.updateForCurrentView(c0.longitude, c0.latitude, c1.longitude, c1.latitude, sliderMinZoom.value, sliderMaxZoom.value, mapType)
        }
    }

    function updateMap() {
        for (var i = 0; i < _map.supportedMapTypes.length; i++) {
            if (mapType === _map.supportedMapTypes[i].name) {
                _map.activeMapType = _map.supportedMapTypes[i]
                handleChanges()
                return
            }
        }
    }

    function addNewSet() {
        isMapInteractive = true
        mapType = _fmSettings.mapProvider.value + " " + _fmSettings.mapType.value
        resetMapToDefaults()
        handleChanges()
        _map.visible = true
        _tileSetList.visible = false
        infoView.visible = false
        _exporTiles.visible = false
        addNewSetView.visible = true
    }

    function showList() {
        _exporTiles.visible = false
        isMapInteractive = false
        _map.visible = false
        _tileSetList.visible = true
        infoView.visible = false
        addNewSetView.visible = false
        QGroundControl.mapEngineManager.resetAction();
    }

    function showExport() {
        isMapInteractive = false
        _map.visible = false
        _tileSetList.visible = false
        infoView.visible = false
        addNewSetView.visible = false
        _exporTiles.visible = true
    }

    function showInfo() {
        isMapInteractive = false
        if(_currentSelection && !offlineMapView._currentSelection.deleting) {
            enterInfoView()
        } else
            showList()
    }

    function toRadian(deg) {
        return deg * Math.PI / 180
    }

    function toDegree(rad) {
        return rad * 180 / Math.PI
    }

    function midPoint(lat1, lat2, lon1, lon2) {
        var dLon = toRadian(lon2 - lon1);
        lat1 = toRadian(lat1);
        lat2 = toRadian(lat2);
        lon1 = toRadian(lon1);
        var Bx = Math.cos(lat2) * Math.cos(dLon);
        var By = Math.cos(lat2) * Math.sin(dLon);
        var lat3 = Math.atan2(Math.sin(lat1) + Math.sin(lat2), Math.sqrt((Math.cos(lat1) + Bx) * (Math.cos(lat1) + Bx) + By * By));
        var lon3 = lon1 + Math.atan2(By, Math.cos(lat1) + Bx);
        return QtPositioning.coordinate(toDegree(lat3), toDegree(lon3))
    }

    function enterInfoView() {
        _map.visible = true
        isMapInteractive = false
        savedCenter = _map.toCoordinate(Qt.point(_map.width / 2, _map.height / 2), false /* clipToViewPort */)
        savedZoom = _map.zoomLevel
        savedMapType = mapType
        if(!offlineMapView._currentSelection.defaultSet) {
            mapType = offlineMapView._currentSelection.mapTypeStr
            _map.center = midPoint(offlineMapView._currentSelection.topleftLat, offlineMapView._currentSelection.bottomRightLat, offlineMapView._currentSelection.topleftLon, offlineMapView._currentSelection.bottomRightLon)
            //-- Delineate Set Region
            var x0 = offlineMapView._currentSelection.topleftLon
            var x1 = offlineMapView._currentSelection.bottomRightLon
            var y0 = offlineMapView._currentSelection.topleftLat
            var y1 = offlineMapView._currentSelection.bottomRightLat
            mapBoundary.topLeft     = QtPositioning.coordinate(y0, x0)
            mapBoundary.bottomRight = QtPositioning.coordinate(y1, x1)
            mapBoundary.visible = true
            // Some times, for whatever reason, the bounding box is correct (around ETH for instance), but the rectangle is drawn across the planet.
            // When that happens, the "_map.fitViewportToMapItems()" below makes the map to zoom to the entire earth.
            //console.log("Map boundary: " + mapBoundary.topLeft + " " + mapBoundary.bottomRight)
            _map.fitViewportToMapItems()
        }
        _tileSetList.visible = false
        addNewSetView.visible = false
        infoView.visible = true
    }

    function leaveInfoView() {
        mapBoundary.visible = false
        _map.center = savedCenter
        _map.zoomLevel = savedZoom
        mapType = savedMapType
    }

    function resetMapToDefaults() {
        _map.center = QGroundControl.flightMapPosition
        _map.zoomLevel = QGroundControl.flightMapZoom
    }

    onMapTypeChanged: {
        updateMap()
        if(isMapInteractive) {
            QGroundControl.mapEngineManager.saveSetting(mapKey, mapType)
        }
    }

    QGCFileDialog {
        id:             fileDialog
        folder:         QGroundControl.settingsManager.appSettings.missionSavePath
        nameFilters:    ["Tile Sets (*.qgctiledb)"]

        onAcceptedForSave: {
            if (QGroundControl.mapEngineManager.exportSets(file)) {
                exportToDiskProgress.open()
            } else {
                showList()
            }
            close()
        }

        onAcceptedForLoad: {
            if(!QGroundControl.mapEngineManager.importSets(file)) {
                showList();
            }
            close()
        }
    }

    MessageDialog {
        id:         errorDialog
        visible:    false
        text:       QGroundControl.mapEngineManager.errorMessage
        icon:       StandardIcon.Critical
        standardButtons: StandardButton.Ok
        title:      qsTr("Thông báo lỗi")
        onYes: {
            errorDialog.visible = false
        }
    }

    Component {
        id: optionsDialogComponent

        QGCPopupDialog {
            title:      qsTr("Tùy chọn bản đồ ngoại tuyến")
            buttons:    StandardButton.Save | StandardButton.Cancel

            onAccepted: {
                QGroundControl.mapEngineManager.maxDiskCache = parseInt(maxCacheSize.text)
                QGroundControl.mapEngineManager.maxMemCache  = parseInt(maxCacheMemSize.text)
            }

            Column {
                spacing: ScreenTools.defaultFontPixelHeight / 2

                QGCLabel { text:       qsTr("Max Cache Disk Size (MB):") }

                QGCTextField {
                    id:                 maxCacheSize
                    maximumLength:      6
                    inputMethodHints:   Qt.ImhDigitsOnly
                    validator:          IntValidator {bottom: 1; top: 262144;}
                    text:               QGroundControl.mapEngineManager.maxDiskCache
                }

                Item { width: 1; height: 1 }

                QGCLabel {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    wrapMode:       Text.WordWrap
                    text:           qsTr("Max Cache Memory Size (MB):")
                }

                QGCTextField {
                    id:                 maxCacheMemSize
                    maximumLength:      4
                    inputMethodHints:   Qt.ImhDigitsOnly
                    validator:          IntValidator {bottom: 1; top: 1024;}
                    text:               QGroundControl.mapEngineManager.maxMemCache
                }

                QGCLabel {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    wrapMode:       Text.WordWrap
                    font.pointSize: _adjustableFontPointSize
                    text:           qsTr("Thay đổi bộ nhớ đệm yêu cầu khởi động lại để có hiệu lực.")
                }

                Item { width: 1; height: 1; visible: _mapboxFact ? _mapboxFact.visible : false }
                QGCLabel { text: qsTr("Mã truy cập Mapbox"); visible: _mapboxFact ? _mapboxFact.visible : false }
                FactTextField {
                    fact:               _mapboxFact
                    visible:            _mapboxFact ? _mapboxFact.visible : false
                    maximumLength:      256
                    width:              ScreenTools.defaultFontPixelWidth * 30
                }
                QGCLabel {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    wrapMode:       Text.WordWrap
                    text:           qsTr("Để kích hoạt bản đồ Mapbox, hãy nhập mã truy cập của bạn.")
                    visible:        _mapboxFact ? _mapboxFact.visible : false
                    font.pointSize: _adjustableFontPointSize
                }

                Item { width: 1; height: 1; visible: _mapboxAccountFact ? _mapboxAccountFact.visible : false }
                QGCLabel { text: qsTr("Tên người dùng Mapbox"); visible: _mapboxAccountFact ? _mapboxAccountFact.visible : false }
                FactTextField {
                    fact:               _mapboxAccountFact
                    visible:            _mapboxAccountFact ? _mapboxAccountFact.visible : false
                    maximumLength:      256
                    width:              ScreenTools.defaultFontPixelWidth * 30
                }
                QGCLabel {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    wrapMode:       Text.WordWrap
                    text:           qsTr("Để kích hoạt kiểu bản đồ Mapbox tùy chỉnh, hãy nhập tên tài khoản của bạn.")
                    visible:        _mapboxAccountFact ? _mapboxAccountFact.visible : false
                    font.pointSize: _adjustableFontPointSize
                }

                Item { width: 1; height: 1; visible: _mapboxStyleFact ? _mapboxStyleFact.visible : false }
                QGCLabel { text: qsTr("ID kiểu bản đồ Mapbox"); visible: _mapboxStyleFact ? _mapboxStyleFact.visible : false }
                FactTextField {
                    fact:               _mapboxStyleFact
                    visible:            _mapboxStyleFact ? _mapboxStyleFact.visible : false
                    maximumLength:      256
                    width:              ScreenTools.defaultFontPixelWidth * 30
                }
                QGCLabel {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    wrapMode:       Text.WordWrap
                    text:           qsTr("Để kích hoạt kiểu bản đồ Mapbox tùy chỉnh, hãy nhập ID kiểu của bạn.")
                    visible:        _mapboxStyleFact ? _mapboxStyleFact.visible : false
                    font.pointSize: _adjustableFontPointSize
                }

                Item { width: 1; height: 1; visible: _esriFact ? _esriFact.visible : false }
                QGCLabel { text: qsTr("Mã truy cập Esri"); visible: _esriFact ? _esriFact.visible : false }
                FactTextField {
                    fact:               _esriFact
                    visible:            _esriFact ? _esriFact.visible : false
                    maximumLength:      256
                    width:              ScreenTools.defaultFontPixelWidth * 30
                }
                QGCLabel {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    wrapMode:       Text.WordWrap
                    text:           qsTr("Để kích hoạt bản đồ Esri, hãy nhập mã truy cập của bạn.")
                    visible:        _esriFact ? _esriFact.visible : false
                    font.pointSize: _adjustableFontPointSize
                }

                Item { width: 1; height: 1; visible: _vworldFact ? _vworldFact.visible : false }
                QGCLabel { text: qsTr("Mã truy cập VWorld"); visible: _vworldFact ? _vworldFact.visible : false }
                FactTextField {
                    fact:               _vworldFact
                    visible:            _vworldFact ? _vworldFact.visible : false
                    maximumLength:      256
                    width:              ScreenTools.defaultFontPixelWidth * 30
                }
                QGCLabel {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    wrapMode:       Text.WordWrap
                    text:           qsTr("Để kích hoạt bản đồ VWorld, hãy nhập mã truy cập của bạn.")
                    visible:        _vworldFact ? _vworldFact.visible : false
                    font.pointSize: _adjustableFontPointSize
                }

                Item { width: 1; height: 1; visible: _customURLFact ? _customURLFact.visible : false }
                QGCLabel { text: qsTr("URL bản đồ tùy chỉnh"); visible: _customURLFact ? _customURLFact.visible : false }
                FactTextField {
                    fact:               _customURLFact
                    visible:            _customURLFact ? _customURLFact.visible : false
                    maximumLength:      256
                    width:              ScreenTools.defaultFontPixelWidth * 30
                }
                QGCLabel {
                    anchors.left:   parent.left
                    anchors.right:  parent.right
                    wrapMode:       Text.WordWrap
                    text:           qsTr("URL với các thay thế {x} {y} {z} hoặc {zoom}")
                    visible:        _customURLFact ? _customURLFact.visible : false
                    font.pointSize: _adjustableFontPointSize
                }
            }
        }
    } // Component - optionsDialogComponent

    Component {
        id: deleteConfirmationDialogComponent
        QGCSimpleMessageDialog {
            title:      qsTr("Xác nhận xóa")
            text:       offlineMapView._currentSelection.defaultSet ?
                            qsTr("Điều này sẽ xóa tất cả các ô bản đồ, BAO GỒM cả các bộ ô mà bạn đã tự tạo.\n\nBạn có chắc chắn muốn làm điều này không?") :
                            qsTr("Xóa %1 và tất cả các ô của nó.\n\nBạn có chắc chắn muốn làm điều này không?").arg(offlineMapView._currentSelection.name)
            buttons:    StandardButton.Yes | StandardButton.No

            onAccepted: {
                QGroundControl.mapEngineManager.deleteTileSet(offlineMapView._currentSelection)
                leaveInfoView()
                showList()
            }
        }
    }

    Item {
        anchors.fill:       parent

        FlightMap {
            id:                         _map
            anchors.fill:               parent
            visible:                    false
            allowGCSLocationCenter:     true
            allowVehicleLocationCenter: false
            gesture.flickDeceleration:  3000
            mapName:                    "OfflineMap"

            property bool isSatelliteMap: activeMapType.name.indexOf("Satellite") > -1 || activeMapType.name.indexOf("Hybrid") > -1

            MapRectangle {
                id:             mapBoundary
                border.width:   2
                border.color:   "red"
                color:          Qt.rgba(1,0,0,0.05)
                smooth:         true
                antialiasing:   true
            }

            Component.onCompleted: resetMapToDefaults()

            onCenterChanged:    handleChanges()
            onZoomLevelChanged: handleChanges()
            onWidthChanged:     handleChanges()
            onHeightChanged:    handleChanges()

            MapScale {
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
                anchors.bottomMargin:   anchors.leftMargin
                anchors.left:           parent.left
                anchors.bottom:         parent.bottom
                mapControl:             _map
                buttonsOnLeft:          true
            }

            //-----------------------------------------------------------------
            //-- Show Set Info
            Rectangle {
                id:                 infoView
                anchors.margins:    ScreenTools.defaultFontPixelHeight
                anchors.right:      parent.right
                anchors.verticalCenter: parent.verticalCenter
                width:              tileInfoColumn.width  + (ScreenTools.defaultFontPixelWidth  * 2)
                height:             tileInfoColumn.height + (ScreenTools.defaultFontPixelHeight * 2)
                color:              Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.85)
                radius:             ScreenTools.defaultFontPixelWidth * 0.5
                visible:            false

                property bool       _extraButton: {
                    if(!offlineMapView._currentSelection)
                        return false;
                    var curSel = offlineMapView._currentSelection;
                    return !_defaultSet && ((!curSel.complete && !curSel.downloading) || (!curSel.complete && curSel.downloading));
                }

                property real       _labelWidth:    ScreenTools.defaultFontPixelWidth * 10
                property real       _valueWidth:    ScreenTools.defaultFontPixelWidth * 14
                Column {
                    id:                 tileInfoColumn
                    anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.5
                    spacing:            ScreenTools.defaultFontPixelHeight * 0.5
                    anchors.centerIn:   parent
                    QGCLabel {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        wrapMode:       Text.WordWrap
                        text:           offlineMapView._currentSelection ? offlineMapView._currentSelection.name : ""
                        font.pointSize: _saveRealEstate ? ScreenTools.defaultFontPointSize : ScreenTools.mediumFontPointSize
                        horizontalAlignment: Text.AlignHCenter
                        visible:        _defaultSet
                    }
                    QGCTextField {
                        id:             editSetName
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        visible:        !_defaultSet
                        text:           offlineMapView._currentSelection ? offlineMapView._currentSelection.name : ""
                    }
                    QGCLabel {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        wrapMode:       Text.WordWrap
                        text: {
                            if(offlineMapView._currentSelection) {
                                if(offlineMapView._currentSelection.defaultSet)
                                    return qsTr("Bộ nhớ đệm ô bản đồ toàn hệ thống");
                                else
                                    return "(" + offlineMapView._currentSelection.mapTypeStr + ")"
                            } else
                                return "";
                        }
                        horizontalAlignment: Text.AlignHCenter
                    }
                    //-- Tile Sets
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    !_defaultSet && mapType !== QGroundControl.elevationProviderName
                        QGCLabel {  text: qsTr("Mức độ thu phóng:"); width: infoView._labelWidth; }
                        QGCLabel {  text: offlineMapView._currentSelection ? (offlineMapView._currentSelection.minZoom + " - " + offlineMapView._currentSelection.maxZoom) : ""; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    !_defaultSet
                        QGCLabel {  text: qsTr("Tổng cộng:"); width: infoView._labelWidth; }
                        QGCLabel {  text: (offlineMapView._currentSelection ? offlineMapView._currentSelection.totalTileCountStr : "") + " (" + (offlineMapView._currentSelection ? offlineMapView._currentSelection.totalTilesSizeStr : "") + ")"; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    offlineMapView && offlineMapView._currentSelection && !_defaultSet && offlineMapView._currentSelection.uniqueTileCount > 0
                        QGCLabel {  text: qsTr("Duy nhất:"); width: infoView._labelWidth; }
                        QGCLabel {  text: (offlineMapView._currentSelection ? offlineMapView._currentSelection.uniqueTileCountStr : "") + " (" + (offlineMapView._currentSelection ? offlineMapView._currentSelection.uniqueTileSizeStr : "") + ")"; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }

                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    offlineMapView && offlineMapView._currentSelection && !_defaultSet && !offlineMapView._currentSelection.complete
                        QGCLabel {  text: qsTr("Đã tải xuống:"); width: infoView._labelWidth; }
                        QGCLabel {  text: (offlineMapView._currentSelection ? offlineMapView._currentSelection.savedTileCountStr : "") + " (" + (offlineMapView._currentSelection ? offlineMapView._currentSelection.savedTileSizeStr : "") + ")"; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    offlineMapView && offlineMapView._currentSelection && !_defaultSet && !offlineMapView._currentSelection.complete && offlineMapView._currentSelection.errorCount > 0
                        QGCLabel {  text: qsTr("Số lỗi:"); width: infoView._labelWidth; }
                        QGCLabel {  text: offlineMapView._currentSelection ? offlineMapView._currentSelection.errorCountStr : ""; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }
                    //-- Default Tile Set
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    _defaultSet
                        QGCLabel { text: qsTr("Kích thước:"); width: infoView._labelWidth; }
                        QGCLabel { text: offlineMapView._currentSelection ? offlineMapView._currentSelection.savedTileSizeStr  : ""; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible:    _defaultSet
                        QGCLabel { text: qsTr("Số lượng ô:"); width: infoView._labelWidth; }
                        QGCLabel { text: offlineMapView._currentSelection ? offlineMapView._currentSelection.savedTileCountStr : ""; horizontalAlignment: Text.AlignRight; width: infoView._valueWidth; }
                    }
                    Row {
                        spacing:    ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCButton {
                            text:       qsTr("Tiếp tục tải xuống")
                            visible:    offlineMapView._currentSelection && offlineMapView._currentSelection && !_defaultSet && (!offlineMapView._currentSelection.complete && !offlineMapView._currentSelection.downloading)
                            width:      ScreenTools.defaultFontPixelWidth * 16
                            onClicked: {
                                if(offlineMapView._currentSelection)
                                    offlineMapView._currentSelection.resumeDownloadTask()
                            }
                        }
                        QGCButton {
                            text:       qsTr("Hủy tải xuống")
                            visible:    offlineMapView._currentSelection && offlineMapView._currentSelection && !_defaultSet && (!offlineMapView._currentSelection.complete && offlineMapView._currentSelection.downloading)
                            width:      ScreenTools.defaultFontPixelWidth * 16
                            onClicked: {
                                if(offlineMapView._currentSelection)
                                    offlineMapView._currentSelection.cancelDownloadTask()
                            }
                        }
                        QGCButton {
                            text:       qsTr("Xóa")
                            width:      ScreenTools.defaultFontPixelWidth * (infoView._extraButton ? 6 : 10)
                            onClicked:  deleteConfirmationDialogComponent.createObject(mainWindow).open()
                            enabled:    offlineMapView._currentSelection ? (offlineMapView._currentSelection.savedTileSize > 0) : false
                        }
                        QGCButton {
                            text:       qsTr("Đồng ý")
                            width:      ScreenTools.defaultFontPixelWidth * (infoView._extraButton ? 6 : 10)
                            visible:    !_defaultSet
                            enabled:    editSetName.text !== ""
                            onClicked: {
                                if(editSetName.text !== _currentSelection.name) {
                                    QGroundControl.mapEngineManager.renameTileSet(_currentSelection, editSetName.text)
                                }
                                leaveInfoView()
                                showList()
                            }
                        }
                        QGCButton {
                            text:       _defaultSet ? qsTr("Đóng") : qsTr("Hủy")
                            width:      ScreenTools.defaultFontPixelWidth * (infoView._extraButton ? 6 : 10)
                            onClicked: {
                                leaveInfoView()
                                showList()
                            }
                        }
                    }
                }
            } // Rectangle - infoView

            //-----------------------------------------------------------------
            //-- Add new set
            Item {
                id:             addNewSetView
                anchors.fill:   parent
                visible:        false

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin:     _margins
                    anchors.left:           parent.left
                    spacing:                _margins

                    QGCButton {
                        text:       qsTr("Hiển thị bản xem trước mức độ thu phóng")
                        visible:    !_showPreview
                        onClicked:  _showPreview = !_showPreview
                    }

                    Map {
                        id:                 minZoomPreview
                        width:              addNewSetView.width / 4
                        height:             addNewSetView.height / 4
                        center:             _map.center
                        activeMapType:      _map.activeMapType
                        zoomLevel:          sliderMinZoom.value
                        gesture.enabled:    false
                        visible:            _showPreview

                        property bool isSatelliteMap: activeMapType.name.indexOf("Satellite") > -1 || activeMapType.name.indexOf("Hybrid") > -1

                        plugin: Plugin { name: "QGroundControl" }

                        MapScale {
                            anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
                            anchors.bottomMargin:   anchors.leftMargin
                            anchors.left:           parent.left
                            anchors.bottom:         parent.bottom
                            mapControl:             parent
                            zoomButtonsVisible:     false
                        }

                        Rectangle {
                            anchors.fill:   parent
                            border.color:   _mapAdjustedColor
                            color:          "transparent"

                            QGCMapLabel {
                                anchors.centerIn:   parent
                                map:                minZoomPreview
                                text:               qsTr("Thu phóng tối thiểu: %1").arg(sliderMinZoom.value)
                            }
                            MouseArea {
                                anchors.fill:   parent
                                onClicked:      _showPreview = false
                            }
                        }
                    } // Map

                    Map {
                        id:                 maxZoomPreview
                        width:              minZoomPreview.width
                        height:             minZoomPreview.height
                        center:             _map.center
                        activeMapType:      _map.activeMapType
                        zoomLevel:          sliderMaxZoom.value
                        gesture.enabled:    false
                        visible:            _showPreview

                        property bool isSatelliteMap: activeMapType.name.indexOf("Satellite") > -1 || activeMapType.name.indexOf("Hybrid") > -1

                        plugin: Plugin { name: "QGroundControl" }

                        MapScale {
                            anchors.leftMargin:     ScreenTools.defaultFontPixelWidth / 2
                            anchors.bottomMargin:   anchors.leftMargin
                            anchors.left:           parent.left
                            anchors.bottom:         parent.bottom
                            mapControl:             parent
                            zoomButtonsVisible:     false
                        }

                        Rectangle {
                            anchors.fill:   parent
                            border.color:   _mapAdjustedColor
                            color:          "transparent"

                            QGCMapLabel {
                                anchors.centerIn:   parent
                                map:                maxZoomPreview
                                text:               qsTr("Thu phóng tối đa: %1").arg(sliderMaxZoom.value)
                            }
                            MouseArea {
                                anchors.fill:   parent
                                onClicked:      _showPreview = false
                            }
                        }
                    } // Map
                }
            } // Item - Add new set view

            CenterMapDropButton {
                topMargin:          0
                anchors.margins:    _margins
                anchors.left:       map.left
                anchors.top:        map.top
                map:                _map
                showMission:        false
                showAllItems:       false
                visible:            addNewSetView.visible
            }
        } // Map

        //-- Add new set dialog
        Rectangle {
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            anchors.verticalCenter: parent.verticalCenter
            anchors.right:      parent.right
            visible:            addNewSetView.visible
            width:              ScreenTools.defaultFontPixelWidth * (ScreenTools.isTinyScreen ? 24 : 28)
            height:             Math.min(parent.height - (anchors.margins * 2), addNewSetFlickable.y + addNewSetColumn.height + addNewSetLabel.anchors.margins)
            color:              Qt.rgba(qgcPal.window.r, qgcPal.window.g, qgcPal.window.b, 0.85)
            radius:             ScreenTools.defaultFontPixelWidth * 0.5

            //-- Eat mouse events
            DeadMouseArea {
                anchors.fill: parent
            }

            QGCLabel {
                id:                 addNewSetLabel
                anchors.margins:    ScreenTools.defaultFontPixelHeight / 2
                anchors.top:        parent.top
                anchors.left:       parent.left
                anchors.right:      parent.right
                wrapMode:           Text.WordWrap
                text:               qsTr("Thêm cài đặt mới")
                font.pointSize:     _saveRealEstate ? ScreenTools.defaultFontPointSize : ScreenTools.mediumFontPointSize
                horizontalAlignment: Text.AlignHCenter
            }

            QGCFlickable {
                id:                     addNewSetFlickable
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
                anchors.rightMargin:    anchors.leftMargin
                anchors.topMargin:      ScreenTools.defaultFontPixelWidth / 3
                anchors.bottomMargin:   anchors.topMargin
                anchors.top:            addNewSetLabel.bottom
                anchors.left:           parent.left
                anchors.right:          parent.right
                anchors.bottom:         parent.bottom
                clip:                   true
                contentHeight:          addNewSetColumn.height

                Column {
                    id:                 addNewSetColumn
                    anchors.left:       parent.left
                    anchors.right:      parent.right
                    spacing:            ScreenTools.defaultFontPixelHeight * (ScreenTools.isTinyScreen ? 0.25 : 0.5)

                    Column {
                        spacing:            ScreenTools.isTinyScreen ? 0 : ScreenTools.defaultFontPixelHeight * 0.25
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        QGCLabel { text: qsTr("Tên:") }
                        QGCTextField {
                            id:             setName
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                        }
                    }

                    Column {
                        spacing:            ScreenTools.isTinyScreen ? 0 : ScreenTools.defaultFontPixelHeight * 0.25
                        anchors.left:       parent.left
                        anchors.right:      parent.right
                        QGCLabel {
                            text:       qsTr("Kiểu bản đồ:")
                            visible:    !_saveRealEstate
                        }
                        QGCComboBox {
                            id:             mapCombo
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            model:          QGroundControl.mapEngineManager.mapList
                            onActivated: {
                                mapType = textAt(index)
                            }
                            Component.onCompleted: {
                                var index = mapCombo.find(mapType)
                                if (index === -1) {
                                    console.warn("Active map name not in combo", mapType)
                                } else {
                                    mapCombo.currentIndex = index
                                }
                            }
                        }
                        QGCCheckBox {
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            text:           qsTr("Lấy dữ liệu độ cao")
                            checked:        QGroundControl.mapEngineManager.fetchElevation
                            onClicked: {
                                QGroundControl.mapEngineManager.fetchElevation = checked
                                handleChanges()
                            }
                        }
                    }

                    Rectangle {
                        anchors.left:   parent.left
                        anchors.right:  parent.right
                        height:         zoomColumn.height + ScreenTools.defaultFontPixelHeight * 0.5
                        color:          qgcPal.window
                        border.color:   qgcPal.text
                        radius:         ScreenTools.defaultFontPixelWidth * 0.5

                        Column {
                            id:                 zoomColumn
                            spacing:            ScreenTools.isTinyScreen ? 0 : ScreenTools.defaultFontPixelHeight * 0.5
                            anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.25
                            anchors.top:        parent.top
                            anchors.left:       parent.left
                            anchors.right:      parent.right

                            QGCLabel {
                                text:           qsTr("Mức thu phóng tối thiểu/tối đa")
                                font.pointSize: _adjustableFontPointSize
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Slider {
                                id:                         sliderMinZoom
                                anchors.left:               parent.left
                                anchors.right:              parent.right
                                height:                     sliderTouchArea * 1.25
                                from:                       minZoomLevel
                                to:                         maxZoomLevel
                                stepSize:                   1
                                live:                       true
                                property bool _updateSetting: false
                                Component.onCompleted: {
                                    sliderMinZoom.value = _settings.minZoomLevelDownload.rawValue
                                    _updateSetting = true
                                }
                                onValueChanged: {
                                    if(sliderMinZoom.value > sliderMaxZoom.value) {
                                        sliderMaxZoom.value = sliderMinZoom.value
                                    }
                                    if (_updateSetting) {
                                        // Don't update setting until after Component.onCompleted since bad values come through before that
                                        _settings.minZoomLevelDownload.rawValue = value
                                    }
                                    handleChanges()
                                }
                                handle: Rectangle {
                                    x: sliderMinZoom.leftPadding + sliderMinZoom.visualPosition  * (sliderMinZoom.availableWidth - width)
                                    y: sliderMinZoom.topPadding  + sliderMinZoom.availableHeight * 0.5 - height * 0.5
                                    implicitWidth:  sliderTouchArea
                                    implicitHeight: sliderTouchArea
                                    radius:         sliderTouchArea * 0.5
                                    color:          qgcPal.button
                                    border.width:   1
                                    border.color:   qgcPal.buttonText
                                    Label {
                                        text:               sliderMinZoom.value
                                        anchors.centerIn:   parent
                                        font.family:        ScreenTools.normalFontFamily
                                        font.pointSize:     ScreenTools.smallFontPointSize
                                        color:              qgcPal.buttonText
                                    }
                                }
                            } // Slider - min zoom

                            Slider {
                                id:                         sliderMaxZoom
                                anchors.left:               parent.left
                                anchors.right:              parent.right
                                height:                     sliderTouchArea * 1.25
                                from:                       minZoomLevel
                                to:                         maxZoomLevel
                                stepSize:                   1
                                live:                       true
                                property bool _updateSetting: false
                                Component.onCompleted: {
                                    sliderMaxZoom.value = _settings.maxZoomLevelDownload.rawValue
                                    _updateSetting = true
                                }
                                onValueChanged: {
                                    if(sliderMaxZoom.value < sliderMinZoom.value) {
                                        sliderMinZoom.value = sliderMaxZoom.value
                                    }
                                    if (_updateSetting) {
                                        // Don't update setting until after Component.onCompleted since bad values come through before that
                                        _settings.maxZoomLevelDownload.rawValue = value
                                    }
                                    handleChanges()
                                }
                                handle: Rectangle {
                                    x: sliderMaxZoom.leftPadding + sliderMaxZoom.visualPosition  * (sliderMaxZoom.availableWidth - width)
                                    y: sliderMaxZoom.topPadding  + sliderMaxZoom.availableHeight * 0.5 - height * 0.5
                                    implicitWidth:  sliderTouchArea
                                    implicitHeight: sliderTouchArea
                                    radius:         sliderTouchArea * 0.5
                                    color:          qgcPal.button
                                    border.width:   1
                                    border.color:   qgcPal.buttonText
                                    Label {
                                        text:               sliderMaxZoom.value
                                        anchors.centerIn:   parent
                                        font.family:        ScreenTools.normalFontFamily
                                        font.pointSize:     ScreenTools.smallFontPointSize
                                        color:              qgcPal.buttonText
                                    }
                                }
                            } // Slider - max zoom

                            GridLayout {
                                columns:    2
                                rowSpacing: ScreenTools.isTinyScreen ? 0 : ScreenTools.defaultFontPixelHeight * 0.5
                                QGCLabel {
                                    text:           qsTr("Số lượng Tile:")
                                    font.pointSize: _adjustableFontPointSize
                                }
                                QGCLabel {
                                    text:            QGroundControl.mapEngineManager.tileCountStr
                                    font.pointSize: _adjustableFontPointSize
                                }

                                QGCLabel {
                                    text:           qsTr("Kích thước ước tính:")
                                    font.pointSize: _adjustableFontPointSize
                                }
                                QGCLabel {
                                    text:           QGroundControl.mapEngineManager.tileSizeStr
                                    font.pointSize: _adjustableFontPointSize
                                }
                            }
                        } // Column - Zoom info
                    } // Rectangle - Zoom info

                    QGCLabel {
                        text:       qsTr("Quá nhiều tiles")
                        visible:    _tooManyTiles
                        color:      qgcPal.warningText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Row {
                        id: addButtonRow
                        spacing: ScreenTools.defaultFontPixelWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        QGCButton {
                            text:       qsTr("Tải xuống")
                            width:      (addNewSetColumn.width * 0.5) - (addButtonRow.spacing * 0.5)
                            enabled:    !_tooManyTiles && setName.text.length > 0
                            onClicked: {
                                if(QGroundControl.mapEngineManager.findName(setName.text)) {
                                    duplicateName.visible = true
                                } else {
                                    QGroundControl.mapEngineManager.startDownload(setName.text, mapType);
                                    showList()
                                }
                            }
                        }
                        QGCButton {
                            text:       qsTr("Hủy")
                            width:      (addNewSetColumn.width * 0.5) - (addButtonRow.spacing * 0.5)
                            onClicked: {
                                showList()
                            }
                        }
                    }

                } // Column
            } // QGCFlickable
        } // Rectangle - Add new set dialog

        QGCFlickable {
            id:                 _tileSetList
            clip:               true
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            anchors.top:        parent.top
            anchors.bottom:     _listButtonRow.top
            anchors.left:       parent.left
            anchors.right:      parent.right
            contentHeight:      _cacheList.height
            ButtonGroup {
                id:             buttonGroup
                buttons:        _cacheList.children
            }
            Column {
                id:             _cacheList
                width:          Math.min(_tileSetList.width, (ScreenTools.defaultFontPixelWidth  * 50).toFixed(0))
                spacing:        ScreenTools.defaultFontPixelHeight * 0.5
                anchors.horizontalCenter: parent.horizontalCenter
                OfflineMapButton {
                    id:             firstButton
                    text:           qsTr("Thêm cài đặt mới")
                    width:          _cacheList.width
                    height:         ScreenTools.defaultFontPixelHeight * (ScreenTools.isMobile ? 3 : 2)
                    currentSet:     _currentSelection
                    onClicked: {
                        offlineMapView._currentSelection = null
                        checked = true
                        addNewSet()
                    }
                }
                Repeater {
                    model: QGroundControl.mapEngineManager.tileSets
                    delegate: OfflineMapButton {
                        text:           object.name
                        size:           object.downloadStatus
                        tiles:          object.totalTileCount
                        complete:       object.complete
                        width:          firstButton.width
                        height:         ScreenTools.defaultFontPixelHeight * (ScreenTools.isMobile ? 3 : 2)
                        currentSet:     _currentSelection
                        tileSet:        object
                        onClicked: {
                            offlineMapView._currentSelection = object
                            checked = true
                            showInfo()
                        }
                    }
                }
            }
        }
        Row {
            id:                 _listButtonRow
            visible:            _tileSetList.visible
            spacing:            _margins
            anchors.bottom:     parent.bottom
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            anchors.horizontalCenter: parent.horizontalCenter
            QGCButton {
                text:           qsTr("Nhập")
                width:          _buttonSize
                visible:        QGroundControl.corePlugin.options.showOfflineMapImport
                onClicked: {
                    QGroundControl.mapEngineManager.importAction = QGCMapEngineManager.ActionNone
                    importDialog.open()
                }
            }
            QGCButton {
                text:           qsTr("Xuất")
                width:          _buttonSize
                visible:        QGroundControl.corePlugin.options.showOfflineMapExport
                onClicked:      showExport()
            }
            QGCButton {
                text:           qsTr("Tùy chọn")
                width:          _buttonSize
                onClicked:      optionsDialogComponent.createObject(mainWindow).open()
            }
        }

        //-- Export Tile Sets
        QGCFlickable {
            id:                 _exporTiles
            clip:               true
            visible:            false
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            anchors.top:        parent.top
            anchors.bottom:     _exportButtonRow.top
            anchors.left:       parent.left
            anchors.right:      parent.right
            contentHeight:      _exportList.height
            Column {
                id:         _exportList
                width:      Math.min(_exporTiles.width, (ScreenTools.defaultFontPixelWidth  * 50).toFixed(0))
                spacing:    ScreenTools.defaultFontPixelHeight * 0.5
                anchors.horizontalCenter: parent.horizontalCenter
                QGCLabel {
                    text:           qsTr("lựa chọn bộ Tile để xuất")
                    font.pointSize: ScreenTools.mediumFontPointSize
                }
                Item { width: 1; height: ScreenTools.defaultFontPixelHeight; }
                Repeater {
                    model: QGroundControl.mapEngineManager.tileSets
                    delegate: QGCCheckBox {
                        text:           object.name
                        checked:        object.selected
                        onClicked:      object.selected = checked
                        Connections {
                            // This connection should theoretically not be needed since the `checked: object.selected` binding should work.
                            // But for some reason when the user clicks the check box taht binding breaks. Which in turns causes
                            // Select All/None to update the internal state but check box visible state is out of sync
                            target:             object
                            onSelectedChanged:  checked = object.selected
                        }
                    }
                }
            }
        }
        Row {
            id:                 _exportButtonRow
            visible:            _exporTiles.visible
            spacing:            _margins
            anchors.bottom:     parent.bottom
            anchors.margins:    ScreenTools.defaultFontPixelWidth
            anchors.horizontalCenter: parent.horizontalCenter
            QGCButton {
                text:           qsTr("Chọn tất cả")
                width:          _bigButtonSize
                onClicked:      QGroundControl.mapEngineManager.selectAll()
            }
            QGCButton {
                text:           qsTr("Chọn Không có")
                width:          _bigButtonSize
                onClicked:      QGroundControl.mapEngineManager.selectNone()
            }
            QGCButton {
                text:           qsTr("Xuất")
                width:          _bigButtonSize
                enabled:        QGroundControl.mapEngineManager.selectedCount > 0
                onClicked: {
                    fileDialog.title = qsTr("Xuất Tile Set")
                    fileDialog.selectExisting = false
                    fileDialog.openForSave()
                }
            }
            QGCButton {
                text:           qsTr("Hủy")
                width:          _bigButtonSize
                onClicked:       showList()
            }
        }
    }

    Popup {
        id:                 exportToDiskProgress
        width:              mainWindow.width  * 0.666
        height:             mainWindow.height * 0.333
        modal:              true
        focus:              true
        parent:             Overlay.overlay
        x:                  Math.round((mainWindow.width  - width)  * 0.5)
        y:                  Math.round((mainWindow.height - height) * 0.5)
        closePolicy:        Popup.NoAutoClose
        background: Rectangle {
            anchors.fill:   parent
            color:          qgcPal.windowShadeDark
            border.color:   qgcPal.text
            radius:         ScreenTools.defaultFontPixelWidth
        }
        Column {
            id:                 exportCol
            spacing:            ScreenTools.defaultFontPixelHeight
            width:              parent.width
            anchors.centerIn:   parent
            QGCLabel {
                text:               QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionExporting ? qsTr("Tile Set Export Progress") : qsTr("Tile Set Export Completed")
                font.family:        ScreenTools.demiboldFontFamily
                font.pointSize:     ScreenTools.mediumFontPointSize
                anchors.horizontalCenter: parent.horizontalCenter
            }
            ProgressBar {
                width:          parent.width * 0.45
                from:           0
                to:             100
                value:          QGroundControl.mapEngineManager.actionProgress
                anchors.horizontalCenter: parent.horizontalCenter
            }
            BusyIndicator {
                visible:        QGroundControl.mapEngineManager ? QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionExporting : false
                running:        QGroundControl.mapEngineManager ? QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionExporting : false
                width:          exportCloseButton.height
                height:         exportCloseButton.height
                anchors.horizontalCenter: parent.horizontalCenter
            }
            QGCButton {
                id:             exportCloseButton
                text:           qsTr("Đóng")
                width:          _buttonSize
                visible:        !QGroundControl.mapEngineManager.exporting
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    exportToDiskProgress.close()
                }
            }
        }
    }

    Popup {
        id:                 importDialog
        width:              mainWindow.width  * 0.666
        height:             importCol.height  * 1.5
        modal:              true
        focus:              true
        parent:             Overlay.overlay
        x:                  Math.round((mainWindow.width  - width)  * 0.5)
        y:                  Math.round((mainWindow.height - height) * 0.5)
        closePolicy:        Popup.NoAutoClose
        background: Rectangle {
            anchors.fill:   parent
            color:          qgcPal.windowShadeDark
            border.color:   qgcPal.text
            radius:         ScreenTools.defaultFontPixelWidth
        }
        Column {
            id:                 importCol
            spacing:            ScreenTools.defaultFontPixelHeight
            width:              parent.width
            anchors.centerIn:   parent
            QGCLabel {
                text: {
                    if(QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionNone) {
                        return qsTr("Nhập cài đặt Tile bản đồ");
                    } else if(QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionImporting) {
                        return qsTr("Tiến trình nhập cài đặt Tile bản đồ");
                    } else {
                        return qsTr("Hoàn thành nhập cài đặt Tile bản đồ");
                    }
                }
                font.family:        ScreenTools.demiboldFontFamily
                font.pointSize:     ScreenTools.mediumFontPointSize
                anchors.horizontalCenter: parent.horizontalCenter
            }
            ProgressBar {
                width:          parent.width * 0.45
                from:           0
                to:             100
                visible:        QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionImporting
                value:          QGroundControl.mapEngineManager.actionProgress
                anchors.horizontalCenter: parent.horizontalCenter
            }
            BusyIndicator {
                visible:        QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionImporting
                running:        QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionImporting
                width:          ScreenTools.defaultFontPixelWidth * 2
                height:         width
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Column {
                id:                 mapSetButtons
                spacing:            ScreenTools.defaultFontPixelHeight
                width:              ScreenTools.defaultFontPixelWidth * 24
                anchors.horizontalCenter: parent.horizontalCenter
                QGCRadioButton {
                    text:           qsTr("Thêm vào cài đặt hiện có")
                    checked:        !QGroundControl.mapEngineManager.importReplace
                    onClicked:      QGroundControl.mapEngineManager.importReplace = !checked
                    visible:        QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionNone
                }
                QGCRadioButton {
                    text:           qsTr("Thay thế cài đặt hiện có")
                    checked:        QGroundControl.mapEngineManager.importReplace
                    onClicked:      QGroundControl.mapEngineManager.importReplace = checked
                    visible:        QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionNone
                }
            }
            QGCButton {
                text:           qsTr("Đóng")
                width:          _bigButtonSize * 1.25
                visible:        QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionDone
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    showList();
                    importDialog.close()
                }
            }
            Row {
                spacing:            _margins
                visible:            QGroundControl.mapEngineManager.importAction === QGCMapEngineManager.ActionNone
                anchors.horizontalCenter: parent.horizontalCenter
                QGCButton {
                    text:           qsTr("Nhập")
                    width:          _bigButtonSize * 1.25
                    onClicked: {
                        importDialog.close()
                        fileDialog.title = qsTr("Nhập cài đặt Tile")
                        fileDialog.selectExisting = true
                        fileDialog.openForLoad()
                    }
                }
                QGCButton {
                    text:           qsTr("Hủy")
                    width:          _bigButtonSize * 1.25
                    onClicked: {
                        showList();
                        importDialog.close()
                    }
                }
            }
        }
    }
}
