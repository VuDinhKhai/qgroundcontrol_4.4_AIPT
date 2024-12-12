/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


#include "SyslinkComponent.h"
#include "AutoPilotPlugin.h"

SyslinkComponent::SyslinkComponent(Vehicle* vehicle, AutoPilotPlugin* autopilot, QObject* parent)
    : VehicleComponent(vehicle, autopilot, parent)
    , _name(tr("Liên kết hệ thống"))
{

}

QString SyslinkComponent::name(void) const
{
    return _name;
}

QString SyslinkComponent::description(void) const
{
    return tr("Thành phần Liên kết hệ thống được sử dụng để thiết lập kết nối radio trên Crazyflies.");
}

QString SyslinkComponent::iconResource(void) const
{
    return "/qmlimages/wifi.svg";
}

bool SyslinkComponent::requiresSetup(void) const
{
    return false;
}

bool SyslinkComponent::setupComplete(void) const
{
    return true;
}

QStringList SyslinkComponent::setupCompleteChangedTriggerList(void) const
{
    return QStringList();
}

QUrl SyslinkComponent::setupSource(void) const
{
    return QUrl::fromUserInput("qrc:/qml/SyslinkComponent.qml");
}

QUrl SyslinkComponent::summaryQmlSource(void) const
{
    return QUrl();
}

QString SyslinkComponent::prerequisiteSetup(void) const
{
    return QString();
}
