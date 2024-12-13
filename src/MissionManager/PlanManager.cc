/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "PlanManager.h"
#include "Vehicle.h"
#include "FirmwarePlugin.h"
#include "MAVLinkProtocol.h"
#include "QGCApplication.h"
#include "MissionCommandTree.h"
#include "MissionCommandUIInfo.h"

QGC_LOGGING_CATEGORY(PlanManagerLog, "PlanManagerLog")

PlanManager::PlanManager(Vehicle* vehicle, MAV_MISSION_TYPE planType)
    : _vehicle                  (vehicle)
    , _missionCommandTree       (qgcApp()->toolbox()->missionCommandTree())
    , _planType                 (planType)
    , _ackTimeoutTimer          (nullptr)
    , _expectedAck              (AckNone)
    , _transactionInProgress    (TransactionNone)
    , _resumeMission            (false)
    , _lastMissionRequest       (-1)
    , _missionItemCountToRead   (-1)
    , _currentMissionIndex      (-1)
    , _lastCurrentIndex         (-1)
{
    _ackTimeoutTimer = new QTimer(this);
    _ackTimeoutTimer->setSingleShot(true);

    connect(_ackTimeoutTimer, &QTimer::timeout, this, &PlanManager::_ackTimeout);
}

PlanManager::~PlanManager()
{

}

void PlanManager::_writeMissionItemsWorker(void)
{
    _lastMissionRequest = -1;

    emit progressPct(0);

    qCDebug(PlanManagerLog) << QStringLiteral("writeMissionItems %1 count:").arg(_planTypeString()) << _writeMissionItems.count();

    // Prime write list
    _itemIndicesToWrite.clear();
    for (int i=0; i<_writeMissionItems.count(); i++) {
        _itemIndicesToWrite << i;
    }

    _retryCount = 0;
    _setTransactionInProgress(TransactionWrite);
    _connectToMavlink();
    _writeMissionCount();
}


void PlanManager::writeMissionItems(const QList<MissionItem*>& missionItems)
{
    if (_vehicle->isOfflineEditingVehicle()) {
        return;
    }

    if (inProgress()) {
        qCDebug(PlanManagerLog) << QStringLiteral("writeMissionItems %1 called while transaction in progress").arg(_planTypeString());
        return;
    }

    _clearAndDeleteWriteMissionItems();

    bool skipFirstItem = _planType == MAV_MISSION_TYPE_MISSION && !_vehicle->firmwarePlugin()->sendHomePositionToVehicle();

    int firstIndex = skipFirstItem ? 1 : 0;

    for (int i=firstIndex; i<missionItems.count(); i++) {
        MissionItem* item = missionItems[i];
        _writeMissionItems.append(item); // PlanManager takes control of passed MissionItem

        item->setIsCurrentItem(i == firstIndex);

        if (skipFirstItem) {
            // Home is in sequence 0, remainder of items start at sequence 1
            item->setSequenceNumber(item->sequenceNumber() - 1);
            if (item->command() == MAV_CMD_DO_JUMP) {
                item->setParam1((int)item->param1() - 1);
            }
        }
    }

    _writeMissionItemsWorker();
}

/// This begins the write sequence with the vehicle. This may be called during a retry.
void PlanManager::_writeMissionCount(void)
{
    qCDebug(PlanManagerLog) << QStringLiteral("_writeMissionCount %1 count:_retryCount").arg(_planTypeString()) << _writeMissionItems.count() << _retryCount;

    WeakLinkInterfacePtr weakLink = _vehicle->vehicleLinkManager()->primaryLink();
    if (!weakLink.expired()) {
        mavlink_message_t       message;
        SharedLinkInterfacePtr  sharedLink = weakLink.lock();

        mavlink_msg_mission_count_pack_chan(qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                                            qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                                            sharedLink->mavlinkChannel(),
                                            &message,
                                            _vehicle->id(),
                                            MAV_COMP_ID_AUTOPILOT1,
                                            _writeMissionItems.count(),
                                            _planType);

        _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
    }
    _startAckTimeout(AckMissionRequest);
}

void PlanManager::loadFromVehicle(void)
{
    if (_vehicle->isOfflineEditingVehicle()) {
        return;
    }

    qCDebug(PlanManagerLog) << QStringLiteral("loadFromVehicle %1 read sequence").arg(_planTypeString());

    if (inProgress()) {
        qCDebug(PlanManagerLog) << QStringLiteral("loadFromVehicle %1 called while transaction in progress").arg(_planTypeString());
        return;
    }

    _retryCount = 0;
    _setTransactionInProgress(TransactionRead);
    _connectToMavlink();
    _requestList();
}

