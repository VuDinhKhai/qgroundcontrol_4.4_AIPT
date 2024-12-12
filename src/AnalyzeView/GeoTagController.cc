/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/
 
#include "GeoTagController.h"
#include "QGCLoggingCategory.h"
#include <math.h>
#include <QtEndian>
#include <QDebug>
#include <cfloat>
#include <QDir>
#include <QUrl>

#include "ExifParser.h"
#include "ULogParser.h"
#include "PX4LogParser.h"

static const char* kTagged = "/TAGGED";

GeoTagController::GeoTagController()
    : _progress(0)
    , _inProgress(false)
{
    connect(&_worker, &GeoTagWorker::progressChanged,   this, &GeoTagController::_workerProgressChanged);
    connect(&_worker, &GeoTagWorker::error,             this, &GeoTagController::_workerError);
    connect(&_worker, &GeoTagWorker::started,           this, &GeoTagController::inProgressChanged);
    connect(&_worker, &GeoTagWorker::finished,          this, &GeoTagController::inProgressChanged);
}

GeoTagController::~GeoTagController()
{

}

void GeoTagController::setLogFile(QString filename)
{
    filename = QUrl(filename).toLocalFile();
    if (!filename.isEmpty()) {
        _worker.setLogFile(filename);
        emit logFileChanged(filename);
    }
}

void GeoTagController::setImageDirectory(QString dir)
{
    dir = QUrl(dir).toLocalFile();
    if (!dir.isEmpty()) {
        _worker.setImageDirectory(dir);
        emit imageDirectoryChanged(dir);
        if(_worker.saveDirectory() == "") {
            QDir saveDirectory = QDir(_worker.imageDirectory() + kTagged);
            if(saveDirectory.exists()) {
                _setErrorMessage(tr("Hình ảnh đã được gắn thẻ trước đó. Các hình ảnh hiện tại sẽ bị xóa."));
                return;
            }
        }
    }
    _errorMessage.clear();
    emit errorMessageChanged(_errorMessage);
}

void GeoTagController::setSaveDirectory(QString dir)
{
    dir = QUrl(dir).toLocalFile();
    if (!dir.isEmpty()) {
        _worker.setSaveDirectory(dir);
        emit saveDirectoryChanged(dir);
        //-- Kiểm tra nếu thư mục lưu đã có hình ảnh
        QDir saveDirectory = QDir(_worker.saveDirectory());
        saveDirectory.setFilter(QDir::Files | QDir::Readable | QDir::NoSymLinks | QDir::Writable);
        QStringList nameFilters;
        nameFilters << "*.jpg" << "*.JPG";
        saveDirectory.setNameFilters(nameFilters);
        QStringList imageList = saveDirectory.entryList();
        if(!imageList.isEmpty()) {
            _setErrorMessage(tr("Thư mục lưu đã có hình ảnh."));
            return;
        }
    }
    _errorMessage.clear();
    emit errorMessageChanged(_errorMessage);
}

void GeoTagController::startTagging()
{
    _errorMessage.clear();
    emit errorMessageChanged(_errorMessage);
    QDir imageDirectory = QDir(_worker.imageDirectory());
    if(!imageDirectory.exists()) {
        _setErrorMessage(tr("Không thể tìm thấy thư mục hình ảnh."));
        return;
    }
    if(_worker.saveDirectory() == "") {
        QDir oldTaggedFolder = QDir(_worker.imageDirectory() + kTagged);
        if(oldTaggedFolder.exists()) {
            oldTaggedFolder.removeRecursively();
            if(!imageDirectory.mkdir(_worker.imageDirectory() + kTagged)) {
                _setErrorMessage(tr("Không thể thay thế các hình ảnh đã được gắn thẻ trước đó"));
                return;
            }
        }
    } else {
        QDir saveDirectory = QDir(_worker.saveDirectory());
        if(!saveDirectory.exists()) {
            _setErrorMessage(tr("Không thể tìm thấy thư mục lưu."));
            return;
        }
    }
    _worker.start();
}

void GeoTagController::_workerProgressChanged(double progress)
{
    _progress = progress;
    emit progressChanged(progress);
}

void GeoTagController::_workerError(QString errorMessage)
{
    _errorMessage = errorMessage;
    emit errorMessageChanged(errorMessage);
}

void GeoTagController::_setErrorMessage(const QString& error)
{
    _errorMessage = error;
    emit errorMessageChanged(error);
}

GeoTagWorker::GeoTagWorker()
    : _cancel(false)
{

}

