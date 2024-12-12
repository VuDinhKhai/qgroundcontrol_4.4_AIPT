/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/


#include "LogDownloadController.h"
#include "MultiVehicleManager.h"
#include "QGCMAVLink.h"
#include "UAS.h"
#include "QGCApplication.h"
#include "QGCToolbox.h"
#include "QGCMapEngine.h"
#include "ParameterManager.h"
#include "Vehicle.h"
#include "SettingsManager.h"

#include <QDebug>
#include <QSettings>
#include <QUrl>
#include <QBitArray>
#include <QtCore/qmath.h>

#define kTimeOutMilliseconds 500
#define kGUIRateMilliseconds 17
#define kTableBins           512
#define kChunkSize           (kTableBins * MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN)

QGC_LOGGING_CATEGORY(LogDownloadLog, "LogDownloadLog")

//-----------------------------------------------------------------------------
struct LogDownloadData {
    LogDownloadData(QGCLogEntry* entry);
    QBitArray     chunk_table;
    uint32_t      current_chunk;
    QFile         file;
    QString       filename;
    uint          ID;
    QGCLogEntry*  entry;
    uint          written;
    size_t        rate_bytes;
    qreal         rate_avg;
    QElapsedTimer elapsed;

    void advanceChunk()
    {
           current_chunk++;
           chunk_table = QBitArray(chunkBins(), false);
    }

    // The number of MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN bins in the current chunk
    uint32_t chunkBins() const
    {
        return qMin(qCeil((entry->size() - current_chunk*kChunkSize)/static_cast<qreal>(MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN)),
                    kTableBins);
    }

    // The number of kChunkSize chunks in the file
    uint32_t numChunks() const
    {
        return qCeil(entry->size() / static_cast<qreal>(kChunkSize));
    }

    // True if all bins in the chunk have been set to val
    bool chunkEquals(const bool val) const
    {
        return chunk_table == QBitArray(chunk_table.size(), val);
    }

};

//----------------------------------------------------------------------------------------
LogDownloadData::LogDownloadData(QGCLogEntry* entry_)
    : ID(entry_->id())
    , entry(entry_)
    , written(0)
    , rate_bytes(0)
    , rate_avg(0)
{

}

//----------------------------------------------------------------------------------------
QGCLogEntry::QGCLogEntry(uint logId, const QDateTime& dateTime, uint logSize, bool received)
    : _logID(logId)
    , _logSize(logSize)
    , _logTimeUTC(dateTime)
    , _received(received)
    , _selected(false)
{
    _status = tr("Đang chờ");
}

//----------------------------------------------------------------------------------------
QString
QGCLogEntry::sizeStr() const
{
    return QGCMapEngine::bigSizeToString(_logSize);
}

//----------------------------------------------------------------------------------------
LogDownloadController::LogDownloadController(void)
    : _uas(nullptr)
    , _downloadData(nullptr)
    , _vehicle(nullptr)
    , _requestingLogEntries(false)
    , _downloadingLogs(false)
    , _retries(0)
    , _apmOneBased(0)
{
    MultiVehicleManager *manager = qgcApp()->toolbox()->multiVehicleManager();
    connect(manager, &MultiVehicleManager::activeVehicleChanged, this, &LogDownloadController::_setActiveVehicle);
    connect(&_timer, &QTimer::timeout, this, &LogDownloadController::_processDownload);
    _setActiveVehicle(manager->activeVehicle());
}

//----------------------------------------------------------------------------------------
void
LogDownloadController::_processDownload()
{
    if (_requestingLogEntries) {
        _findMissingEntries();
    } else if (_downloadingLogs) {
        _findMissingData();
    }
}

//----------------------------------------------------------------------------------------
void
LogDownloadController::_setActiveVehicle(Vehicle* vehicle)
{
    if (_uas) {
        _logEntriesModel.clear();
        disconnect(_uas, &UASInterface::logEntry, this, &LogDownloadController::_logEntry);
        disconnect(_uas, &UASInterface::logData, this, &LogDownloadController::_logData);
        _uas = nullptr;
    }
    _vehicle = vehicle;
    if (_vehicle) {
        _uas = vehicle->uas();
        connect(_uas, &UASInterface::logEntry, this, &LogDownloadController::_logEntry);
        connect(_uas, &UASInterface::logData, this, &LogDownloadController::_logData);
    }
}

