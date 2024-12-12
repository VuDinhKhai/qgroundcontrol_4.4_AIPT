#include "ExifParser.h"
#include <math.h>
#include <QtEndian>
#include <QDateTime>

ExifParser::ExifParser()
{

}

ExifParser::~ExifParser()
{

}

double ExifParser::readTime(QByteArray& buf)
{
    QByteArray tiffHeader("\x49\x49\x2A", 3);
    QByteArray createDateHeader("\x04\x90\x02", 3);

    // tìm vị trí tiêu đề
    uint32_t tiffHeaderIndex = buf.indexOf(tiffHeader);

    // tìm vị trí tiêu đề ngày tạo
    uint32_t createDateHeaderIndex = buf.indexOf(createDateHeader);

    // trích xuất kích thước chuỗi ngày-giờ, -1 do có null-termination
    uint32_t* sizeString = reinterpret_cast<uint32_t*>(buf.mid(createDateHeaderIndex + 4, 4).data());
    uint32_t createDateStringSize = qFromLittleEndian(*sizeString) - 1;

    // trích xuất vị trí của chuỗi ngày-giờ
    uint32_t* dataIndex = reinterpret_cast<uint32_t*>(buf.mid(createDateHeaderIndex + 8, 4).data());
    uint32_t createDateStringDataIndex = qFromLittleEndian(*dataIndex) + tiffHeaderIndex;

    // đọc dữ liệu của trường ngày-giờ tạo
    QString createDate = buf.mid(createDateStringDataIndex, createDateStringSize);

    QStringList createDateList = createDate.split(' ');
    if (createDateList.count() < 2) {
        qWarning() << "Không thể giải mã thời gian và ngày tạo: " << createDateList;
        return -1.0;
    }
    QStringList dateList = createDateList[0].split(':');
    if (dateList.count() < 3) {
        qWarning() << "Không thể giải mã ngày tạo: " << dateList;
        return -1.0;
    }
    QStringList timeList = createDateList[1].split(':');
    if (timeList.count() < 3) {
        qWarning() << "Không thể giải mã thời gian tạo: " << timeList;
        return -1.0;
    }
    QDate date(dateList[0].toInt(), dateList[1].toInt(), dateList[2].toInt());
    QTime time(timeList[0].toInt(), timeList[1].toInt(), timeList[2].toInt());
    QDateTime tagTime(date, time);
    return tagTime.toMSecsSinceEpoch()/1000.0;
}

