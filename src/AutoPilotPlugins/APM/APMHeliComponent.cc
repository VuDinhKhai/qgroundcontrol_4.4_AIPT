/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "APMHeliComponent.h"
#include "APMAutoPilotPlugin.h"

APMHeliComponent::APMHeliComponent(Vehicle* vehicle, AutoPilotPlugin* autopilot, QObject* parent)
    : VehicleComponent(vehicle, autopilot, parent)
    , _name(tr("Trực thăng"))
{
}

QString APMHeliComponent::name(void) const
{
    return _name;
}

QString APMHeliComponent::description(void) const
{
    return tr("Cài đặt Trực thăng được sử dụng để thiết lập các tham số dành riêng cho trực thăng.");
}

QString APMHeliComponent::iconResource(void) const
{
    return "/res/helicoptericon.svg";
}

bool APMHeliComponent::requiresSetup(void) const
{
    return false;
}

bool APMHeliComponent::setupComplete(void) const
{
    return true;
}

QStringList APMHeliComponent::setupCompleteChangedTriggerList(void) const
{
    return QStringList();
}

QUrl APMHeliComponent::setupSource(void) const
{
    return QStringLiteral("qrc:/qml/APMHeliComponent.qml");
}

QUrl APMHeliComponent::summaryQmlSource(void) const
{
    return QUrl();
}
