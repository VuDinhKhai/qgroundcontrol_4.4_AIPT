/****************************************************************************
 *
 * (c) 2021 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "MotorAssignment.h"
#include "ActuatorOutputs.h"

#include "QGCApplication.h"

#include <vector>

MotorAssignment::MotorAssignment(QObject* parent, Vehicle* vehicle, QmlObjectListModel* actuators)
        : QObject(parent), _vehicle(vehicle), _actuators(actuators)
{
    _spinTimer.setInterval(_spinTimeoutDefaultSec);
    _spinTimer.setSingleShot(true);
    connect(&_spinTimer, &QTimer::timeout, this, &MotorAssignment::spinTimeout);
}

bool MotorAssignment::initAssignment(int selectedActuatorIdx, int firstMotorsFunction, int numMotors)
{
    if (_state != State::Idle) {
        qCWarning(ActuatorsConfigLog) << "Already init/running";
    }

    // gather all the function facts
    _functionFacts.clear();
    for (int groupIdx = 0; groupIdx < _actuators->count(); groupIdx++) {
        auto group = qobject_cast<ActuatorOutputs::ActuatorOutput*>(_actuators->get(groupIdx));
        _functionFacts.append(QList<Fact*>{});
        group->getAllChannelFunctions(_functionFacts.last());
    }

    // Check the current configuration for these cases:
    // - no motors assigned: ask to assign to selected output
    // - there are motors, but none assigned to the selected output: ask to remove and assign to selected output
    // - partially assigned motors: abort with error
    // - all assigned to current output: nothing further to do

    int index = 0;
    std::vector<bool> selectedAssignment(numMotors);
    std::vector<bool> otherAssignment(numMotors);
    for (auto& group : _functionFacts) {
        bool selected = index == selectedActuatorIdx;
        for (auto& fact : group) {
            int currentFunction = fact->rawValue().toInt();
            if (currentFunction >= firstMotorsFunction && currentFunction < firstMotorsFunction + numMotors) {
                if (selected) {
                    selectedAssignment[currentFunction - firstMotorsFunction] = true;
                } else {
                    otherAssignment[currentFunction - firstMotorsFunction] = true;
                }
            }
        }
        ++index;
    }
    int numAssigned = 0;
    int numAssignedToSelected = 0;
    for (int i = 0; i < numMotors; ++i) {
        numAssigned += selectedAssignment[i] || otherAssignment[i];
        numAssignedToSelected += selectedAssignment[i];
    }

    QString selectedActuatorOutputName = qobject_cast<ActuatorOutputs::ActuatorOutput*>(_actuators->get(selectedActuatorIdx))->label();

    _assignMotors = false;
    QString extraMessage;
    if (numAssigned == 0 && _functionFacts[selectedActuatorIdx].size() >= numMotors) {
        _assignMotors = true;
        extraMessage = tr(
R"(<br />Chưa có động cơ nào được chỉ định.
Bằng cách nói có, tất cả các động cơ sẽ được gán cho %1 kênh đầu tiên của đầu ra đã chọn (%2)
 (bạn cũng có thể đầu tiên chỉ định tất cả các động cơ, sau đó bắt đầu nhận dạng).<br />)").arg(numMotors).arg(selectedActuatorOutputName);

    } else if (numAssigned > 0 && numAssignedToSelected == 0 && _functionFacts[selectedActuatorIdx].size() >= numMotors) {
        _assignMotors = true;
        extraMessage = tr(
R"(<br />Động cơ hiện đang được gán cho đầu ra khác.
Bằng cách nói có, tất cả các động cơ sẽ được chỉ định lại cho %1 kênh đầu tiên của đầu ra đã chọn (%2).<br />)")
            .arg(numMotors).arg(selectedActuatorOutputName);

    } else if (numAssigned < numMotors) {
        _message = tr("Chưa chỉ định tất cả động cơ. Hãy xóa tất cả các chỉ định hiện có hoặc chỉ định tất cả động cơ cho một đầu ra.");
        emit messageChanged();
        return false;
    }

    _message = tr(
R"(Điều này sẽ tự động quay từng động cơ với lực đẩy 15%.<br /><br />
<b>Cảnh báo: Chỉ tiến hành nếu bạn đã tháo hết cánh quạt</b>.<br />
%1
<br />
Quy trình thực hiện như sau:<br />
- Sau khi xác nhận, động cơ đầu tiên bắt đầu quay trong 0,5 giây.<br />
- Sau đó nhấp vào động cơ đang quay.<br />
- Lặp lại các bước trên cho tất cả các động cơ.<br />
- Các chức năng đầu ra của động cơ sẽ tự động được chỉ định lại theo thứ tự đã chọn.<br />
<br />
Bạn có muốn tiếp tục không?)").arg(extraMessage);
    emit messageChanged();

    _selectedActuatorIdx = selectedActuatorIdx;
    _firstMotorsFunction = firstMotorsFunction;
    _numMotors = numMotors;
    _selectedMotors.clear();
    _state = State::Init;
    emit activeChanged();
    return true;
}

void MotorAssignment::start()
{
    if (_state != State::Init) {
        qCWarning(ActuatorsConfigLog) << "Invalid state";
        return;
    }

    if (_assignMotors) {
        // clear all motors
        for (auto& group : _functionFacts) {
            for (auto& fact : group) {
                int currentFunction = fact->rawValue().toInt();
                if (currentFunction >= _firstMotorsFunction && currentFunction < _firstMotorsFunction + _numMotors) {
                    fact->setRawValue(0);
                }
            }
        }
        // assign to selected output
        int index = 0;
        for (auto& fact : _functionFacts[_selectedActuatorIdx]) {
            fact->setRawValue(_firstMotorsFunction + index);
            if (++index >= _numMotors) {
                break;
            }
        }
    }
    _state = State::Running;
    emit activeChanged();
    _spinTimer.setInterval(_assignMotors ? _spinTimeoutHighSec : _spinTimeoutDefaultSec);
    _spinTimer.start();
}

void MotorAssignment::selectMotor(int motorIndex)
{
    if (_state != State::Running) {
        qCDebug(ActuatorsConfigLog) << "Not running";
        return;
    }

    _selectedMotors.append(motorIndex);
    if (_selectedMotors.size() == _numMotors) {

        // finished, change functions
        for (auto& group : _functionFacts) {
            for (auto& fact : group) {
                int currentFunction = fact->rawValue().toInt();
                if (currentFunction >= _firstMotorsFunction && currentFunction < _firstMotorsFunction + _numMotors) {
                    // this is set to a motor -> update
                    fact->setRawValue(_firstMotorsFunction + _selectedMotors[currentFunction - _firstMotorsFunction]);
                }
            }
        }

        _state = State::Idle;
        emit activeChanged();
    } else {
        // spin the next motor after some time
        _spinTimer.setInterval(_spinTimeoutDefaultSec);
        _spinTimer.start();
    }
}

void MotorAssignment::spinCurrentMotor()
{
    if (!_commandInProgress) {
        _spinTimer.stop();
        int motorIndex = _selectedMotors.size();
        sendMavlinkRequest(_firstMotorsFunction + motorIndex, 0.15f);
    }
}

void MotorAssignment::abort()
{
    _spinTimer.stop();
    _state = State::Idle;
    emit activeChanged();
    emit onAbort();
}

void MotorAssignment::spinTimeout()
{
    spinCurrentMotor();
}

void MotorAssignment::ackHandlerEntry(void* resultHandlerData, int /*compId*/, const mavlink_command_ack_t& ack, Vehicle::MavCmdResultFailureCode_t failureCode)
{
    MotorAssignment* motorAssignment = (MotorAssignment*)resultHandlerData;
    motorAssignment->ackHandler(static_cast<MAV_RESULT>(ack.result), failureCode);
}

