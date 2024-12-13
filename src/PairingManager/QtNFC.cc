/****************************************************************************
 *
 *   (c) 2019 DỰ ÁN QGROUNDCONTROL <http://www.qgroundcontrol.org>
 *
 * QGroundControl được cấp phép theo các điều khoản trong tệp
 * COPYING.md trong thư mục nguồn mã nguồn.
 *
 ****************************************************************************/
#include "PairingManager.h"
#include "QtNFC.h"
#include "QGCApplication.h"
#include <QSoundEffect>

QGC_LOGGING_CATEGORY(PairingNFCLog, "PairingNFCLog")

#include <QNdefNfcTextRecord>

//-----------------------------------------------------------------------------
PairingNFC::PairingNFC()
{
}

//-----------------------------------------------------------------------------
void
PairingNFC::start()
{
    if (manager != nullptr) {
        return;
    }
    qgcApp()->toolbox()->pairingManager()->setStatusMessage(tr("Đang chờ kết nối NFC"));
    qCDebug(PairingNFCLog) << "Đang chờ kết nối NFC";

    manager = new QNearFieldManager(this);
    if (!manager->isAvailable()) {
        qWarning() << "NFC không có sẵn";
        delete manager;
        manager = nullptr;
        return;
    }

    QNdefFilter filter;
    filter.setOrderMatch(false);
    filter.appendRecord<QNdefNfcTextRecord>(1, UINT_MAX);
    // type parameter cannot specify substring so filter for "image/" below
    filter.appendRecord(QNdefRecord::Mime, QByteArray(), 0, 1);

    int result = manager->registerNdefMessageHandler(filter, this, SLOT(handleMessage(QNdefMessage, QNearFieldTarget*)));

    if (result < 0)
        qWarning() << "Nền tảng không hỗ trợ đăng ký xử lý tin nhắn NDEF";

    manager->startTargetDetection();
    connect(manager, &QNearFieldManager::targetDetected, this, &PairingNFC::targetDetected);
    connect(manager, &QNearFieldManager::targetLost, this, &PairingNFC::targetLost);
}

//-----------------------------------------------------------------------------
void
PairingNFC::stop()
{
    if (manager != nullptr) {
        qgcApp()->toolbox()->pairingManager()->setStatusMessage("");
        qCDebug(PairingNFCLog) << "NFC: Dừng";
        manager->stopTargetDetection();
        delete manager;
        manager = nullptr;
    }
}

//-----------------------------------------------------------------------------
void
PairingNFC::targetDetected(QNearFieldTarget *target)
{
    if (!target) {
        return;
    }

    qgcApp()->toolbox()->pairingManager()->setStatusMessage(tr("Thiết bị được phát hiện"));
    qCDebug(PairingNFCLog) << "NFC: Thiết bị được phát hiện";
    connect(target, &QNearFieldTarget::ndefMessageRead, this, &PairingNFC::handlePolledNdefMessage);
    connect(target, SIGNAL(error(QNearFieldTarget::Error,QNearFieldTarget::RequestId)),
            this, SLOT(targetError(QNearFieldTarget::Error,QNearFieldTarget::RequestId)));
    connect(target, &QNearFieldTarget::requestCompleted, this, &PairingNFC::handleRequestCompleted);

    manager->setTargetAccessModes(QNearFieldManager::NdefReadTargetAccess);
    QNearFieldTarget::RequestId id = target->readNdefMessages();
    if (target->waitForRequestCompleted(id)) {
        qCDebug(PairingNFCLog) << "requestCompleted ";
        QVariant res = target->requestResponse(id);
        qCDebug(PairingNFCLog) << "Response:  " << res.toString();
    }
}

//-----------------------------------------------------------------------------
void
PairingNFC::handleRequestCompleted(const QNearFieldTarget::RequestId& id)
{
    Q_UNUSED(id);
    qCDebug(PairingNFCLog) << "handleRequestCompleted ";
}

//-----------------------------------------------------------------------------
void
PairingNFC::targetError(QNearFieldTarget::Error error, const QNearFieldTarget::RequestId& id)
{
    Q_UNUSED(id);
    qCDebug(PairingNFCLog) << "Lỗi: " << error;
}

//-----------------------------------------------------------------------------
void
PairingNFC::targetLost(QNearFieldTarget *target)
{
    qgcApp()->toolbox()->pairingManager()->setStatusMessage(tr("Thiết bị đã được gỡ bỏ"));
    qCDebug(PairingNFCLog) << "NFC: Thiết bị đã được gỡ bỏ";
    if (target) {
        target->deleteLater();
    }
}

//-----------------------------------------------------------------------------
void
PairingNFC::handlePolledNdefMessage(QNdefMessage message)
{
    qCDebug(PairingNFCLog) << "NFC: Xử lý tin nhắn NDEF";
//    QNearFieldTarget *target = qobject_cast<QNearFieldTarget *>(sender());
    for (const QNdefRecord &record : message) {
        if (record.isRecordType<QNdefNfcTextRecord>()) {
            QNdefNfcTextRecord textRecord(record);
            qgcApp()->toolbox()->pairingManager()->jsonReceived(textRecord.text());
        }
    }
}

//-----------------------------------------------------------------------------