void GeoTagWorker::run()
{
    _cancel = false;
    emit progressChanged(1);
    double nSteps = 5;

    // Tải hình ảnh
    _imageList.clear();
    QDir imageDirectory = QDir(_imageDirectory);
    imageDirectory.setFilter(QDir::Files | QDir::Readable | QDir::NoSymLinks | QDir::Writable);
    imageDirectory.setSorting(QDir::Name);
    QStringList nameFilters;
    nameFilters << "*.jpg" << "*.JPG";
    imageDirectory.setNameFilters(nameFilters);
    _imageList = imageDirectory.entryInfoList();
    if(_imageList.isEmpty()) {
        emit error(tr("Thư mục hình ảnh không chứa hình ảnh, hãy đảm bảo các hình ảnh của bạn ở định dạng JPG"));
        return;
    }
    emit progressChanged((100/nSteps));

    // Phân tích EXIF
    ExifParser exifParser;
    _imageTime.clear();
    for (int i = 0; i < _imageList.size(); ++i) {
        QFile file(_imageList.at(i).absoluteFilePath());
        if (!file.open(QIODevice::ReadOnly)) {
            emit error(tr("Gắn thẻ địa lý thất bại. Không thể mở hình ảnh."));
            return;
        }
        QByteArray imageBuffer = file.readAll();
        file.close();

        _imageTime.append(exifParser.readTime(imageBuffer));

        emit progressChanged((100/nSteps) + ((100/nSteps) / _imageList.size())*i);

        if (_cancel) {
            qCDebug(GeotaggingLog) << "Gắn thẻ bị hủy";
            emit error(tr("Gắn thẻ bị hủy"));
            return;
        }
    }

    // Tải nhật ký
    bool isULog = _logFile.endsWith(".ulg", Qt::CaseSensitive);
    QFile file(_logFile);
    if (!file.open(QIODevice::ReadOnly)) {
        emit error(tr("Gắn thẻ địa lý thất bại. Không thể mở tệp nhật ký."));
        return;
    }
    QByteArray log = file.readAll();
    file.close();

    // Khởi tạo trình phân tích phù hợp
    _triggerList.clear();
    bool parseComplete = false;
    QString errorString;
    if (isULog) {
        ULogParser parser;
        parseComplete = parser.getTagsFromLog(log, _triggerList, errorString);

    } else {
        PX4LogParser parser;
        parseComplete = parser.getTagsFromLog(log, _triggerList);

    }

    if (!parseComplete) {
        if (_cancel) {
            qCDebug(GeotaggingLog) << "Gắn thẻ bị hủy";
            emit error(tr("Gắn thẻ bị hủy"));
            return;
        } else {
            qCDebug(GeotaggingLog) << "Phân tích nhật ký thất bại";
            errorString = tr("%1 - gắn thẻ bị hủy").arg(errorString.isEmpty() ? tr("Phân tích nhật ký thất bại") : errorString);
            emit error(errorString);
            return;
        }
    }
    emit progressChanged(3*(100/nSteps));

    qCDebug(GeotaggingLog) << "Tìm thấy " << _triggerList.count() << " nhật ký kích hoạt.";

    if (_cancel) {
        qCDebug(GeotaggingLog) << "Gắn thẻ bị hủy";
        emit error(tr("Gắn thẻ bị hủy"));
        return;
    }

    // Lọc kích hoạt
    if (!triggerFiltering()) {
        qCDebug(GeotaggingLog) << "Gắn thẻ địa lý thất bại trong quá trình lọc kích hoạt";
        emit error(tr("Gắn thẻ địa lý thất bại trong quá trình lọc kích hoạt"));
        return;
    }
    emit progressChanged(4*(100/nSteps));

    if (_cancel) {
        qCDebug(GeotaggingLog) << "Gắn thẻ bị hủy";
        emit error(tr("Gắn thẻ bị hủy"));
        return;
    }

    // Gắn thẻ hình ảnh
    int maxIndex = std::min(_imageIndices.count(), _triggerIndices.count());
    maxIndex = std::min(maxIndex, _imageList.count());
    for(int i = 0; i < maxIndex; i++) {
        int imageIndex = _imageIndices[i];
        if (imageIndex >= _imageList.count()) {
            emit error(tr("Gắn thẻ địa lý thất bại. Yêu cầu hình ảnh #%1, nhưng chỉ có %2 hình ảnh.").arg(imageIndex).arg(_imageList.count()));
            return;
        }
        QFile fileRead(_imageList.at(_imageIndices[i]).absoluteFilePath());
        if (!fileRead.open(QIODevice::ReadOnly)) {
            emit error(tr("Gắn thẻ địa lý thất bại. Không thể mở hình ảnh."));
            return;
        }
        QByteArray imageBuffer = fileRead.readAll();
        fileRead.close();

        if (!exifParser.write(imageBuffer, _triggerList[_triggerIndices[i]])) {
            emit error(tr("Gắn thẻ địa lý thất bại. Không thể ghi vào hình ảnh."));
            return;
        } else {
            QFile fileWrite;
            if(_saveDirectory == "") {
                fileWrite.setFileName(_imageDirectory + "/TAGGED/" + _imageList.at(_imageIndices[i]).fileName());
            } else {
                fileWrite.setFileName(_saveDirectory + "/" + _imageList.at(_imageIndices[i]).fileName());
            }
            if (!fileWrite.open(QFile::WriteOnly)) {
                emit error(tr("Gắn thẻ địa lý thất bại. Không thể ghi vào hình ảnh."));
                return;
            }
            fileWrite.write(imageBuffer);
            fileWrite.close();
        }
        emit progressChanged(4*(100/nSteps) + ((100/nSteps) / maxIndex)*i);

        if (_cancel) {
            qCDebug(GeotaggingLog) << "Gắn thẻ bị hủy";
            emit error(tr("Gắn thẻ bị hủy"));
            return;
        }
    }

    if (_cancel) {
        qCDebug(GeotaggingLog) << "Gắn thẻ bị hủy";
        emit error(tr("Gắn thẻ bị hủy"));
        return;
    }

    emit progressChanged(100);
}

bool GeoTagWorker::triggerFiltering()
{
    _imageIndices.clear();
    _triggerIndices.clear();
    if(_imageList.count() > _triggerList.count()) {             // Mất gói phản hồi
        qCDebug(GeotaggingLog) << "Phát hiện thiếu gói phản hồi.";
    } else if (_imageList.count() < _triggerList.count()) {     // Máy ảnh bỏ qua khung hình
        qCDebug(GeotaggingLog) << "Phát hiện thiếu khung hình hình ảnh.";
    }
    for(int i = 0; i < _imageList.count() && i < _triggerList.count(); i++) {
        _imageIndices.append(static_cast<int>(_triggerList[i].imageSequence));
        _triggerIndices.append(i);
    }
    return true;
}
