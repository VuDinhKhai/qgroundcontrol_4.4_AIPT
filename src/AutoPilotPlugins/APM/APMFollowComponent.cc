/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "APMFollowComponent.h"
#include "APMAutoPilotPlugin.h"
#include "APMAirframeComponent.h"
#include "ParameterManager.h"

APMFollowComponent::APMFollowComponent(Vehicle* vehicle, AutoPilotPlugin* autopilot, QObject* parent)
    : VehicleComponent(vehicle, autopilot, parent),
    _name(tr("Theo dõi Tôi"))
{
}

QString APMFollowComponent::name(void) const
{
    return _name;
}

QString APMFollowComponent::description(void) const
{
    return tr("Cài đặt Theo dõi Tôi được sử dụng để cấu hình hỗ trợ cho phương tiện theo dõi vị trí trạm mặt đất.");
}

QString APMFollowComponent::iconResource(void) const
{
    return QStringLiteral("/qmlimages/FollowComponentIcon.png");
}

QUrl APMFollowComponent::setupSource(void) const
{
    return QUrl::fromUserInput(QStringLiteral("qrc:/qml/APMFollowComponent.qml"));
}

QUrl APMFollowComponent::summaryQmlSource(void) const
{
    return QUrl::fromUserInput(QStringLiteral("qrc:/qml/APMFollowComponentSummary.qml"));
}