//----------------------------------------------------------------------------------------
void
LogDownloadController::_logEntry(UASInterface* uas, uint32_t time_utc, uint32_t size, uint16_t id, uint16_t num_logs, uint16_t /*last_log_num*/)
{
    //-- Chúng ta có quan tâm không?
    if (!_uas || uas != _uas || !_requestingLogEntries) {
        return;
    }
    //-- Nếu đây là lần đầu tiên, điền trước danh sách
    if (!_logEntriesModel.count() && num_logs > 0) {
        //-- Có phải APM không? Họ gửi một mục đầu tiên với ID sai và chỉ số đếm là hợp lệ.
        //   Từ bây giờ, tất cả các mục là 1-based.
        if (_vehicle->firmwareType() == MAV_AUTOPILOT_ARDUPILOTMEGA) {
            _apmOneBased = 1;
        }
        for (int i = 0; i < num_logs; i++) {
            QGCLogEntry *entry = new QGCLogEntry(i);
            _logEntriesModel.append(entry);
        }
    }
    //-- Cập nhật bản ghi nhật ký này
    if (num_logs > 0) {
        //-- Bỏ qua nếu trống (gói tin đầu tiên của APM)
        if (size || _vehicle->firmwareType() != MAV_AUTOPILOT_ARDUPILOTMEGA) {
            id -= _apmOneBased;
            if (id < _logEntriesModel.count()) {
                QGCLogEntry* entry = _logEntriesModel[id];
                entry->setSize(size);
                entry->setTime(QDateTime::fromSecsSinceEpoch(time_utc));
                entry->setReceived(true);
                entry->setStatus(tr("Sẵn sàng"));
            } else {
                qWarning() << "Nhận mục nhật ký vượt quá chỉ mục giới hạn:" << id;
            }
        }
    } else {
        //-- Không có nhật ký nào để liệt kê
        _receivedAllEntries();
    }
    //-- Đặt lại bộ đếm thử lại
    _retries = 0;
    //-- Chúng ta đã có tất cả chưa?
    if (_entriesComplete()) {
        _receivedAllEntries();
    } else {
        //-- Đặt lại bộ hẹn giờ
        _timer.start(kTimeOutMilliseconds);
    }
}

//----------------------------------------------------------------------------------------
bool
LogDownloadController::_entriesComplete()
{
    //-- Duyệt qua các mục và tìm khoảng trống
    int num_logs = _logEntriesModel.count();
    for (int i = 0; i < num_logs; i++) {
        QGCLogEntry* entry = _logEntriesModel[i];
        if (entry) {
            if (!entry->received()) {
               return false;
            }
        }
    }
    return true;
}

//----------------------------------------------------------------------------------------
void
LogDownloadController::_resetSelection(bool canceled)
{
    int num_logs = _logEntriesModel.count();
    for (int i = 0; i < num_logs; i++) {
        QGCLogEntry* entry = _logEntriesModel[i];
        if (entry) {
            if (entry->selected()) {
                if (canceled) {
                    entry->setStatus(tr("Đã hủy"));
                }
                entry->setSelected(false);
            }
        }
    }
    emit selectionChanged();
}

//----------------------------------------------------------------------------------------
void
LogDownloadController::_receivedAllEntries()
{
    _timer.stop();
    _setListing(false);
}

//----------------------------------------------------------------------------------------
void
LogDownloadController::_findMissingEntries()
{
    int start = -1;
    int end   = -1;
    int num_logs = _logEntriesModel.count();
    //-- Duyệt qua các mục và tìm khoảng trống
    for (int i = 0; i < num_logs; i++) {
        QGCLogEntry* entry = _logEntriesModel[i];
        if (entry) {
            if (!entry->received()) {
                if (start < 0)
                    start = i;
                else
                    end = i;
            } else {
                if (start >= 0) {
                    break;
                }
            }
        }
    }
    //-- Có thiếu mục nào không?
    if (start >= 0) {
        //-- Chúng ta đã thử quá nhiều lần chưa?
        if (_retries++ > 2) {
            for (int i = 0; i < num_logs; i++) {
                QGCLogEntry* entry = _logEntriesModel[i];
                if (entry && !entry->received()) {
                    entry->setStatus(tr("Lỗi"));
                }
            }
            //-- Bỏ cuộc
            _receivedAllEntries();
            qWarning() << "Quá nhiều lỗi khi lấy danh sách nhật ký. Từ bỏ.";
            return;
        }
        //-- Đây là một chuỗi hay chỉ một mục?
        if (end < 0) {
            end = start;
        }
        //-- Sửa lỗi APM
        start += _apmOneBased;
        end   += _apmOneBased;
        //-- Yêu cầu lại các mục này
        _requestLogList((uint32_t)start, (uint32_t)end);
    } else {
        _receivedAllEntries();
    }
}