/// Internal call to request list of mission items. May be called during a retry sequence.
void PlanManager::_requestList(void)
{
    qCDebug(PlanManagerLog) << QStringLiteral("_requestList %1 _planType:_retryCount").arg(_planTypeString()) << _planType << _retryCount;

    _itemIndicesToRead.clear();
    _clearMissionItems();

    WeakLinkInterfacePtr weakLink = _vehicle->vehicleLinkManager()->primaryLink();
    if (!weakLink.expired()) {
        mavlink_message_t       message;
        SharedLinkInterfacePtr  sharedLink = weakLink.lock();

        mavlink_msg_mission_request_list_pack_chan(qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                                                   qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                                                   sharedLink->mavlinkChannel(),
                                                   &message,
                                                   _vehicle->id(),
                                                   MAV_COMP_ID_AUTOPILOT1,
                                                   _planType);

        _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
    }
    _startAckTimeout(AckMissionCount);
}

void PlanManager::_ackTimeout(void)
{
    if (_expectedAck == AckNone) {
        return;
    }

    switch (_expectedAck) {
    case AckNone:
        qCWarning(PlanManagerLog) << QStringLiteral("_ackTimeout %1 timeout với AckNone").arg(_planTypeString());
        _sendError(InternalError, tr("Lỗi nội bộ xảy ra trong quá trình giao tiếp mục tiêu: _ackTimeOut:_expectedAck == AckNone"));
        break;
    case AckMissionCount:
        // TIN NHẮN MISSION_COUNT được mong đợi
        if (_retryCount > _maxRetryCount) {
            _sendError(MaxRetryExceeded, tr("Yêu cầu danh sách nhiệm vụ thất bại, vượt quá số lần thử lại tối đa."));
            _finishTransaction(false);
        } else {
            _retryCount++;
            qCDebug(PlanManagerLog) << tr("Thử lại %1 REQUEST_LIST số lần thử lại").arg(_planTypeString()) << _retryCount;
            _requestList();
        }
        break;
    case AckMissionItem:
        // TIN NHẮN MISSION_ITEM được mong đợi
        if (_retryCount > _maxRetryCount) {
            _sendError(MaxRetryExceeded, tr("Đọc nhiệm vụ thất bại, vượt quá số lần thử lại tối đa."));
            _finishTransaction(false);
        } else {
            _retryCount++;
            qCDebug(PlanManagerLog) << tr("Thử lại %1 MISSION_REQUEST số lần thử lại").arg(_planTypeString()) << _retryCount;
            _requestNextMissionItem();
        }
        break;
    case AckMissionRequest:
        // TIN NHẮN MISSION_REQUEST được mong đợi, hoặc MISSION_ACK để kết thúc chuỗi
        if (_itemIndicesToWrite.count() == 0) {
            // Phương tiện không gửi MISSION_ACK cuối cùng tại cuối chuỗi
            _sendError(ProtocolError, tr("Viết nhiệm vụ thất bại, phương tiện không gửi ack cuối cùng."));
            _finishTransaction(false);
        } else if (_itemIndicesToWrite[0] == 0) {
            // Phương tiện không phản hồi MISSION_COUNT, thử lại
            if (_retryCount > _maxRetryCount) {
                _sendError(MaxRetryExceeded, tr("Viết số lượng nhiệm vụ thất bại, vượt quá số lần thử lại tối đa."));
                _finishTransaction(false);
            } else {
                _retryCount++;
                qCDebug(PlanManagerLog) << QStringLiteral("Thử lại %1 MISSION_COUNT số lần thử lại").arg(_planTypeString()) << _retryCount;
                _writeMissionCount();
            }
        } else {
            // Phương tiện không yêu cầu tất cả các mục từ trạm mặt đất
            _sendError(ProtocolError, tr("Phương tiện không yêu cầu tất cả các mục từ trạm mặt đất: %1").arg(_ackTypeToString(_expectedAck)));
            _expectedAck = AckNone;
            _finishTransaction(false);
        }
        break;
    case AckMissionClearAll:
        // TIN NHẮN MISSION_ACK được mong đợi
        if (_retryCount > _maxRetryCount) {
            _sendError(MaxRetryExceeded, tr("Xóa tất cả nhiệm vụ, vượt quá số lần thử lại tối đa."));
            _finishTransaction(false);
        } else {
            _retryCount++;
            qCDebug(PlanManagerLog) << tr("Thử lại %1 MISSION_CLEAR_ALL số lần thử lại").arg(_planTypeString()) << _retryCount;
            _removeAllWorker();
        }
        break;
    case AckGuidedItem:
        // TIN NHẮN MISSION_REQUEST được mong đợi, hoặc MISSION_ACK để kết thúc chuỗi
    default:
        _sendError(AckTimeoutError, tr("Phương tiện không phản hồi với giao tiếp mục tiêu: %1").arg(_ackTypeToString(_expectedAck)));
        _expectedAck = AckNone;
        _finishTransaction(false);
    }
}

