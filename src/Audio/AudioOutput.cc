/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include <QApplication>
#include <QDebug>
#include <QRegularExpression>

#include "AudioOutput.h"
#include "QGCApplication.h"
#include "QGC.h"
#include "SettingsManager.h"

AudioOutput::AudioOutput(QGCApplication* app, QGCToolbox* toolbox)
    : QGCTool   (app, toolbox)
    , _tts      (nullptr)
{
    if (qgcApp()->runningUnitTests()) {
        // Các bài kiểm tra đơn vị trên đám mây không có khả năng đọc văn bản thành tiếng.
        // Nếu thử khởi động engine đọc văn bản, sẽ xuất hiện cảnh báo và ngăn sử dụng QT_FATAL_WARNINGS.
        return;
    }

    _tts = new QTextToSpeech(this);

    //-- Bắt buộc engine TTS sử dụng tiếng Anh vì tất cả các thông báo từ autopilot
    //   đều bằng tiếng Anh và không được bản địa hóa.
#ifdef Q_OS_LINUX
    _tts->setLocale(QLocale("en_US"));
#endif
    connect(_tts, &QTextToSpeech::stateChanged, this, &AudioOutput::_stateChanged);
}

void AudioOutput::say(const QString& inText)
{
    if (!_tts) {
        qDebug() << "Nói" << inText;
        return;
    }

    bool muted = qgcApp()->toolbox()->settingsManager()->appSettings()->audioMuted()->rawValue().toBool();
    muted |= qgcApp()->runningUnitTests();
    if (!muted && !qgcApp()->runningUnitTests()) {
        QString text = fixTextMessageForAudio(inText);
        if(_tts->state() == QTextToSpeech::Speaking) {
            if(!_texts.contains(text)) {
                //-- Một giới hạn tùy ý
                if(_texts.size() > 20) {
                    _texts.removeFirst();
                }
                _texts.append(text);
            }
        } else {
            _tts->say(text);
        }
    }
}

void AudioOutput::_stateChanged(QTextToSpeech::State state)
{
    if(state == QTextToSpeech::Ready) {
        if(_texts.size()) {
            QString text = _texts.first();
            _texts.removeFirst();
            _tts->say(text);
        }
    }
}

bool AudioOutput::getMillisecondString(const QString& string, QString& match, int& number) {
    static QRegularExpression re("([0-9]+ms)");
    QRegularExpressionMatchIterator i = re.globalMatch(string);
    while (i.hasNext()) {
        QRegularExpressionMatch qmatch = i.next();
        if (qmatch.hasMatch()) {
            match = qmatch.captured(0);
            number = qmatch.captured(0).replace("ms", "").toInt();
            return true;
        }
    }
    return false;
}

