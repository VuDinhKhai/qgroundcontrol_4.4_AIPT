/****************************************************************************
 *
 * (c) 2009-2020 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "SHPFileHelper.h"
#include "QGCGeo.h"

#include <QFile>
#include <QVariant>
#include <QtDebug>
#include <QRegularExpression>

const char* SHPFileHelper::_errorPrefix = QT_TR_NOOP("SHP file load failed. %1");

/// Validates the specified SHP file is truly a SHP file and is in the format we understand.
///     @param utmZone[out] Zone for UTM shape, 0 for lat/lon shape
///     @param utmSouthernHemisphere[out] true/false for UTM hemisphere
/// @return true: Valid supported SHP file found, false: Invalid or unsupported file found
bool SHPFileHelper::_validateSHPFiles(const QString& shpFile, int* utmZone, bool* utmSouthernHemisphere, QString& errorString)
{
    *utmZone = 0;
    errorString.clear();

    if (shpFile.endsWith(QStringLiteral(".shp"))) {
        QString prjFilename = shpFile.left(shpFile.length() - 4) + QStringLiteral(".prj");
        QFile prjFile(prjFilename);
        if (prjFile.exists()) {
            if (prjFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QTextStream strm(&prjFile);
                QString line = strm.readLine();
                if (line.startsWith(QStringLiteral("GEOGCS[\"GCS_WGS_1984\","))) {
                    *utmZone = 0;
                    *utmSouthernHemisphere = false;
                } else if (line.startsWith(QStringLiteral("PROJCS[\"WGS_1984_UTM_Zone_"))) {
                    QRegularExpression regEx(QStringLiteral("^PROJCS\\[\"WGS_1984_UTM_Zone_(\\d+){1,2}([NS]{1})"));
                    QRegularExpressionMatch regExMatch = regEx.match(line);
                    QStringList rgCapture = regExMatch.capturedTexts();
                    if (rgCapture.count() == 3) {
                        int zone = rgCapture[1].toInt();
                        if (zone >= 1 && zone <= 60) {
                            *utmZone = zone;
                            *utmSouthernHemisphere = rgCapture[2] == QStringLiteral("S");
                        }
                    }
                    if (*utmZone == 0) {
                        errorString = QString(_errorPrefix).arg(tr("Phép chiếu UTM không có định dạng được hỗ trợ. Phải là PROJCS[\"WGS_1984_UTM_Zone_##N/S"));
                    }
                } else {
                    errorString = QString(_errorPrefix).arg(tr("Chỉ hỗ trợ phép chiếu WGS84 hoặc UTM."));
                }
            } else {
                errorString = QString(_errorPrefix).arg(tr("Không mở được tệp PRJ: %1").arg(prjFile.errorString()));
            }
        } else {
            errorString = QString(_errorPrefix).arg(tr("Không tìm thấy tập tin: %1").arg(prjFilename));
        }
    } else {
        errorString = QString(_errorPrefix).arg(tr("Tệp không phải là tệp .shp: %1").arg(shpFile));
    }

    return errorString.isEmpty();
}

/// @param utmZone[out] Zone for UTM shape, 0 for lat/lon shape
/// @param utmSouthernHemisphere[out] true/false for UTM hemisphere
SHPHandle SHPFileHelper::_loadShape(const QString& shpFile, int* utmZone, bool* utmSouthernHemisphere, QString& errorString)
{
    SHPHandle shpHandle = Q_NULLPTR;

    errorString.clear();

    if (_validateSHPFiles(shpFile, utmZone, utmSouthernHemisphere, errorString)) {
        if (!(shpHandle = SHPOpen(shpFile.toUtf8(), "rb"))) {
            errorString = QString(_errorPrefix).arg(tr("SHPOpen không thành công."));
        }
    }

    return shpHandle;
}

ShapeFileHelper::ShapeType SHPFileHelper::determineShapeType(const QString& shpFile, QString& errorString)
{
    ShapeFileHelper::ShapeType shapeType = ShapeFileHelper::Error;

    errorString.clear();

    int utmZone;
    bool utmSouthernHemisphere;
    SHPHandle shpHandle = SHPFileHelper::_loadShape(shpFile, &utmZone, &utmSouthernHemisphere, errorString);
    if (errorString.isEmpty()) {
        int cEntities, type;

        SHPGetInfo(shpHandle, &cEntities /* pnEntities */, &type, Q_NULLPTR /* padfMinBound */, Q_NULLPTR /* padfMaxBound */);
        qDebug() << "SHPGetInfo" << shpHandle << cEntities << type;
        if (cEntities != 1) {
            errorString = QString(_errorPrefix).arg(tr("Đã tìm thấy nhiều hơn một thực thể."));
        } else if (type == SHPT_POLYGON) {
            shapeType = ShapeFileHelper::Polygon;
        } else {
            errorString = QString(_errorPrefix).arg(tr("Không tìm thấy loại nào được hỗ trợ."));
        }
    }

    SHPClose(shpHandle);

    return shapeType;
}

bool SHPFileHelper::loadPolygonFromFile(const QString& shpFile, QList<QGeoCoordinate>& vertices, QString& errorString)
{
    int         utmZone = 0;
    bool        utmSouthernHemisphere;
    double      vertexFilterMeters = 5;
    SHPHandle   shpHandle = Q_NULLPTR;
    SHPObject*  shpObject = Q_NULLPTR;

    errorString.clear();
    vertices.clear();

    shpHandle = SHPFileHelper::_loadShape(shpFile, &utmZone, &utmSouthernHemisphere, errorString);
    if (!errorString.isEmpty()) {
        goto Error;
    }

    int cEntities, shapeType;
    SHPGetInfo(shpHandle, &cEntities, &shapeType, Q_NULLPTR /* padfMinBound */, Q_NULLPTR /* padfMaxBound */);
    if (shapeType != SHPT_POLYGON) {
        errorString = QString(_errorPrefix).arg(tr("Tệp không chứa đa giác."));
        goto Error;
    }

    shpObject = SHPReadObject(shpHandle, 0);
    if (shpObject->nParts != 1) {
        errorString = QString(_errorPrefix).arg(tr("Chỉ hỗ trợ đa giác một phần."));
        goto Error;
    }

    for (int i=0; i<shpObject->nVertices; i++) {
        QGeoCoordinate coord;
        if (!utmZone || !convertUTMToGeo(shpObject->padfX[i], shpObject->padfY[i], utmZone, utmSouthernHemisphere, coord)) {
            coord.setLatitude(shpObject->padfY[i]);
            coord.setLongitude(shpObject->padfX[i]);
        }
        vertices.append(coord);
    }

    // Filter last vertex such that it differs from first
    {
        QGeoCoordinate firstVertex = vertices[0];

        while (vertices.count() > 3 && vertices.last().distanceTo(firstVertex) < vertexFilterMeters) {
            vertices.removeLast();
        }
    }

    // Filter vertex distances to be larger than 1 meter apart
    {
        int i = 0;
        while (i < vertices.count() - 2) {
            if (vertices[i].distanceTo(vertices[i+1]) < vertexFilterMeters) {
                vertices.removeAt(i+1);
            } else {
                i++;
            }
        }
    }

Error:
    if (shpObject) {
        SHPDestroyObject(shpObject);
    }
    if (shpHandle) {
        SHPClose(shpHandle);
    }
    return errorString.isEmpty();
}