void PlanManager::_startAckTimeout(AckType_t ack)
{
    switch (ack) {
    case AckMissionItem:
        // We are actively trying to get the mission item, so we don't want to wait as long.
        _ackTimeoutTimer->setInterval(_retryTimeoutMilliseconds);
        break;
    case AckNone:
        // FALLTHROUGH
    case AckMissionCount:
        // FALLTHROUGH
    case AckMissionRequest:
        // FALLTHROUGH
    case AckMissionClearAll:
        // FALLTHROUGH
    case AckGuidedItem:
        _ackTimeoutTimer->setInterval(_ackTimeoutMilliseconds);
        break;
    }

    _expectedAck = ack;
    _ackTimeoutTimer->start();
}

/// Checks the received ack against the expected ack. If they match the ack timeout timer will be stopped.
/// @return true: received ack matches expected ack
bool PlanManager::_checkForExpectedAck(AckType_t receivedAck)
{
    if (receivedAck == _expectedAck) {
        _expectedAck = AckNone;
        _ackTimeoutTimer->stop();
        return true;
    } else {
        if (_expectedAck == AckNone) {
            // Don't worry about unexpected mission commands, just ignore them; ArduPilot updates home position using
            // spurious MISSION_ITEMs.
        } else {
            // We just warn in this case, this could be crap left over from a previous transaction or the vehicle going bonkers.
            // Whatever it is we let the ack timeout handle any error output to the user.
            qCDebug(PlanManagerLog) << QString("Out of sequence ack %1 expected:received %2:%3").arg(_planTypeString().arg(_ackTypeToString(_expectedAck)).arg(_ackTypeToString(receivedAck)));
        }
        return false;
    }
}

void PlanManager::_readTransactionComplete(void)
{
    qCDebug(PlanManagerLog) << "_readTransactionComplete read sequence complete";
    
    WeakLinkInterfacePtr weakLink = _vehicle->vehicleLinkManager()->primaryLink();
    if (!weakLink.expired()) {
        SharedLinkInterfacePtr  sharedLink = weakLink.lock();
        mavlink_message_t       message;

        mavlink_msg_mission_ack_pack_chan(qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                                          qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                                          sharedLink->mavlinkChannel(),
                                          &message,
                                          _vehicle->id(),
                                          MAV_COMP_ID_AUTOPILOT1,
                                          MAV_MISSION_ACCEPTED,
                                          _planType);

        _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
    }

    _finishTransaction(true);
}

void PlanManager::_handleMissionCount(const mavlink_message_t& message)
{
    mavlink_mission_count_t missionCount;

    mavlink_msg_mission_count_decode(&message, &missionCount);

    if (missionCount.mission_type != _planType) {
        // if there was a previous transaction with a different mission_type, it can happen that we receive
        // a stale message here, for example when the MAV ran into a timeout and sent a message twice
        qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionCount %1 Incorrect mission_type received expected:actual").arg(_planTypeString()) << _planType << missionCount.mission_type;
        return;
    }

    if (!_checkForExpectedAck(AckMissionCount)) {
        return;
    }

    qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionCount %1 count:").arg(_planTypeString()) << missionCount.count;

    _retryCount = 0;

    if (missionCount.count == 0) {
        _readTransactionComplete();
    } else {
        // Prime read list
        for (int i=0; i<missionCount.count; i++) {
            _itemIndicesToRead << i;
        }
        _missionItemCountToRead = missionCount.count;
        _requestNextMissionItem();
    }
}
void PlanManager::_requestNextMissionItem(void)
{
    if (_itemIndicesToRead.count() == 0) {
        _sendError(InternalError, tr("Lỗi Nội bộ: Gọi đến _requestNextMissionItem của Xe với không có chỉ số nào để đọc nữa"));
        return;
    }

    qCDebug(PlanManagerLog) << QStringLiteral("_requestNextMissionItem %1 sequenceNumber:retry").arg(_planTypeString()) << _itemIndicesToRead[0] << _retryCount;

    WeakLinkInterfacePtr weakLink = _vehicle->vehicleLinkManager()->primaryLink();
    if (!weakLink.expired()) {
        SharedLinkInterfacePtr  sharedLink = weakLink.lock();
        mavlink_message_t       message;

        mavlink_msg_mission_request_int_pack_chan(qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                                                  qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                                                  sharedLink->mavlinkChannel(),
                                                  &message,
                                                  _vehicle->id(),
                                                  MAV_COMP_ID_AUTOPILOT1,
                                                  _itemIndicesToRead[0],
                                                  _planType);
        _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
    }
    _startAckTimeout(AckMissionItem);
}

