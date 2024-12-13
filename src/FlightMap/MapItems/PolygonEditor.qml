/****************************************************************************
 *
 * (c) 2009-2020 DỰ ÁN QGROUNDCONTROL <http://www.qgroundcontrol.org>
 *
 * QGroundControl được cấp phép theo các điều khoản trong tệp
 * COPYING.md trong thư mục nguồn mã nguồn.
 *
 ****************************************************************************/

import QtQuick      2.3
import QtLocation   5.3

import QGroundControl               1.0
import QGroundControl.ScreenTools   1.0
import QGroundControl.Controls      1.0


/// Mục vẽ đa giác. Thêm vào điều khiển của bạn và gọi các phương thức để có được sự hỗ trợ cho việc vẽ và điều chỉnh đa giác.
Item {
    id: _root

    // Những thuộc tính này phải được cung cấp bởi người tiêu dùng
    property var    map            ///< Bản đồ điều khiển
    property var    callbackObject ///< Mục gọi lại

    // Những thuộc tính này có thể được truy vấn bởi người tiêu dùng
    property bool   drawingPolygon:     false
    property bool   adjustingPolygon:   false
    property bool   polygonReady:       _currentPolygon ? _currentPolygon.path.length > 2 : false   ///< true: đủ điểm đã được chụp để tạo ra một đa giác đóng

    property var    _helpLabel                                  ///< Mục nhãn trợ giúp được thêm vào động
    property var    _newPolygon                                 ///< Mục đa giác mới được thêm vào động, đại diện cho tất cả các điểm đa giác bao gồm cả điểm đang được vẽ
    property var    _currentPolygon                             ///< Mục đa giác hiện tại được thêm vào động, đại diện cho đa giác đã hoàn thành hiện tại
    property var    _nextPointLine                              ///< Mục dòng tiếp theo được thêm vào động, đại diện cho dòng mới đang được vẽ
    property var    _mobileSegment                              ///< Mục dòng di động được thêm vào động, đại diện cho dòng giữa điểm đa giác đầu tiên và thứ hai cho di động
    property var    _mobilePoint                                ///< Mục điểm di động được thêm vào động, đại diện cho điểm đa giác đầu tiên trên di động
    property var    _mouseArea                                  ///< Mục khu vực chuột được thêm vào động, xử lý tất cả các nhấp chuột và di chuyển chuột
    property var    _vertexDragList:    [ ]                     ///< Mục danh sách kéo điểm đa giác được thêm vào động
    property bool   _mobile:            ScreenTools.isMobile

    /// Bắt đầu chụp một đa giác mới
    ///     polygonCaptureStarted sẽ được ký hiệu thông qua callbackObject
    function startCapturePolygon() {
        _helpLabel =        helpLabelComponent.createObject     (map)
        _newPolygon =       newPolygonComponent.createObject    (map)
        _currentPolygon =   currentPolygonComponent.createObject(map)
        _nextPointLine =    nextPointComponent.createObject     (map)
        _mobileSegment =    mobileSegmentComponent.createObject (map)
        _mobilePoint =      mobilePointComponent.createObject   (map)
        _mouseArea =        mouseAreaComponent.createObject     (map)

        map.addMapItem(_newPolygon)
        map.addMapItem(_currentPolygon)
        map.addMapItem(_nextPointLine)
        map.addMapItem(_mobileSegment)
        map.addMapItem(_mobilePoint)

        drawingPolygon = true
        callbackObject.polygonCaptureStarted()
    }

    /// Kết thúc chụp đa giác
    ///     polygonCaptureFinished sẽ được ký hiệu thông qua callbackObject
    /// @return true: đa giác hoàn thành, false: không đủ điểm để hoàn thành đa giác
    function finishCapturePolygon() {
        if (!polygonReady) {
            return false
        }
        var polygonPath = _currentPolygon.path
        _cancelCapturePolygon()
        callbackObject.polygonCaptureFinished(polygonPath)
        return true
    }

    function startAdjustPolygon(vertexCoordinates) {
        adjustingPolygon = true
        for (var i=0; i<vertexCoordinates.length; i++) {
            var dragItem = Qt.createQmlObject(
                        "import QtQuick                     2.3; " +
                        "import QtLocation                  5.3; " +
                        "import QGroundControl.ScreenTools  1.0; " +
                        "" +
                        "Rectangle {" +
                        "   id:     vertexDrag; " +
                        "   width:  _sideLength + _expandMargin; " +
                        "   height: _sideLength + _expandMargin; " +
                        "   color:  'red'; " +
                        "" +
                        "   property var coordinate; " +
                        "   property int index; " +
                        "" +
                        "   readonly property real _sideLength:     ScreenTools.defaultFontPixelWidth * 2; " +
                        "   readonly property real _halfSideLength: _sideLength / 2; " +
                        "" +
                        "   property real _expandMargin: ScreenTools.isMobile ? ScreenTools.defaultFontPixelWidth : 0;" +
                        "" +
                        "   Drag.active:    dragMouseArea.drag.active; " +
                        "" +
                        "   onXChanged: updateCoordinate(); " +
                        "   onYChanged: updateCoordinate(); " +
                        "" +
                        "   function updateCoordinate() { " +
                        "       vertexDrag.coordinate = map.toCoordinate(Qt.point(vertexDrag.x + _expandMargin + _halfSideLength, vertexDrag.y + _expandMargin + _halfSideLength), false); " +
                        "       callbackObject.polygonAdjustVertex(vertexDrag.index, vertexDrag.coordinate); " +
                        "   } " +
                        "" +
                        "   function updatePosition() { " +
                        "       var vertexPoint = map.fromCoordinate(coordinate, false); " +
                        "       vertexDrag.x = vertexPoint.x - _expandMargin - _halfSideLength; " +
                        "       vertexDrag.y = vertexPoint.y - _expandMargin - _halfSideLength; " +
                        "   } " +
                        "" +
                        "   Connections { " +
                        "       target:             map; " +
                        "       onCenterChanged:    updatePosition(); " +
                        "       onZoomLevelChanged: updatePosition(); " +
                        "   } " +
                        "" +
                        "   MouseArea { " +
                        "       id:             dragMouseArea; " +
                        "       anchors.fill:   parent; " +
                        "       drag.target:    parent; " +
                        "       drag.minimumX:  0; " +
                        "       drag.minimumY:  0; " +
                        "       drag.maximumX:  map.width - parent.width; " +
                        "       drag.maximumY:  map.height - parent.height; " +
                        "   } " +
                        "} ",
                        map)
            dragItem.z = QGroundControl.zOrderMapItems + 1
            dragItem.coordinate = vertexCoordinates[i]
            dragItem.index = i
            dragItem.updatePosition()
            _vertexDragList.push(dragItem)
            callbackObject.polygonAdjustStarted()
        }
    }

    function finishAdjustPolygon() {
        _cancelAdjustPolygon()
        callbackObject.polygonAdjustFinished()
    }

    /// Hủy bỏ một vẽ hoặc điều chỉnh đang diễn ra
    function cancelPolygonEdit() {
        _cancelAdjustPolygon()
        _cancelCapturePolygon()
    }

    function _cancelAdjustPolygon() {
        adjustingPolygon = false
        for (var i=0; i<_vertexDragList.length; i++) {
            _vertexDragList[i].destroy()
        }
        _vertexDragList = []
    }

    function _cancelCapturePolygon() {
        _helpLabel.destroy()
        _newPolygon.destroy()
        _currentPolygon.destroy()
        _nextPointLine.destroy()
        _mouseArea.destroy()
        drawingPolygon = false
    }

    Component {
        id: helpLabelComponent

        QGCMapLabel {
            id:                     polygonHelp
            anchors.topMargin:      parent.height - mainWindow.height
            anchors.top:            parent.top
            anchors.left:           parent.left
            anchors.right:          parent.right
            horizontalAlignment:    Text.AlignHCenter
            map:                    _root.map
            text:                   qsTr("Nhấp để thêm điểm %1").arg(ScreenTools.isMobile || !polygonReady ? "" : qsTr("- Nhấp chuột phải để kết thúc đa giác"))

            Connections {
                target: _root

                onDrawingPolygonChanged: {
                    if (drawingPolygon) {
                        polygonHelp.text = qsTr("Nhấp để thêm điểm")
                    }
                    polygonHelp.visible = drawingPolygon
                }

                onPolygonReadyChanged: {
                    if (polygonReady && !ScreenTools.isMobile) {
                        polygonHelp.text = qsTr("Nhấp để thêm điểm - Nhấp chuột phải để kết thúc đa giác")
                    }
                }

                onAdjustingPolygonChanged: {
                    if (adjustingPolygon) {
                        polygonHelp.text = qsTr("Điều chỉnh đa giác bằng cách kéo góc")
                    }
                    polygonHelp.visible = adjustingPolygon
                }
            }
        }
    }

    Component {
        id: mouseAreaComponent

        MouseArea {
            anchors.fill:       map
            acceptedButtons:    Qt.LeftButton | Qt.RightButton
            hoverEnabled:       true
            z:                  QGroundControl.zOrderMapItems + 1

            property bool   justClicked: false

            onClicked: {
                if (mouse.button == Qt.LeftButton) {
                    justClicked = true
                    if (_newPolygon.path.length > 2) {
                        // Đảm bảo dòng mới không giao nhau với đa giác hiện tại
                        var lastSegment = _newPolygon.path.length - 2
                        var newLineA = map.fromCoordinate(_newPolygon.path[lastSegment], false /* clipToViewPort */)
                        var newLineB = map.fromCoordinate(_newPolygon.path[lastSegment+1], false /* clipToViewPort */)
                        for (var i=0; i<lastSegment; i++) {
                            var oldLineA = map.fromCoordinate(_newPolygon.path[i], false /* clipToViewPort */)
                            var oldLineB = map.fromCoordinate(_newPolygon.path[i+1], false /* clipToViewPort */)
                            if (QGroundControl.linesIntersect(newLineA, newLineB, oldLineA, oldLineB)) {
                                return;
                            }
                        }
                    }

                    var clickCoordinate = map.toCoordinate(Qt.point(mouse.x, mouse.y), false /* clipToViewPort */)
                    var polygonPath = _newPolygon.path
                    if (polygonPath.length === 0) {
                        // Thêm tọa độ đầu tiên
                        polygonPath.push(clickCoordinate)
                    } else {
                        // Thêm tọa độ tiếp theo
                        if (ScreenTools.isMobile) {
                            // Vì di động không có chuột, onPositionChangedHandler sẽ không kích hoạt. Chúng ta phải thêm tọa độ
                            // ở đây thay vì.
                            justClicked = false
                            polygonPath.push(clickCoordinate)
                        } else {
                            // onPositionChanged handler cho di chuyển chuột đã thêm tọa độ vào mảng.
                            // Chỉ cần cập nhật nó đến vị trí cuối cùng
                            polygonPath[_newPolygon.path.length - 1] = clickCoordinate
                        }
                    }
                    _currentPolygon.path = polygonPath
                    _newPolygon.path = polygonPath

                    if (_mobile && _currentPolygon.path.length === 1) {
                        _mobilePoint.coordinate = _currentPolygon.path[0]
                        _mobilePoint.visible = true
                    } else if (_mobile && _currentPolygon.path.length === 2) {
                        // Hiển thị đoạn thẳng ban đầu trên di động
                        _mobileSegment.path = [ _currentPolygon.path[0], _currentPolygon.path[1] ]
                        _mobileSegment.visible = true
                        _mobilePoint.visible = false
                    } else {
                        _mobileSegment.visible = false
                        _mobilePoint.visible = false
                    }
                } else if (polygonReady) {
                    finishCapturePolygon()
                }
            }

            onPositionChanged: {
                if (ScreenTools.isMobile) {
                    // Chúng tôi không theo dõi kéo chuột trên di động
                    return
                }
                if (_newPolygon.path.length) {
                    var dragCoordinate = map.toCoordinate(Qt.point(mouse.x, mouse.y), false /* clipToViewPort */)
                    var polygonPath = _newPolygon.path
                    if (justClicked){
                        // Thêm tọa độ kéo mới
                        polygonPath.push(dragCoordinate)
                        justClicked = false
                    }

                    // Cập nhật dòng kéo
                    _nextPointLine.path = [ _newPolygon.path[_newPolygon.path.length - 2], dragCoordinate ]

                    polygonPath[_newPolygon.path.length - 1] = dragCoordinate
                    _newPolygon.path = polygonPath
                }
            }
        }
    }

    /// Đa giác đang được vẽ, bao gồm điểm mới
    Component {
        id: newPolygonComponent

        MapPolygon {
            color:      "blue"
            opacity:    0.5
            visible:    path.length > 2
        }
    }

    /// Đa giác hoàn thành hiện tại
    Component {
        id: currentPolygonComponent

        MapPolygon {
            color:      'green'
            opacity:    0.5
            visible:    polygonReady
        }
    }

    /// Dòng đầu tiên để hiển thị trên di động
    Component {
        id: mobileSegmentComponent

        MapPolyline {
            line.color: "green"
            line.width: 3
            visible:    false
        }
    }

    /// Điểm đầu tiên để hiển thị trên di động
    Component {
        id: mobilePointComponent

        MapQuickItem {
            anchorPoint.x:  rect.width / 2
            anchorPoint.y:  rect.height / 2
            visible:        false

            sourceItem: Rectangle {
                id:     rect
                width:  ScreenTools.defaultFontPixelHeight
                height: width
                color:  "green"
            }
        }
    }

    /// Dòng tiếp theo cho đa giác
    Component {
        id: nextPointComponent

        MapPolyline {
            line.color: "green"
            line.width: 3
        }
    }
}
