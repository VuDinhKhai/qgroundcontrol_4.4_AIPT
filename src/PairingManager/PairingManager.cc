/****************************************************************************
 *
 *   (c) 2019 DỰ ÁN QGROUNDCONTROL <http://www.qgroundcontrol.org>
 *
 * QGroundControl được cấp phép theo các điều khoản trong tệp
 * COPYING.md trong thư mục nguồn mã nguồn.
 *
 ****************************************************************************/

#include "PairingManager.h"
#include "SettingsManager.h"
#include "MicrohardManager.h"
#include "QGCApplication.h"
#include "QGCCorePlugin.h"

#include <QSettings>
#include <QJsonObject>
#include <QStandardPaths>
#include <QMutexLocker>

QGC_LOGGING_CATEGORY(PairingManagerLog, "PairingManagerLog")

static const char* jsonFileName = "pairing.json";

//-----------------------------------------------------------------------------
static QString
random_string(uint length)
{
    auto randchar = []() -> char
    {
        const char charset[] =
            "0123456789"
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            "abcdefghijklmnopqrstuvwxyz";
        const uint max_index = (sizeof(charset) - 1);
        return charset[static_cast<uint>(rand()) % max_index];
    };
    std::string str(length, 0);
    std::generate_n(str.begin(), length, randchar);
    return QString::fromStdString(str);
}

//-----------------------------------------------------------------------------
PairingManager::PairingManager(QGCApplication* app, QGCToolbox* toolbox)
    : QGCTool(app, toolbox)
    , _aes("J6+KuWh9K2!hG(F'", 0x368de30e8ec063ce)
{
    _jsonFileName = QDir::temp().filePath(jsonFileName);
    connect(this, &PairingManager::parsePairingJson, this, &PairingManager::_parsePairingJson);
    connect(this, &PairingManager::setPairingStatus, this, &PairingManager::_setPairingStatus);
    connect(this, &PairingManager::startUpload, this, &PairingManager::_startUpload);
}

//-----------------------------------------------------------------------------
PairingManager::~PairingManager()
{
}

//-----------------------------------------------------------------------------

void
PairingManager::setToolbox(QGCToolbox *toolbox)
{
    QGCTool::setToolbox(toolbox);
    _updatePairedDeviceNameList();
    emit pairedListChanged();
}

//-----------------------------------------------------------------------------
void
PairingManager::_pairingCompleted(QString name)
{
    _writeJson(_jsonDoc, _pairingCacheFile(name));
    _remotePairingMap["NM"] = name;
    _lastPaired = name;
    _updatePairedDeviceNameList();
    emit pairedListChanged();
    emit pairedVehicleChanged();
    //_app->informationMessageBoxOnMainThread("", tr("Paired with %1").arg(name));
    setPairingStatus(PairingSuccess, tr("Kết nối thành công với %1").arg(name));
}

//-----------------------------------------------------------------------------
void
PairingManager::_connectionCompleted(QString /*name*/)
{
    //QString pwd = _remotePairingMap["PWD"].toString();
    //_toolbox->microhardManager()->switchToConnectionEncryptionKey(pwd);
    //_app->informationMessageBoxOnMainThread("", tr("Connected to %1").arg(name));
    setPairingStatus(PairingConnected, tr("Kết nối thành công"));
}

//-----------------------------------------------------------------------------
void
PairingManager::_startUpload(QString pairURL, QJsonDocument jsonDoc)
{
    QMutexLocker lock(&_uploadMutex);
    if (_uploadManager != nullptr) {
        return;
    }
    _uploadManager = new QNetworkAccessManager(this);

    QString str = jsonDoc.toJson(QJsonDocument::JsonFormat::Compact);
    qCDebug(PairingManagerLog) << "Bắt đầu tải lên đến: " << pairURL << " " << str;
    _uploadData = QString::fromStdString(_aes.encrypt(str.toStdString()));
    _uploadURL = pairURL;
    _startUploadRequest();
}