void PlanManager::_handleMissionItem(const mavlink_message_t& message)
{
    MAV_CMD          command;
    MAV_FRAME        frame;
    MAV_MISSION_TYPE missionType;
    double           param1;
    double           param2;
    double           param3;
    double           param4;
    double           param5;
    double           param6;
    double           param7;
    bool             autoContinue;
    bool             isCurrentItem;
    int              seq;

    mavlink_mission_item_int_t missionItem;
    mavlink_msg_mission_item_int_decode(&message, &missionItem);

    command =       (MAV_CMD)missionItem.command;
    frame =         (MAV_FRAME)missionItem.frame;
    missionType =   (MAV_MISSION_TYPE)missionItem.mission_type;
    param1 =        missionItem.param1;
    param2 =        missionItem.param2;
    param3 =        missionItem.param3;
    param4 =        missionItem.param4;
    param5 =        missionItem.frame == MAV_FRAME_MISSION ? (double)missionItem.x : (double)missionItem.x * 1e-7;
    param6 =        missionItem.frame == MAV_FRAME_MISSION ? (double)missionItem.y : (double)missionItem.y * 1e-7;
    param7 =        (double)missionItem.z;
    autoContinue =  missionItem.autocontinue;
    isCurrentItem = missionItem.current;
    seq =           missionItem.seq;

    // Check the mission_type field. It can happen that we receive a late duplicate message for a
    // different mission_type request.
    if (missionType != _planType) {
       qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionItem %1 dropping spurious item seq:command:missionType").arg(_planTypeString()) << seq << command << missionType;
       return;
    }

    // We don't support editing ALT_INT frames so change on the way in.
    if (frame == MAV_FRAME_GLOBAL_INT) {
        frame = MAV_FRAME_GLOBAL;
    } else if (frame == MAV_FRAME_GLOBAL_RELATIVE_ALT_INT) {
        frame = MAV_FRAME_GLOBAL_RELATIVE_ALT;
    }

    bool ardupilotHomePositionUpdate = false;
    if (!_checkForExpectedAck(AckMissionItem)) {
        if (_vehicle->apmFirmware() && seq ==  0 && _planType == MAV_MISSION_TYPE_MISSION) {
            ardupilotHomePositionUpdate = true;
        } else {
            qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionItem %1 dropping spurious item seq:command:current").arg(_planTypeString()) << seq << command << isCurrentItem;
            return;
        }
    }

    qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionItem %1 seq:command:current:ardupilotHomePositionUpdate").arg(_planTypeString()) << seq << command << isCurrentItem << ardupilotHomePositionUpdate;

    if (ardupilotHomePositionUpdate) {
        QGeoCoordinate newHomePosition(param5, param6, param7);
        _vehicle->_setHomePosition(newHomePosition);
        return;
    }
    
    if (_itemIndicesToRead.contains(seq)) {
        _itemIndicesToRead.removeOne(seq);

        MissionItem* item = new MissionItem(seq,
                                            command,
                                            frame,
                                            param1,
                                            param2,
                                            param3,
                                            param4,
                                            param5,
                                            param6,
                                            param7,
                                            autoContinue,
                                            isCurrentItem,
                                            this);

        if (item->command() == MAV_CMD_DO_JUMP && !_vehicle->firmwarePlugin()->sendHomePositionToVehicle()) {
            // Home is in position 0
            item->setParam1((int)item->param1() + 1);
        }

        _missionItems.append(item);
    } else {
        qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionItem %1 mission item received item index which was not requested, disregrarding:").arg(_planTypeString()) << seq;
        // We have to put the ack timeout back since it was removed above
        _startAckTimeout(AckMissionItem);
        return;
    }

    emit progressPct((double)seq / (double)_missionItemCountToRead);
    
    _retryCount = 0;
    if (_itemIndicesToRead.count() == 0) {
        _readTransactionComplete();
    } else {
        _requestNextMissionItem();
    }
}

void PlanManager::_clearMissionItems(void)
{
    _itemIndicesToRead.clear();
    _clearAndDeleteMissionItems();
}