void MotorAssignment::ackHandler(MAV_RESULT commandResult, Vehicle::MavCmdResultFailureCode_t failureCode)
{
    _commandInProgress = false;
    if (failureCode != Vehicle::MavCmdResultFailureNoResponseToCommand && commandResult != MAV_RESULT_ACCEPTED) {
        abort();
        qgcApp()->showAppMessage(tr("Lệnh kiểm tra bộ truyền động không thành công"));
    }
}

void MotorAssignment::sendMavlinkRequest(int function, float value)
{
    qCDebug(ActuatorsConfigLog) << "Gửi chức năng kiểm tra bộ truyền động:" << function << "giá trị:" << value;

    Vehicle::MavCmdAckHandlerInfo_t handlerInfo = {};
    handlerInfo.resultHandler       = ackHandlerEntry;
    handlerInfo.resultHandlerData   = this;

    _vehicle->sendMavCommandWithHandler(
            &handlerInfo,
            MAV_COMP_ID_AUTOPILOT1,           // the ID of the autopilot
            MAV_CMD_ACTUATOR_TEST,            // the mavlink command
            value,                            // value
            0.5f,                             // timeout
            0,                                // unused parameter
            0,                                // unused parameter
            1000+function,                    // function
            0,                                // unused parameter
            0);
    _commandInProgress = true;
}