//-----------------------------------------------------------------------------
void
PairingManager::_startUploadRequest()
{
    QNetworkRequest req;
    req.setUrl(QUrl(_uploadURL));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");
    QNetworkReply *reply = _uploadManager->post(req, _uploadData.toUtf8());
    connect(reply, &QNetworkReply::finished, this, &PairingManager::_uploadFinished);
}

//-----------------------------------------------------------------------------
void
PairingManager::_stopUpload()
{
    QMutexLocker lock(&_uploadMutex);
    if (_uploadManager != nullptr) {
        delete _uploadManager;
        _uploadManager = nullptr;
    }
}

//-----------------------------------------------------------------------------
void
PairingManager::_uploadFinished()
{
    QMutexLocker lock(&_uploadMutex);
    QNetworkReply* reply = qobject_cast<QNetworkReply*>(QObject::sender());
    if (reply) {
        if (_uploadManager != nullptr) {
            if (reply->error() == QNetworkReply::NoError) {
                qCDebug(PairingManagerLog) << "Tải lên hoàn tất.";
                QByteArray bytes = reply->readAll();
                QString str = QString::fromUtf8(bytes.data(), bytes.size());
                qCDebug(PairingManagerLog) << "Trả lời: " << str;
                auto a = str.split(QRegExp("\\s+"));
                if (a[0] == "Accepted" && a.length() > 1) {
                    _pairingCompleted(a[1]);
                } else if (a[0] == "Connected" && a.length() > 1) {
                    _connectionCompleted(a[1]);
                } else if (a[0] == "Connection" && a.length() > 1) {
                    setPairingStatus(PairingConnectionRejected, tr("Kết nối bị từ chối"));
                    qCDebug(PairingManagerLog) << "Lỗi kết nối: " << str;
                } else {
                    setPairingStatus(PairingRejected, tr("Kết nối bị từ chối"));
                    qCDebug(PairingManagerLog) << "Lỗi kết nối: " << str;
                }
                _uploadManager->deleteLater();
                _uploadManager = nullptr;
            } else {
                if(++_pairRetryCount > 3) {
                    qCDebug(PairingManagerLog) << "Từ chối";
                    setPairingStatus(PairingError, tr("Không có phản hồi từ phương tiện"));
                    _uploadManager->deleteLater();
                    _uploadManager = nullptr;
                } else {
                    qCDebug(PairingManagerLog) << "Lỗi tải lên: " + reply->errorString();
                    _startUploadRequest();
                }
            }
        }
    }
}

//-----------------------------------------------------------------------------
void
PairingManager::_parsePairingJsonFile()
{
    QFile file(_jsonFileName);
    file.open(QIODevice::ReadOnly | QIODevice::Text);
    QString json = file.readAll();
    file.remove();
    file.close();

    jsonReceived(json);
}

//-----------------------------------------------------------------------------
void
PairingManager::connectToPairedDevice(QString name)
{
    setPairingStatus(PairingConnecting, tr("Đang kết nối đến %1").arg(name));
    QFile file(_pairingCacheFile(name));
    file.open(QIODevice::ReadOnly | QIODevice::Text);
    QString json = file.readAll();
    jsonReceived(json);
}

//-----------------------------------------------------------------------------
void
PairingManager::removePairedDevice(QString name)
{
    QFile file(_pairingCacheFile(name));
    file.remove();
    _updatePairedDeviceNameList();
    emit pairedListChanged();
}

//-----------------------------------------------------------------------------
void
PairingManager::_updatePairedDeviceNameList()
{
    _deviceList.clear();
    QDirIterator it(_pairingCacheDir().absolutePath(), QDir::Files);
    while (it.hasNext()) {
        QFileInfo fileInfo(it.next());
        _deviceList.append(fileInfo.fileName());
        qCDebug(PairingManagerLog) << "Danh sách: " << fileInfo.fileName();
    }
}