void LogDownloadController::_updateDataRate(void)
{
    if (_downloadData->elapsed.elapsed() >= kGUIRateMilliseconds) {
        //-- Cập nhật tốc độ tải xuống
        qreal rrate = _downloadData->rate_bytes / (_downloadData->elapsed.elapsed() / 1000.0);
        _downloadData->rate_avg = (_downloadData->rate_avg * 0.95) + (rrate * 0.05);
        _downloadData->rate_bytes = 0;

        //-- Cập nhật trạng thái
        const QString status = QString("%1 (%2/s)").arg(QGCMapEngine::bigSizeToString(_downloadData->written),
                                                        QGCMapEngine::bigSizeToString(_downloadData->rate_avg));

        _downloadData->entry->setStatus(status);
        _downloadData->elapsed.start();
    }
}

//----------------------------------------------------------------------------------------
void
LogDownloadController::_logData(UASInterface* uas, uint32_t ofs, uint16_t id, uint8_t count, const uint8_t* data)
{
    if (!_uas || uas != _uas || !_downloadData) {
        return;
    }
    //-- Sửa lỗi APM
    id -= _apmOneBased;
    if (_downloadData->ID != id) {
        qWarning() << "Nhận dữ liệu nhật ký cho nhật ký sai";
        return;
    }

    if ((ofs % MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN) != 0) {
        qWarning() << "Bỏ qua gói dữ liệu không khớp @" << ofs;
        return;
    }

    bool result = false;
    uint32_t timeout_time = kTimeOutMilliseconds;
    if (ofs <= _downloadData->entry->size()) {
        const uint32_t chunk = ofs / kChunkSize;
        if (chunk != _downloadData->current_chunk) {
            qWarning() << "Bỏ qua gói tin không theo thứ tự chunk thực tế:kỳ vọng" << chunk << _downloadData->current_chunk;
            return;
        }
        const uint16_t bin = (ofs - chunk * kChunkSize) / MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN;
        if (bin >= _downloadData->chunk_table.size()) {
            qWarning() << "Nhận bin vượt giới hạn";
        } else
            _downloadData->chunk_table.setBit(bin);
        if (_downloadData->file.pos() != ofs) {
            // Tìm đến vị trí chính xác
            if (!_downloadData->file.seek(ofs)) {
                qWarning() << "Lỗi khi tìm vị trí file nhật ký";
                return;
            }
        }

        //-- Ghi chunk vào file
        if (_downloadData->file.write((const char*)data, count)) {
            _downloadData->written += count;
            _downloadData->rate_bytes += count;
            _updateDataRate();
            result = true;
            //-- Đặt lại bộ đếm thử lại
            _retries = 0;
            //-- Đặt lại bộ hẹn giờ
            _timer.start(timeout_time);
            //-- Chúng ta đã có tất cả chưa?
            if (_logComplete()) {
                _downloadData->entry->setStatus(tr("Đã tải xuống"));
                //-- Kiểm tra thêm
                _receivedAllData();
            } else if (_chunkComplete()) {
                _downloadData->advanceChunk();
                _requestLogData(_downloadData->ID,
                                _downloadData->current_chunk * kChunkSize,
                                _downloadData->chunk_table.size() * MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN);
            } else if (bin < _downloadData->chunk_table.size() - 1 && _downloadData->chunk_table.at(bin + 1)) {
                // Có khả năng đang thu thập các mảnh và đến cuối khoảng trống
                _findMissingData();
            }
        } else {
            qWarning() << "Lỗi khi ghi chunk file nhật ký";
        }
    } else {
        qWarning() << "Nhận offset nhật ký lớn hơn mong đợi";
    }
    if (!result) {
        _downloadData->entry->setStatus(tr("Lỗi"));
    }
}

//----------------------------------------------------------------------------------------
bool
LogDownloadController::_chunkComplete() const
{
    return _downloadData->chunkEquals(true);
}

