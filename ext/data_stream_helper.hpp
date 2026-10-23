// QDataStream streams QString and QByteArray through free `operator<<` and
// `operator>>`, which bindgen doesn't wrap as methods.  See
// src/qt6/data_stream.cr.
#include <QtCore/QDataStream>

void qt6cr_data_stream_write_string(QDataStream *stream, const QString &string) {
  *stream << string;
}

QString qt6cr_data_stream_read_string(QDataStream *stream) {
  QString string;
  *stream >> string;
  return string;
}

void qt6cr_data_stream_write_bytes(QDataStream *stream, const QByteArray &bytes) {
  *stream << bytes;
}

QByteArray qt6cr_data_stream_read_bytes(QDataStream *stream) {
  QByteArray bytes;
  *stream >> bytes;
  return bytes;
}