bool ExifParser::write(QByteArray& buf, GeoTagWorker::cameraFeedbackPacket& geotag)
{
    QByteArray app1Header("\xff\xe1", 2);
    uint32_t app1HeaderInd = buf.indexOf(app1Header);
    uint16_t *conversionPointer = reinterpret_cast<uint16_t *>(buf.mid(app1HeaderInd + 2, 2).data());
    uint16_t app1Size = *conversionPointer;
    uint16_t app1SizeEndian = qFromBigEndian(app1Size) + 0xa5;  // thay đổi endian sai
    QByteArray tiffHeader("\x49\x49\x2A", 3);
    uint32_t tiffHeaderInd = buf.indexOf(tiffHeader);
    conversionPointer = reinterpret_cast<uint16_t *>(buf.mid(tiffHeaderInd + 8, 2).data());
    uint16_t numberOfTiffFields  = *conversionPointer;
    uint32_t nextIfdOffsetInd = tiffHeaderInd + 10 + 12 * (numberOfTiffFields);
    conversionPointer = reinterpret_cast<uint16_t *>(buf.mid(nextIfdOffsetInd, 2).data());
    uint16_t nextIfdOffset = *conversionPointer;

    // Định nghĩa các union và struct hữu ích
    union char2uint32_u {
        char c[4];
        uint32_t i;
    };
    union char2uint16_u {
        char c[2];
        uint16_t i;
    };
    // Cấu trúc này mô tả một trường chuẩn trong exif
    struct field_s {
        uint16_t tagID;    // Mô tả loại thông tin, ví dụ GPS Lat
        uint16_t type;     // Mô tả kiểu dữ liệu, ví dụ string, uint8_t,...
        uint32_t size;     // Mô tả kích thước
        uint32_t content;  // Chứa thông tin hoặc offset đến tiêu đề exif nơi chứa thông tin (nếu 32 bit không đủ)
    };
    // Cấu trúc này chứa tất cả các trường mà chúng ta muốn thêm vào ảnh
    struct fields_s {
        field_s gpsVersion;
        field_s gpsLatRef;
        field_s gpsLat;
        field_s gpsLonRef;
        field_s gpsLon;
        field_s gpsAltRef;
        field_s gpsAlt;
        field_s gpsMapDatum;
        uint32_t finishedDataField;
    };
    // Cấu trúc này chứa các thông tin mở rộng không thể đặt vừa vào một uint32_t
    struct extended_s {
        uint32_t gpsLat[6];
        uint32_t gpsLon[6];
        uint32_t gpsAlt[2];
        char mapDatum[7];// = {0x57,0x47,0x53,0x2D,0x38,0x34,0x00};
    };
    // Cấu trúc này chứa tất cả thông tin chúng ta muốn thêm vào ảnh
    struct readable_s {
        fields_s fields;
        extended_s extendedData;
    };

    // Union này được sử dụng vì khi ghi thông tin cần dùng char array,
    // nhưng chúng ta vẫn muốn thông tin có sẵn theo cách dễ hiểu hơn
    union {
        char c[0xa3];
        readable_s readable;
    } gpsData;


    char2uint32_u gpsIFDInd;
    gpsIFDInd.i = nextIfdOffset;

    // phần này giữ nguyên
    QByteArray gpsInfo("\x25\x88\x04\x00\x01\x00\x00\x00", 8);
    gpsInfo.append(gpsIFDInd.c[0]);
    gpsInfo.append(gpsIFDInd.c[1]);
    gpsInfo.append(gpsIFDInd.c[2]);
    gpsInfo.append(gpsIFDInd.c[3]);

    // điền các giá trị vào gpsData
    uint32_t gpsDataExtInd = gpsIFDInd.i + 2 + sizeof(fields_s);

    // Điền các trường với giá trị tương ứng
    gpsData.readable.fields.gpsVersion.tagID = 0;
    gpsData.readable.fields.gpsVersion.type = 1;
    gpsData.readable.fields.gpsVersion.size = 4;
    gpsData.readable.fields.gpsVersion.content = 2;

    gpsData.readable.fields.gpsLatRef.tagID = 1;
    gpsData.readable.fields.gpsLatRef.type = 2;
    gpsData.readable.fields.gpsLatRef.size = 2;
    gpsData.readable.fields.gpsLatRef.content = geotag.latitude > 0 ? 'N' : 'S';

    gpsData.readable.fields.gpsLat.tagID = 2;
    gpsData.readable.fields.gpsLat.type = 5;
    gpsData.readable.fields.gpsLat.size = 3;
    gpsData.readable.fields.gpsLat.content = gpsDataExtInd;

    gpsData.readable.fields.gpsLonRef.tagID = 3;
    gpsData.readable.fields.gpsLonRef.type = 2;
    gpsData.readable.fields.gpsLonRef.size = 2;
    gpsData.readable.fields.gpsLonRef.content = geotag.longitude > 0 ? 'E' : 'W';

    gpsData.readable.fields.gpsLon.tagID = 4;
    gpsData.readable.fields.gpsLon.type = 5;
    gpsData.readable.fields.gpsLon.size = 3;
    gpsData.readable.fields.gpsLon.content = gpsDataExtInd + 6 * 4;

    gpsData.readable.fields.gpsAltRef.tagID = 5;
    gpsData.readable.fields.gpsAltRef.type = 1;
    gpsData.readable.fields.gpsAltRef.size = 1;
    gpsData.readable.fields.gpsAltRef.content = 0x00;

    gpsData.readable.fields.gpsAlt.tagID = 6;
    gpsData.readable.fields.gpsAlt.type = 5;
    gpsData.readable.fields.gpsAlt.size = 1;
    gpsData.readable.fields.gpsAlt.content = gpsDataExtInd + 6 * 4 * 2;

    gpsData.readable.fields.gpsMapDatum.tagID = 18;
    gpsData.readable.fields.gpsMapDatum.type = 2;
    gpsData.readable.fields.gpsMapDatum.size = 7;
    gpsData.readable.fields.gpsMapDatum.content = gpsDataExtInd + 6 * 4 * 2 + 2 * 4;

    gpsData.readable.fields.finishedDataField = 0;

    // Điền thông tin mở rộng không vừa trong trường
    gpsData.readable.extendedData.gpsLat[0] = abs(static_cast<int>(geotag.latitude));
    gpsData.readable.extendedData.gpsLat[1] = 1;
    gpsData.readable.extendedData.gpsLat[2] = static_cast<int>((fabs(geotag.latitude) - floor(fabs(geotag.latitude))) * 60.0);
    gpsData.readable.extendedData.gpsLat[3] = 1;
    gpsData.readable.extendedData.gpsLat[4] = static_cast<int>((fabs(geotag.latitude) * 60.0 - floor(fabs(geotag.latitude) * 60.0)) * 60000.0);
    gpsData.readable.extendedData.gpsLat[5] = 1000;

    gpsData.readable.extendedData.gpsLon[0] = abs(static_cast<int>(geotag.longitude));
    gpsData.readable.extendedData.gpsLon[1] = 1;
    gpsData.readable.extendedData.gpsLon[2] = static_cast<int>((fabs(geotag.longitude) - floor(fabs(geotag.longitude))) * 60.0);
    gpsData.readable.extendedData.gpsLon[3] = 1;
    gpsData.readable.extendedData.gpsLon[4] = static_cast<int>((fabs(geotag.longitude) * 60.0 - floor(fabs(geotag.longitude) * 60.0)) * 60000.0);
    gpsData.readable.extendedData.gpsLon[5] = 1000;

    gpsData.readable.extendedData.gpsAlt[0] = geotag.altitude * 100;
    gpsData.readable.extendedData.gpsAlt[1] = 100;
    gpsData.readable.extendedData.mapDatum[0] = 'W';
    gpsData.readable.extendedData.mapDatum[1] = 'G';
    gpsData.readable.extendedData.mapDatum[2] = 'S';
    gpsData.readable.extendedData.mapDatum[3] = '-';
    gpsData.readable.extendedData.mapDatum[4] = '8';
    gpsData.readable.extendedData.mapDatum[5] = '4';
    gpsData.readable.extendedData.mapDatum[6] = 0x00;

    // xóa 12 khoảng trắng từ mô tả ảnh, nếu không sẽ phải lặp qua mọi trường và chỉnh lại địa chỉ mới
    buf.remove(nextIfdOffsetInd + 4, 12);
    // TODO: chỉnh kích thước trong mô tả ảnh
    // chèn Thông tin GPS vào file ảnh
    buf.insert(nextIfdOffsetInd, gpsInfo, 12);
    char numberOfFields[2] = {0x08, 0x00};
    // chèn số trường GPS cụ thể mà chúng ta muốn thêm
    buf.insert(gpsIFDInd.i + tiffHeaderInd, numberOfFields, 2);
    // chèn dữ liệu GPS
    buf.insert(gpsIFDInd.i + 2 + tiffHeaderInd, gpsData.c, 0xa3);

    // cập nhật kích thước tệp và offsets exif mới
    char2uint16_u converter;
    converter.i = qToBigEndian(app1SizeEndian);
    buf.replace(app1HeaderInd + 2, 2, converter.c, 2);
    converter.i = nextIfdOffset + 12 + 0xa5;
    buf.replace(nextIfdOffsetInd + 12, 2, converter.c, 2);

    converter.i = (numberOfTiffFields) + 1;
    buf.replace(tiffHeaderInd + 8, 2, converter.c, 2);
    return true;
}