//----------------------------------------------------------------------------------------
bool
LogDownloadController::_logComplete() const
{
    return _chunkComplete() && (_downloadData->current_chunk + 1) == _downloadData->numChunks();
}

//----------------------------------------------------------------------------------------
void
LogDownloadController::_receivedAllData()
{
    _timer.stop();
    //-- Có gì trong hàng đợi để tải xuống không?
    if (_prepareLogDownload()) {
        //-- Yêu cầu nhật ký
        _requestLogData(_downloadData->ID, 0, _downloadData->chunk_table.size() * MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN);
        _timer.start(kTimeOutMilliseconds);
    } else {
        _resetSelection();
        _setDownloading(false);
    }
}

//----------------------------------------------------------------------------------------
void
LogDownloadController::_findMissingData()
{
    if (_logComplete()) {
        _receivedAllData();
        return;
    } else if (_chunkComplete()) {
        _downloadData->advanceChunk();
    }

    _retries++;
#if 0
    // Thử thay đổi để tải nhật ký vô hạn. Cách này nếu retries đạt 100% thất bại,
    // tốc độ dữ liệu sẽ giảm dần xuống 0 và người dùng có thể hủy. Cách này hoạt động tốt hơn
    // trên các liên kết thực sự kém.
    if (_retries > 5) {
        _downloadData->entry->setStatus(tr("Hết thời gian"));
        //-- Từ bỏ
        qWarning() << "Quá nhiều lỗi khi lấy dữ liệu nhật ký. Từ bỏ.";
        _receivedAllData();
        return;
    }
#endif

    _updateDataRate();

    uint16_t start = 0, end = 0;
    const int size = _downloadData->chunk_table.size();
    for (; start < size; start++) {
        if (!_downloadData->chunk_table.testBit(start)) {
            break;
        }
    }

    for (end = start; end < size; end++) {
        if (_downloadData->chunk_table.testBit(end)) {
            break;
        }
    }

    const uint32_t pos = _downloadData->current_chunk * kChunkSize + start * MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN,
                   len = (end - start) * MAVLINK_MSG_LOG_DATA_FIELD_DATA_LEN;
    _requestLogData(_downloadData->ID, pos, len, _retries);
}

//----------------------------------------------------------------------------------------
void
LogDownloadController::_requestLogData(uint16_t id, uint32_t offset, uint32_t count, int retryCount)
{
    if (_vehicle) {
        WeakLinkInterfacePtr weakLink = _vehicle->vehicleLinkManager()->primaryLink();
        if (!weakLink.expired()) {
            SharedLinkInterfacePtr sharedLink = weakLink.lock();

            //-- Sửa lỗi APM
            id += _apmOneBased;
            qCDebug(LogDownloadLog) << "Yêu cầu dữ liệu nhật ký (id:" << id << "offset:" << offset << "size:" << count << "retryCount" << retryCount << ")";
            mavlink_message_t msg;
            mavlink_msg_log_request_data_pack_chan(
                        qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                        qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                        sharedLink->mavlinkChannel(),
                        &msg,
                        _vehicle->id(), _vehicle->defaultComponentId(),
                        id, offset, count);
            _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), msg);
        }
    }
}

//----------------------------------------------------------------------------------------
void
LogDownloadController::refresh(void)
{
    _logEntriesModel.clear();
    //-- Lấy 50 mục đầu tiên
    _requestLogList(0, 49);
}

//----------------------------------------------------------------------------------------
void
LogDownloadController::_requestLogList(uint32_t start, uint32_t end)
{
    if (_vehicle && _uas) {
        qCDebug(LogDownloadLog) << "Yêu cầu danh sách mục nhật ký (" << start << "đến" << end << ")";
        _setListing(true);
        WeakLinkInterfacePtr weakLink = _vehicle->vehicleLinkManager()->primaryLink();
        if (!weakLink.expired()) {
            SharedLinkInterfacePtr sharedLink = weakLink.lock();

            mavlink_message_t msg;
            mavlink_msg_log_request_list_pack_chan(
                        qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                        qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                        sharedLink->mavlinkChannel(),
                        &msg,
                        _vehicle->id(),
                        _vehicle->defaultComponentId(),
                        start,
                        end);
            _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), msg);
        }
        //-- Chờ 5 giây trước khi cảnh báo không nhận được gì
        _timer.start(5000);
    }
}