QString AudioOutput::fixTextMessageForAudio(const QString& string) {
    QString match;
    QString newNumber;
    QString result = string;

    //-- Tìm các thuật ngữ mã hóa
    if(result.contains("ERR ", Qt::CaseInsensitive)) {
        result.replace("ERR ", "lỗi ", Qt::CaseInsensitive);
    }
    if(result.contains("ERR:", Qt::CaseInsensitive)) {
        result.replace("ERR:", "lỗi.", Qt::CaseInsensitive);
    }
    if(result.contains("POSCTL", Qt::CaseInsensitive)) {
        result.replace("POSCTL", "Kiểm soát vị trí", Qt::CaseInsensitive);
    }
    if(result.contains("ALTCTL", Qt::CaseInsensitive)) {
        result.replace("ALTCTL", "Kiểm soát độ cao", Qt::CaseInsensitive);
    }
    if(result.contains("AUTO_RTL", Qt::CaseInsensitive)) {
        result.replace("AUTO_RTL", "tự động quay về điểm khởi hành", Qt::CaseInsensitive);
    } else if(result.contains("RTL", Qt::CaseInsensitive)) {
        result.replace("RTL", "quay về điểm khởi hành", Qt::CaseInsensitive);
    }
    if(result.contains("ACCEL ", Qt::CaseInsensitive)) {
        result.replace("ACCEL ", "gia tốc kế ", Qt::CaseInsensitive);
    }
    if(result.contains("RC_MAP_MODE_SW", Qt::CaseInsensitive)) {
        result.replace("RC_MAP_MODE_SW", "chuyển chế độ RC", Qt::CaseInsensitive);
    }
    if(result.contains("REJ.", Qt::CaseInsensitive)) {
        result.replace("REJ.", "bị từ chối", Qt::CaseInsensitive);
    }
    if(result.contains("WP", Qt::CaseInsensitive)) {
        result.replace("WP", "điểm đường", Qt::CaseInsensitive);
    }
    if(result.contains("CMD", Qt::CaseInsensitive)) {
        result.replace("CMD", "lệnh", Qt::CaseInsensitive);
    }
    if(result.contains("COMPID", Qt::CaseInsensitive)) {
        result.replace("COMPID", "ID thành phần", Qt::CaseInsensitive);
    }
    if(result.contains(" params ", Qt::CaseInsensitive)) {
        result.replace(" params ", " tham số ", Qt::CaseInsensitive);
    }
    if(result.contains(" id ", Qt::CaseInsensitive)) {
        result.replace(" id ", " ID ", Qt::CaseInsensitive);
    }
    if(result.contains(" ADSB ", Qt::CaseInsensitive)) {
        result.replace(" ADSB ", " ADSB ", Qt::CaseInsensitive);
    }
    if(result.contains(" EKF ", Qt::CaseInsensitive)) {
        result.replace(" EKF ", " EKF ", Qt::CaseInsensitive);
    }
    if(result.contains("PREARM", Qt::CaseInsensitive)) {
        result.replace("PREARM", "chuẩn bị", Qt::CaseInsensitive);
    }
    if(result.contains("PITOT", Qt::CaseInsensitive)) {
        result.replace("PITOT", "pitot", Qt::CaseInsensitive);
    }

    // Chuyển đổi số âm
    QRegularExpression re(QStringLiteral("(-)[0-9]*\\.?[0-9]"));
    QRegularExpressionMatch reMatch = re.match(result);
    while (reMatch.hasMatch()) {
        if (!reMatch.captured(1).isNull()) {
            result.replace(reMatch.capturedStart(1), reMatch.capturedEnd(1) - reMatch.capturedStart(1), tr(" âm "));
        }
        reMatch = re.match(result);
    }

    // Chuyển đổi số thực với dấu chấm thập phân
    re.setPattern(QStringLiteral("([0-9]+)(\\.)([0-9]+)"));
    reMatch = re.match(result);
    while (reMatch.hasMatch()) {
        if (!reMatch.captured(2).isNull()) {
            result.replace(reMatch.capturedStart(2), reMatch.capturedEnd(2) - reMatch.capturedStart(2), tr(" phẩy "));
        }
        reMatch = re.match(result);
    }

    // Chuyển đổi hậu tố mét
    re.setPattern(QStringLiteral("[0-9]*\\.?[0-9]\\s?(m)([^A-Za-z]|$)"));
    reMatch = re.match(result);
    while (reMatch.hasMatch()) {
        if (!reMatch.captured(1).isNull()) {
            result.replace(reMatch.capturedStart(1), reMatch.capturedEnd(1) - reMatch.capturedStart(1), tr(" mét"));
        }
        reMatch = re.match(result);
    }

    int number;
    if(getMillisecondString(string, match, number) && number > 1000) {
        if(number < 60000) {
            int seconds = number / 1000;
            newNumber = QString("%1 giây").arg(seconds);
        } else {
            int minutes = number / 60000;
            int seconds = (number - (minutes * 60000)) / 1000;
            if (!seconds) {
                newNumber = QString("%1 phút").arg(minutes);
            } else {
                newNumber = QString("%1 phút và %2 giây").arg(minutes).arg(seconds);
            }
        }
        result.replace(match, newNumber);
    }
    return result;
}