void PlanManager::_handleMissionRequest(const mavlink_message_t& message)
{
    MAV_MISSION_TYPE    missionRequestMissionType;
    uint16_t            missionRequestSeq;

    mavlink_mission_request_int_t missionRequest;
    mavlink_msg_mission_request_int_decode(&message, &missionRequest);
    missionRequestMissionType = static_cast<MAV_MISSION_TYPE>(missionRequest.mission_type);
    missionRequestSeq = missionRequest.seq;

    if (missionRequestMissionType != _planType) {
        // if there was a previous transaction with a different mission_type, it can happen that we receive
        // a stale message here, for example when the MAV ran into a timeout and sent a message twice
        qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionRequest %1 Incorrect mission_type received expected:actual").arg(_planTypeString()) << _planType << missionRequestMissionType;
        return;
    }
    
    if (!_checkForExpectedAck(AckMissionRequest)) {
        return;
    }
    qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionRequest %1 sốSequence").arg(_planTypeString()) << missionRequestSeq;

    if (missionRequestSeq > _writeMissionItems.count() - 1) {
        _sendError(RequestRangeError, tr("Phương tiện đã yêu cầu mục nằm ngoài phạm vi, số lượng:yêu cầu %1:%2. Gửi đến Phương tiện thất bại.").arg(_writeMissionItems.count()).arg(missionRequestSeq));
        _finishTransaction(false);
        return;
    }

    emit progressPct((double)missionRequestSeq / (double)_writeMissionItems.count());

    _lastMissionRequest = missionRequestSeq;
    if (!_itemIndicesToWrite.contains(missionRequestSeq)) {
        qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionRequest %1 sequence number requested which has already been sent, sending again:").arg(_planTypeString()) << missionRequestSeq;
    } else {
        _itemIndicesToWrite.removeOne(missionRequestSeq);
    }
    
    MissionItem* item = _writeMissionItems[missionRequestSeq];
    qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionRequest %1 sequenceNumber:command").arg(_planTypeString()) << missionRequestSeq << item->command();

    WeakLinkInterfacePtr weakLink = _vehicle->vehicleLinkManager()->primaryLink();
    if (!weakLink.expired()) {
        mavlink_message_t       messageOut;
        SharedLinkInterfacePtr  sharedLink = weakLink.lock();

        mavlink_msg_mission_item_int_pack_chan(qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                                               qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                                               sharedLink->mavlinkChannel(),
                                               &messageOut,
                                               _vehicle->id(),
                                               MAV_COMP_ID_AUTOPILOT1,
                                               missionRequestSeq,
                                               item->frame(),
                                               item->command(),
                                               missionRequestSeq == 0,
                                               item->autoContinue(),
                                               item->param1(),
                                               item->param2(),
                                               item->param3(),
                                               item->param4(),
                                               item->frame() == MAV_FRAME_MISSION ? item->param5() : item->param5() * 1e7,
                                               item->frame() == MAV_FRAME_MISSION ? item->param6() : item->param6() * 1e7,
                                               item->param7(),
                                               _planType);
        _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), messageOut);
    }
    _startAckTimeout(AckMissionRequest);
}