//----------------------------------------------------------------------------------------
void LogDownloadController::download(QString path)
{
    QString dir = path;
    if (dir.isEmpty()) {
        dir = qgcApp()->toolbox()->settingsManager()->appSettings()->logSavePath();
    }
    downloadToDirectory(dir);
}

void LogDownloadController::downloadToDirectory(const QString& dir)
{
    //-- Dừng danh sách trong trường hợp cần thiết
    _receivedAllEntries();
    //-- Đặt lại tải xuống, lại trong trường hợp cần thiết
    delete _downloadData;
    _downloadData = nullptr;

    _downloadPath = dir;
    if (!_downloadPath.isEmpty()) {
        if (!_downloadPath.endsWith(QDir::separator()))
            _downloadPath += QDir::separator();
        //-- Duyệt qua các mục đã chọn và hiển thị chúng là "chờ đợi"
        int num_logs = _logEntriesModel.count();
        for (int i = 0; i < num_logs; i++) {
            QGCLogEntry* entry = _logEntriesModel[i];
            if (entry) {
                if (entry->selected()) {
                   entry->setStatus(tr("Đang chờ"));
                }
            }
        }
        //-- Bắt đầu quá trình tải xuống
        _setDownloading(true);
        _receivedAllData();
    }
}

//----------------------------------------------------------------------------------------
QGCLogEntry* LogDownloadController::_getNextSelected()
{
    //-- Duyệt qua các mục và tìm một tệp được chọn
    int num_logs = _logEntriesModel.count();
    for (int i = 0; i < num_logs; i++) {
        QGCLogEntry* entry = _logEntriesModel[i];
        if (entry) {
            if (entry->selected()) {
               return entry;
            }
        }
    }
    return nullptr;
}

//----------------------------------------------------------------------------------------
bool LogDownloadController::_prepareLogDownload()
{
    delete _downloadData;
    _downloadData = nullptr;

    QGCLogEntry* entry = _getNextSelected();
    if (!entry) {
        return false;
    }
    //-- Bỏ chọn tệp
    entry->setSelected(false);
    emit selectionChanged();
    bool result = false;
    QString ftime;
    if (entry->time().date().year() < 2010) {
        ftime = tr("Ngày không xác định");
    } else {
        ftime = entry->time().toString(QStringLiteral("yyyy-M-d-hh-mm-ss"));
    }
    _downloadData = new LogDownloadData(entry);
    _downloadData->filename = QString("log_") + QString::number(entry->id()) + "_" + ftime;
    if (_vehicle->firmwareType() == MAV_AUTOPILOT_PX4) {
        QString loggerParam = QStringLiteral("SYS_LOGGER");
        if (_vehicle->parameterManager()->parameterExists(FactSystem::defaultComponentId, loggerParam) &&
                _vehicle->parameterManager()->getParameter(FactSystem::defaultComponentId, loggerParam)->rawValue().toInt() == 0) {
            _downloadData->filename += ".px4log";
        } else {
            _downloadData->filename += ".ulg";
        }
    } else {
        _downloadData->filename += ".bin";
    }
    _downloadData->file.setFileName(_downloadPath + _downloadData->filename);
    //-- Thêm số vào cuối nếu tên tệp đã tồn tại
    if (_downloadData->file.exists()) {
        uint num_dups = 0;
        QStringList filename_spl = _downloadData->filename.split('.');
        do {
            num_dups += 1;
            _downloadData->file.setFileName(filename_spl[0] + '_' + QString::number(num_dups) + '.' + filename_spl[1]);
        } while (_downloadData->file.exists());
    }
    //-- Tạo tệp
    if (!_downloadData->file.open(QIODevice::WriteOnly)) {
        qWarning() << "Không thể tạo tệp nhật ký:" << _downloadData->filename;
    } else {
        //-- Dành trước dung lượng tệp
        if (!_downloadData->file.resize(entry->size())) {
            qWarning() << "Không thể cấp phát dung lượng cho tệp nhật ký:" << _downloadData->filename;
        } else {
            _downloadData->current_chunk = 0;
            _downloadData->chunk_table = QBitArray(_downloadData->chunkBins(), false);
            _downloadData->elapsed.start();
            result = true;
        }
    }
    if (!result) {
        if (_downloadData->file.exists()) {
            _downloadData->file.remove();
        }
        _downloadData->entry->setStatus(tr("Lỗi"));
        delete _downloadData;
        _downloadData = nullptr;
    }
    return result;
}