//-----------------------------------------------------------------------------
QString
PairingManager::_assumeMicrohardPairingJson()
{
    QJsonDocument json;
    QJsonObject   jsonObject;

    jsonObject.insert("LT", "MH");
    jsonObject.insert("IP", "192.168.168.10");
    jsonObject.insert("AIP", _toolbox->microhardManager()->remoteIPAddr());
    jsonObject.insert("CU",  _toolbox->microhardManager()->configUserName());
    jsonObject.insert("CP",  _toolbox->microhardManager()->configPassword());
    jsonObject.insert("EK",  _toolbox->microhardManager()->encryptionKey());
    json.setObject(jsonObject);

    return QString(json.toJson(QJsonDocument::Compact));
}

//-----------------------------------------------------------------------------
void
PairingManager::_parsePairingJson(QString jsonEnc)
{
    QString json = QString::fromStdString(_aes.decrypt(jsonEnc.toStdString()));
    if (json == "") {
        json = jsonEnc;
    }
    qCDebug(PairingManagerLog) << "Phân tích JSON: " << json;

    _jsonDoc = QJsonDocument::fromJson(json.toUtf8());

    if (_jsonDoc.isNull()) {
        setPairingStatus(PairingError, tr("Tệp kết nối không hợp lệ"));
        qCDebug(PairingManagerLog) << "Không thể tạo tài liệu JSON kết nối.";
        return;
    }
    if (!_jsonDoc.isObject()) {
        setPairingStatus(PairingError, tr("Lỗi phân tích tệp kết nối"));
        qCDebug(PairingManagerLog) << "Tài liệu JSON kết nối không phải là một đối tượng.";
        return;
    }

    QJsonObject jsonObj = _jsonDoc.object();

    if (jsonObj.isEmpty()) {
        setPairingStatus(PairingError, tr("Lỗi phân tích tệp kết nối"));
        qCDebug(PairingManagerLog) << "Đối tượng JSON kết nối trống.";
        return;
    }

    _remotePairingMap = jsonObj.toVariantMap();
    QString linkType  = _remotePairingMap["LT"].toString();
    QString pport     = _remotePairingMap["PP"].toString();
    if (pport.length()==0) {
        pport = "29351";
    }

    if (linkType.length()==0) {
        setPairingStatus(PairingError, tr("Lỗi phân tích tệp kết nối"));
        qCDebug(PairingManagerLog) << "Tài liệu JSON kết nối bị lỗi.";
        return;
    }

    _toolbox->microhardManager()->switchToPairingEncryptionKey();

    QString pairURL = "http://" + _remotePairingMap["IP"].toString() + ":" + pport;
    bool connecting = jsonObj.contains("PWD");
    QJsonDocument jsonDoc;

    if (!connecting) {
        pairURL +=  + "/pair";
        QString pwd = random_string(8);
        // TODO generate certificates
        QString cert1 = "";
        QString cert2 = "";
        jsonObj.insert("PWD", pwd);
        jsonObj.insert("CERT1", cert1);
        jsonObj.insert("CERT2", cert2);
        _jsonDoc.setObject(jsonObj);
        if (linkType == "ZT") {
            jsonDoc = _createZeroTierPairingJson(cert1);
        } else if (linkType == "MH") {
            jsonDoc = _createMicrohardPairingJson(pwd, cert1);
        }
    } else {
        pairURL +=  + "/connect";
        QString cert2 = _remotePairingMap["CERT2"].toString();
        if (linkType == "ZT") {
            jsonDoc = _createZeroTierConnectJson(cert2);
        } else if (linkType == "MH") {
            jsonDoc = _createMicrohardConnectJson(cert2);
        }
    }

    if (linkType == "ZT") {
        _toolbox->settingsManager()->appSettings()->enableMicrohard()->setRawValue(false);
        _toolbox->settingsManager()->appSettings()->enableTaisync()->setRawValue(false);
        emit startUpload(pairURL, jsonDoc);
    } else if (linkType == "MH") {
        _toolbox->settingsManager()->appSettings()->enableMicrohard()->setRawValue(true);
        _toolbox->settingsManager()->appSettings()->enableTaisync()->setRawValue(false);
        if (_remotePairingMap.contains("AIP")) {
            _toolbox->microhardManager()->setRemoteIPAddr(_remotePairingMap["AIP"].toString());
        }
        if (_remotePairingMap.contains("CU")) {
            _toolbox->microhardManager()->setConfigUserName(_remotePairingMap["CU"].toString());
        }
        if (_remotePairingMap.contains("CP")) {
            _toolbox->microhardManager()->setConfigPassword(_remotePairingMap["CP"].toString());
        }
        if (_remotePairingMap.contains("EK") && !connecting) {
            _toolbox->microhardManager()->setEncryptionKey(_remotePairingMap["EK"].toString());
        }
        _toolbox->microhardManager()->updateSettings();
        emit startUpload(pairURL, jsonDoc);
    }
}