void PlanManager::_handleMissionAck(const mavlink_message_t& message)
{
    mavlink_mission_ack_t missionAck;
    
    mavlink_msg_mission_ack_decode(&message, &missionAck);
    if (missionAck.mission_type != _planType) {
        // if there was a previous transaction with a different mission_type, it can happen that we receive
        // a stale message here, for example when the MAV ran into a timeout and sent a message twice
        qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionAck %1 Incorrect mission_type received expected:actual").arg(_planTypeString()) << _planType << missionAck.mission_type;
        return;
    }

    if (_vehicle->apmFirmware() && missionAck.type == MAV_MISSION_INVALID_SEQUENCE) {
        // ArduPilot sends these Acks which can happen just due to noisy links causing duplicated requests being responded to.
        // As far as I'm concerned this is incorrect protocol implementation but we need to deal with it anyway. So we just
        // ignore it and if things really go haywire the timeouts will fire to fail the overall transaction.
        qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionAck ArduPilot sending possibly bogus MAV_MISSION_INVALID_SEQUENCE").arg(_planTypeString()) << _planType;
        return;
    }

    // Save the retry ack before calling _checkForExpectedAck since we'll need it to determine what
    // type of a protocol sequence we are in.
    AckType_t savedExpectedAck = _expectedAck;
    
    // We can get a MISSION_ACK with an error at any time, so if the Acks don't match it is not
    // a protocol sequence error. Call _checkForExpectedAck with _retryAck so it will succeed no
    // matter what.
    if (!_checkForExpectedAck(_expectedAck)) {
        return;
    }

    qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionAck %1 type:").arg(_planTypeString()) << _missionResultToString((MAV_MISSION_RESULT)missionAck.type);

    switch (savedExpectedAck) {
    case AckNone:
        // State machine is idle. Vehicle is confused.
        qCDebug(PlanManagerLog) << QStringLiteral("Vehicle sent unexpected MISSION_ACK message, error: %1").arg(_missionResultToString((MAV_MISSION_RESULT)missionAck.type));
        break;
    case AckMissionCount:
        // MISSION_COUNT message expected
        // FIXME: Protocol error
        _sendError(VehicleAckError, _missionResultToString((MAV_MISSION_RESULT)missionAck.type));
        _finishTransaction(false);
        break;
    case AckMissionItem:
        // MISSION_ITEM expected
        // FIXME: Protocol error
        _sendError(VehicleAckError, _missionResultToString((MAV_MISSION_RESULT)missionAck.type));
        _finishTransaction(false);
        break;
    case AckMissionRequest:
        // MISSION_REQUEST is expected, or MAV_MISSION_ACCEPTED to end sequence
        if (missionAck.type == MAV_MISSION_ACCEPTED) {
            if (_itemIndicesToWrite.count() == 0) {
                qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionAck write sequence complete %1").arg(_planTypeString());
                _finishTransaction(true);
            } else {
                // FIXME: Protocol error
                _sendError(VehicleAckError, _missionResultToString((MAV_MISSION_RESULT)missionAck.type));
                _finishTransaction(false);
            }
        } else {
            _sendError(VehicleAckError, _missionResultToString((MAV_MISSION_RESULT)missionAck.type));
            _finishTransaction(false);
        }
        break;
    case AckMissionClearAll:
        // MAV_MISSION_ACCEPTED được mong đợi
        if (missionAck.type != MAV_MISSION_ACCEPTED) {
            _sendError(VehicleAckError, tr("Xe không thể xóa tất cả. Lỗi: %1").arg(_missionResultToString((MAV_MISSION_RESULT)missionAck.type)));
        }
        _finishTransaction(missionAck.type == MAV_MISSION_ACCEPTED);
        break;
    case AckGuidedItem:
        // MISSION_REQUEST được mong đợi, hoặc MAV_MISSION_ACCEPTED để kết thúc chuỗi
        if (missionAck.type == MAV_MISSION_ACCEPTED) {
            qCDebug(PlanManagerLog) << QStringLiteral("_handleMissionAck %1 mục tiêu chế độ hướng dẫn được chấp nhận").arg(_planTypeString());
            _finishTransaction(true, true /* apmGuidedItemWrite */);
        } else {
            // FIXME: Lỗi giao thức
            _sendError(VehicleAckError, tr("Xe trả về lỗi: %1. %2Xe không chấp nhận mục tiêu hướng dẫn.").arg(_missionResultToString((MAV_MISSION_RESULT)missionAck.type)));
            _finishTransaction(false, true /* apmGuidedItemWrite */);
        }
        break;
    }
}

/// Called when a new mavlink message for out vehicle is received
void PlanManager::_mavlinkMessageReceived(const mavlink_message_t& message)
{
    switch (message.msgid) {
    case MAVLINK_MSG_ID_MISSION_COUNT:
        _handleMissionCount(message);
        break;

    case MAVLINK_MSG_ID_MISSION_ITEM_INT:
        _handleMissionItem(message);
        break;

    case MAVLINK_MSG_ID_MISSION_REQUEST:
    case MAVLINK_MSG_ID_MISSION_REQUEST_INT:
        _handleMissionRequest(message);
        break;

    case MAVLINK_MSG_ID_MISSION_ACK:
        _handleMissionAck(message);
        break;
    }
}

void PlanManager::_sendError(ErrorCode_t errorCode, const QString& errorMsg)
{
    qCDebug(PlanManagerLog) << QStringLiteral("Sending error - _planTypeString(%1) errorCode(%2) errorMsg(%4)").arg(_planTypeString()).arg(errorCode).arg(errorMsg);

    emit error(errorCode, errorMsg);
}

QString PlanManager::_ackTypeToString(AckType_t ackType)
{
    switch (ackType) {
    case AckNone:
        return QString("No Ack");
    case AckMissionCount:
        return QString("MISSION_COUNT");
    case AckMissionItem:
        return QString("MISSION_ITEM");
    case AckMissionRequest:
        return QString("MISSION_REQUEST");
    case AckGuidedItem:
        return QString("Guided Mode Item");
    default:
        qWarning(PlanManagerLog) << QStringLiteral("Fell off end of switch statement %1").arg(_planTypeString());
        return QString("QGC Internal Error");
    }
}

