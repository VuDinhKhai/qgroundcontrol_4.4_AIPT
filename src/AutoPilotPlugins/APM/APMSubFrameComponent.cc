/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


/// @file
///     @author Don Gagne <don@thegagnes.com>
///     @author Jacob Walser <jwalser90@gmail.com>

#include "APMSubFrameComponent.h"
#include "APMAutoPilotPlugin.h"
#include "APMAirframeComponent.h"

APMSubFrameComponent::APMSubFrameComponent(Vehicle* vehicle, AutoPilotPlugin* autopilot, QObject* parent)
    : VehicleComponent(vehicle, autopilot, parent)
    , _name(tr("Khung"))
{
}

QString APMSubFrameComponent::name(void) const
{
    return _name;
}

QString APMSubFrameComponent::description(void) const
{
    return tr("Thiết lập khung cho phép bạn chọn cấu hình động cơ của phương tiện. Lắp cánh quạt <b>quay theo chiều kim đồng hồ</b>" \
              "<br>vào <b>động cơ đẩy màu xanh lá</b> và cánh quạt <b>quay ngược chiều kim đồng hồ</b> vào <b>động cơ đẩy màu xanh dương</b>" \
              "<br>(hoặc ngược lại). Bộ điều khiển bay sẽ cần được khởi động lại để áp dụng các thay đổi." \
              "<br>Khi chọn khung, bạn có thể chọn tải bộ tham số mặc định cho cấu hình khung đó nếu có sẵn.");
}

QString APMSubFrameComponent::iconResource(void) const
{
    return QStringLiteral("/qmlimages/SubFrameComponentIcon.png");
}

bool APMSubFrameComponent::requiresSetup(void) const
{
    return false;
}

bool APMSubFrameComponent::setupComplete(void) const
{
    return true;
}

QStringList APMSubFrameComponent::setupCompleteChangedTriggerList(void) const
{
    return QStringList();
}

QUrl APMSubFrameComponent::setupSource(void) const
{
    return QUrl::fromUserInput(QStringLiteral("qrc:/qml/APMSubFrameComponent.qml"));
}

QUrl APMSubFrameComponent::summaryQmlSource(void) const
{
    return QUrl::fromUserInput(QStringLiteral("qrc:/qml/APMSubFrameComponentSummary.qml"));
}