//-----------------------------------------------------------------------------
QString
PairingManager::_getLocalIPInNetwork(QString remoteIP, int num)
{
    QStringList pieces = remoteIP.split(".");
    QString ipPrefix = "";
    for (int i = 0; i<num && i<pieces.length(); i++) {
        ipPrefix += pieces[i] + ".";
    }

    const QHostAddress &localhost = QHostAddress(QHostAddress::LocalHost);
    for (const QHostAddress &address: QNetworkInterface::allAddresses()) {
        if (address.protocol() == QAbstractSocket::IPv4Protocol && address != localhost) {
            if (address.toString().startsWith(ipPrefix)) {
                return address.toString();
            }
        }
    }

    return "";
}

//-----------------------------------------------------------------------------
QDir
PairingManager::_pairingCacheDir()
{
    const QString spath(QFileInfo(QSettings().fileName()).dir().absolutePath());
    QDir dir = spath + QDir::separator() + "PairingCache";
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    return dir;
}

//-----------------------------------------------------------------------------
QString
PairingManager::_pairingCacheFile(QString uavName)
{
    return _pairingCacheDir().filePath(uavName);
}

//-----------------------------------------------------------------------------
void
PairingManager::_writeJson(QJsonDocument &jsonDoc, QString fileName)
{
    QString val = jsonDoc.toJson(QJsonDocument::JsonFormat::Compact);
    qCDebug(PairingManagerLog) << "Ghi json " << val;
    QString enc = QString::fromStdString(_aes.encrypt(val.toStdString()));

    QFile file(fileName);
    file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate);
    file.write(enc.toUtf8());
    file.close();
}

//-----------------------------------------------------------------------------
QJsonDocument
PairingManager::_createZeroTierPairingJson(QString cert1)
{
    QString localIP = _getLocalIPInNetwork(_remotePairingMap["IP"].toString(), 2);

    QJsonObject jsonObj;
    jsonObj.insert("LT", "ZT");
    jsonObj.insert("IP", localIP);
    jsonObj.insert("P", 14550);
    jsonObj.insert("CERT1", cert1);
    return QJsonDocument(jsonObj);
}

//-----------------------------------------------------------------------------
QJsonDocument
PairingManager::_createMicrohardPairingJson(QString pwd, QString cert1)
{
    QString localIP = _getLocalIPInNetwork(_remotePairingMap["IP"].toString(), 3);

    QJsonObject jsonObj;
    jsonObj.insert("LT", "MH");
    jsonObj.insert("IP", localIP);
    jsonObj.insert("P", 14550);
    jsonObj.insert("PWD", pwd);
    jsonObj.insert("CERT1", cert1);
    return QJsonDocument(jsonObj);
}

//-----------------------------------------------------------------------------
QJsonDocument
PairingManager::_createZeroTierConnectJson(QString cert2)
{
    QString localIP = _getLocalIPInNetwork(_remotePairingMap["IP"].toString(), 2);

    QJsonObject jsonObj;
    jsonObj.insert("LT", "ZT");
    jsonObj.insert("IP", localIP);
    jsonObj.insert("P", 14550);
    jsonObj.insert("CERT2", cert2);
    return QJsonDocument(jsonObj);
}