//----------------------------------------------------------------------------------------
void LogDownloadController::_setDownloading(bool active)
{
    if (_downloadingLogs != active) {
        _downloadingLogs = active;
        _vehicle->vehicleLinkManager()->setCommunicationLostEnabled(!active);
        emit downloadingLogsChanged();
    }
}

//----------------------------------------------------------------------------------------
void LogDownloadController::_setListing(bool active)
{
    if (_requestingLogEntries != active) {
        _requestingLogEntries = active;
        _vehicle->vehicleLinkManager()->setCommunicationLostEnabled(!active);
        emit requestingListChanged();
    }
}

//----------------------------------------------------------------------------------------
void LogDownloadController::eraseAll(void)
{
    if (_vehicle && _uas) {
        WeakLinkInterfacePtr weakLink = _vehicle->vehicleLinkManager()->primaryLink();
        if (!weakLink.expired()) {
            SharedLinkInterfacePtr sharedLink = weakLink.lock();

            mavlink_message_t msg;
            mavlink_msg_log_erase_pack_chan(
                        qgcApp()->toolbox()->mavlinkProtocol()->getSystemId(),
                        qgcApp()->toolbox()->mavlinkProtocol()->getComponentId(),
                        sharedLink->mavlinkChannel(),
                        &msg,
                        qgcApp()->toolbox()->multiVehicleManager()->activeVehicle()->id(), qgcApp()->toolbox()->multiVehicleManager()->activeVehicle()->defaultComponentId());
            _vehicle->sendMessageOnLinkThreadSafe(sharedLink.get(), msg);
        }
        refresh();
    }
}

//----------------------------------------------------------------------------------------
void LogDownloadController::cancel(void)
{
    if (_uas) {
        _receivedAllEntries();
    }
    if (_downloadData) {
        _downloadData->entry->setStatus(tr("Đã hủy"));
        if (_downloadData->file.exists()) {
            _downloadData->file.remove();
        }
        delete _downloadData;
        _downloadData = nullptr;
    }
    _resetSelection(true);
    _setDownloading(false);
}

//-----------------------------------------------------------------------------

QGCLogModel::QGCLogModel(QObject* parent)
    : QAbstractListModel(parent)
{
}

//-----------------------------------------------------------------------------

QGCLogEntry* QGCLogModel::get(int index)
{
    if (index < 0 || index >= _logEntries.count()) {
        return nullptr;
    }
    return _logEntries[index];
}

//-----------------------------------------------------------------------------

int QGCLogModel::count() const
{
    return _logEntries.count();
}

//-----------------------------------------------------------------------------

void QGCLogModel::append(QGCLogEntry* object)
{
    beginInsertRows(QModelIndex(), rowCount(), rowCount());
    QQmlEngine::setObjectOwnership(object, QQmlEngine::CppOwnership);
    _logEntries.append(object);
    endInsertRows();
    emit countChanged();
}

//-----------------------------------------------------------------------------

void QGCLogModel::clear(void)
{
    if (!_logEntries.isEmpty()) {
        beginRemoveRows(QModelIndex(), 0, _logEntries.count());
        while (_logEntries.count()) {
            QGCLogEntry* entry = _logEntries.last();
            if (entry) entry->deleteLater();
            _logEntries.removeLast();
        }
        endRemoveRows();
        emit countChanged();
    }
}

//-----------------------------------------------------------------------------

QGCLogEntry* QGCLogModel::operator[](int index)
{
    return get(index);
}

//-----------------------------------------------------------------------------

int QGCLogModel::rowCount(const QModelIndex& /*parent*/) const
{
    return _logEntries.count();
}

//-----------------------------------------------------------------------------

QVariant QGCLogModel::data(const QModelIndex& index, int role) const
{
    if (index.row() < 0 || index.row() >= _logEntries.count())
        return QVariant();
    if (role == ObjectRole)
        return QVariant::fromValue(_logEntries[index.row()]);
    return QVariant();
}

//-----------------------------------------------------------------------------

QHash<int, QByteArray> QGCLogModel::roleNames() const
{
    QHash<int, QByteArray> roles;
    roles[ObjectRole] = "logEntry";
    return roles;
}