QString PlanManager::_lastMissionReqestString(MAV_MISSION_RESULT result)
{
    QString prefix;
    QString postfix;

    if (_lastMissionRequest >= 0 && _lastMissionRequest < _writeMissionItems.count()) {
        MissionItem* item = _writeMissionItems[_lastMissionRequest];

        prefix = tr("Item #%1 Command: %2").arg(_lastMissionRequest).arg(_missionCommandTree->friendlyName(item->command()));

        switch (result) {
        case MAV_MISSION_UNSUPPORTED_FRAME:
            postfix = tr("Frame: %1").arg(item->frame());
            break;
        case MAV_MISSION_UNSUPPORTED:
            // All we need is the prefix
            break;
        case MAV_MISSION_INVALID_PARAM1:
            postfix = tr("Value: %1").arg(item->param1());
            break;
        case MAV_MISSION_INVALID_PARAM2:
            postfix = tr("Value: %1").arg(item->param2());
            break;
        case MAV_MISSION_INVALID_PARAM3:
            postfix = tr("Value: %1").arg(item->param3());
            break;
        case MAV_MISSION_INVALID_PARAM4:
            postfix = tr("Value: %1").arg(item->param4());
            break;
        case MAV_MISSION_INVALID_PARAM5_X:
            postfix = tr("Value: %1").arg(item->param5());
            break;
        case MAV_MISSION_INVALID_PARAM6_Y:
            postfix = tr("Value: %1").arg(item->param6());
            break;
        case MAV_MISSION_INVALID_PARAM7:
            postfix = tr("Value: %1").arg(item->param7());
            break;
        case MAV_MISSION_INVALID_SEQUENCE:
            // All we need is the prefix
            break;
        default:
            break;
        }
    }

    return prefix + (postfix.isEmpty() ? QStringLiteral("") : QStringLiteral(" ")) + postfix;
}

QString PlanManager::_missionResultToString(MAV_MISSION_RESULT result)
{
    QString error;
    switch (result) {
    case MAV_MISSION_ACCEPTED:
        error = tr("Nhiệm vụ được chấp nhận.");
        break;
    case MAV_MISSION_ERROR:
        error = tr("Lỗi không xác định.");
        break;
    case MAV_MISSION_UNSUPPORTED_FRAME:
        error = tr("Khung tọa độ không được hỗ trợ.");
        break;
    case MAV_MISSION_UNSUPPORTED:
        error = tr("Lệnh không được hỗ trợ.");
        break;
    case MAV_MISSION_NO_SPACE:
        error = tr("Mục nhiệm vụ vượt quá không gian lưu trữ.");
        break;
    case MAV_MISSION_INVALID:
        error = tr("Một trong các tham số có giá trị không hợp lệ.");
        break;
    case MAV_MISSION_INVALID_PARAM1:
        error = tr("Giá trị không hợp lệ của Param 1.");
        break;
    case MAV_MISSION_INVALID_PARAM2:
        error = tr("Giá trị không hợp lệ của Param 2.");
        break;
    case MAV_MISSION_INVALID_PARAM3:
        error = tr("Giá trị không hợp lệ của Param 3.");
        break;
    case MAV_MISSION_INVALID_PARAM4:
        error = tr("Giá trị không hợp lệ của Param 4.");
        break;
    case MAV_MISSION_INVALID_PARAM5_X:
        error = tr("Giá trị không hợp lệ của Param 5.");
        break;
    case MAV_MISSION_INVALID_PARAM6_Y:
        error = tr("Giá trị không hợp lệ của Param 6.");
        break;
    case MAV_MISSION_INVALID_PARAM7:
        error = tr("Giá trị không hợp lệ của Param 7.");
        break;
    case MAV_MISSION_INVALID_SEQUENCE:
        error = tr("Nhận được mục nhiệm vụ không đúng thứ tự.");
        break;
    case MAV_MISSION_DENIED:
        error = tr("Không chấp nhận bất kỳ lệnh nhiệm vụ nào.");
        break;
    default:
        qWarning(PlanManagerLog) << QStringLiteral("Rơi khỏi cuối của câu lệnh switch %1 %2").arg(_planTypeString()).arg(result);
        error = tr("Lỗi không biết: %1.").arg(result);
        break;
    }

    QString lastRequestString = _lastMissionReqestString(result);
    if (!lastRequestString.isEmpty()) {
        error += QStringLiteral(" ") + lastRequestString;
    }

    return error;
}