//-----------------------------------------------------------------------------
QJsonDocument
PairingManager::_createMicrohardConnectJson(QString cert2)
{
    QString localIP = _getLocalIPInNetwork(_remotePairingMap["IP"].toString(), 3);

    QJsonObject jsonObj;
    jsonObj.insert("LT", "MH");
    jsonObj.insert("IP", localIP);
    jsonObj.insert("P", 14550);
    jsonObj.insert("CERT2", cert2);
    return QJsonDocument(jsonObj);
}

//-----------------------------------------------------------------------------

QStringList
PairingManager::pairingLinkTypeStrings()
{
    //-- Phải theo cùng một thứ tự như enum LinkType trong LinkConfiguration.h
    static QStringList list;
    int i = 0;
    if (!list.size()) {
#if defined QGC_ENABLE_QTNFC
        list += tr("NFC");
        _nfcIndex = i++;
#endif
#if defined QGC_GST_MICROHARD_ENABLED
        list += tr("Microhard");
        _microhardIndex = i++;
#endif
    }
    return list;
}

//-----------------------------------------------------------------------------
void
PairingManager::_setPairingStatus(PairingStatus status, QString statusStr)
{
    _status = status;
    _statusString = statusStr;
    emit pairingStatusChanged();
}

//-----------------------------------------------------------------------------
QString
PairingManager::pairingStatusStr() const
{
    return _statusString;
}

#if QGC_GST_MICROHARD_ENABLED
//-----------------------------------------------------------------------------
void
PairingManager::startMicrohardPairing()
{
    stopPairing();
    _pairRetryCount = 0;
    setPairingStatus(PairingActive, tr("Kết nối..."));
    _parsePairingJson(_assumeMicrohardPairingJson());
}
#endif

//-----------------------------------------------------------------------------
void
PairingManager::stopPairing()
{
#if defined QGC_ENABLE_QTNFC
    pairingNFC.stop();
#endif
    _stopUpload();
    setPairingStatus(PairingIdle, "");
}

#if defined QGC_ENABLE_QTNFC
//-----------------------------------------------------------------------------
void
PairingManager::startNFCScan()
{
    stopPairing();
    setPairingStatus(PairingActive, tr("Kết nối..."));
    pairingNFC.start();
}

#endif

//-----------------------------------------------------------------------------
#ifdef __android__
static const char kJniClassName[] {"org/mavlink/qgroundcontrol/QGCActivity"};

//-----------------------------------------------------------------------------
static void jniNFCTagReceived(JNIEnv *envA, jobject thizA, jstring messageA)
{
    Q_UNUSED(thizA);

    const char *stringL = envA->GetStringUTFChars(messageA, nullptr);
    QString ndef = QString::fromUtf8(stringL);
    envA->ReleaseStringUTFChars(messageA, stringL);
    if (envA->ExceptionCheck())
        envA->ExceptionClear();
    qCDebug(PairingManagerLog) << "NDEF Tag Received: " << ndef;
    qgcApp()->toolbox()->pairingManager()->jsonReceived(ndef);
}

//-----------------------------------------------------------------------------
void PairingManager::setNativeMethods(void)
{
    //  REGISTER THE C++ FUNCTION WITH JNI
    JNINativeMethod javaMethods[] {
        {"nativeNFCTagReceived", "(Ljava/lang/String;)V", reinterpret_cast<void *>(jniNFCTagReceived)}
    };

    QAndroidJniEnvironment jniEnv;
    if (jniEnv->ExceptionCheck()) {
        jniEnv->ExceptionDescribe();
        jniEnv->ExceptionClear();
    }

    jclass objectClass = jniEnv->FindClass(kJniClassName);
    if(!objectClass) {
        qWarning() << "Couldn't find class:" << kJniClassName;
        return;
    }

    jint val = jniEnv->RegisterNatives(objectClass, javaMethods, sizeof(javaMethods) / sizeof(javaMethods[0]));

    if (val < 0) {
        qWarning() << "Error registering methods: " << val;
    } else {
        qCDebug(PairingManagerLog) << "Native Functions Registered";
    }

    if (jniEnv->ExceptionCheck()) {
        jniEnv->ExceptionDescribe();
        jniEnv->ExceptionClear();
    }
}
#endif
//-----------------------------------------------------------------------------