void PlanManager::_finishTransaction(bool success, bool apmGuidedItemWrite)
{
    emit progressPct(1);
    _disconnectFromMavlink();

    _itemIndicesToRead.clear();
    _itemIndicesToWrite.clear();

    // First thing we do is clear the transaction. This way inProgesss is off when we signal transaction complete.
    TransactionType_t currentTransactionType = _transactionInProgress;
    _setTransactionInProgress(TransactionNone);

    switch (currentTransactionType) {
    case TransactionRead:
        if (!success) {
            // Read from vehicle failed, clear partial list
            _clearAndDeleteMissionItems();
        }
        emit newMissionItemsAvailable(false);
        break;
    case TransactionWrite:
        // No need to do anything for ArduPilot guided go to waypoint write
        if (!apmGuidedItemWrite) {
            if (success) {
                // Write succeeded, update internal list to be current
                if (_planType == MAV_MISSION_TYPE_MISSION) {
                    _currentMissionIndex = -1;
                    _lastCurrentIndex = -1;
                    emit currentIndexChanged(-1);
                    emit lastCurrentIndexChanged(-1);
                }
                _clearAndDeleteMissionItems();
                for (int i=0; i<_writeMissionItems.count(); i++) {
                    _missionItems.append(_writeMissionItems[i]);
                }
                _writeMissionItems.clear();
            } else {
                // Write failed, throw out the write list
                _clearAndDeleteWriteMissionItems();
            }
            emit sendComplete(!success /* error */);
        }
        break;
    case TransactionRemoveAll:
        emit removeAllComplete(!success /* error */);
        break;
    default:
        break;
    }

    if (_resumeMission) {
        _resumeMission = false;
        if (success) {
            emit resumeMissionReady();
        } else {
            emit resumeMissionUploadFail();
        }
    }
}

bool PlanManager::inProgress(void) const
{
    return _transactionInProgress != TransactionNone;
}

void PlanManager::_removeAllWorker(void)
{
    qCDebug(PlanManagerLog) << "_removeAllWorker";

    emit progressPct(0);

    _connectToMavlink();

    WeakLinkInterfacePtr weakLink = _vehicle->vehicleLinkManager()->primaryLink();
    if (!weakLink.expired()) {
        mavlink_message_t       message;
        SharedLinkInterfacePtr  sharedLink = weakLink.lock();

        mavlink_msg_mission_clear_all_pack_chan(qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                                                qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                                                sharedLink->mavlinkChannel(),
                                                &message,
                                                _vehicle->id(),
                                                MAV_COMP_ID_AUTOPILOT1,
                                                _planType);
        _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), message);
    }
    _startAckTimeout(AckMissionClearAll);
}

void PlanManager::removeAll(void)
{
    if (inProgress()) {
        return;
    }

    qCDebug(PlanManagerLog) << QStringLiteral("removeAll %1").arg(_planTypeString());

    _clearAndDeleteMissionItems();

    if (_planType == MAV_MISSION_TYPE_MISSION) {
        _currentMissionIndex = -1;
        _lastCurrentIndex = -1;
        emit currentIndexChanged(-1);
        emit lastCurrentIndexChanged(-1);
    }

    _retryCount = 0;
    _setTransactionInProgress(TransactionRemoveAll);

    _removeAllWorker();
}

void PlanManager::_clearAndDeleteMissionItems(void)
{
    for (int i=0; i<_missionItems.count(); i++) {
        // Using deleteLater here causes too much transient memory to stack up
        delete _missionItems[i];
    }
    _missionItems.clear();
}


void PlanManager::_clearAndDeleteWriteMissionItems(void)
{
    for (int i=0; i<_writeMissionItems.count(); i++) {
        // Using deleteLater here causes too much transient memory to stack up
        delete _writeMissionItems[i];
    }
    _writeMissionItems.clear();
}

void PlanManager::_connectToMavlink(void)
{
    connect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &PlanManager::_mavlinkMessageReceived);
}

void PlanManager::_disconnectFromMavlink(void)
{
    disconnect(_vehicle, &Vehicle::mavlinkMessageReceived, this, &PlanManager::_mavlinkMessageReceived);
}

QString PlanManager::_planTypeString(void)
{
    switch (_planType) {
    case MAV_MISSION_TYPE_MISSION:
        return QStringLiteral("T:Mission");
    case MAV_MISSION_TYPE_FENCE:
        return QStringLiteral("T:GeoFence");
    case MAV_MISSION_TYPE_RALLY:
        return QStringLiteral("T:Rally");
    default:
        qWarning() << "Unknown plan type" << _planType;
        return QStringLiteral("T:Unknown");
    }
}

void PlanManager::_setTransactionInProgress(TransactionType_t type)
{
    if (_transactionInProgress  != type) {
        qCDebug(PlanManagerLog) << "_setTransactionInProgress" << _planTypeString() << type;
        _transactionInProgress = type;
        emit inProgressChanged(inProgress());
    }
}
