// The methods Qt adds to `QList<QString>` as `QStringList` live in the
// template specialization `QListSpecialMethods<QString>`, which bindgen doesn't
// see.  These functions forward to them; `src/qt6/string_list.cr` exposes them
// as methods of the `QList<QString>` wrapper.  Like Qt's own `self()`, the
// list is cast down: `QStringList` adds no data members.

static QStringList &qt6cr_as_string_list(QList<QString> &list) {
  return static_cast<QStringList &>(list);
}

static const QStringList &qt6cr_as_string_list(const QList<QString> &list) {
  return static_cast<const QStringList &>(list);
}

void qt6cr_string_list_sort(QList<QString> &list, Qt::CaseSensitivity cs) {
  qt6cr_as_string_list(list).sort(cs);
}

qsizetype qt6cr_string_list_removeDuplicates(QList<QString> &list) {
  return qt6cr_as_string_list(list).removeDuplicates();
}

QStringList qt6cr_string_list_filter(const QList<QString> &list, const QString &str, Qt::CaseSensitivity cs) {
  return qt6cr_as_string_list(list).filter(str, cs);
}

QStringList qt6cr_string_list_filter(const QList<QString> &list, const QRegularExpression &re) {
  return qt6cr_as_string_list(list).filter(re);
}

void qt6cr_string_list_replaceInStrings(QList<QString> &list, const QString &before, const QString &after, Qt::CaseSensitivity cs) {
  qt6cr_as_string_list(list).replaceInStrings(before, after, cs);
}

void qt6cr_string_list_replaceInStrings(QList<QString> &list, const QRegularExpression &re, const QString &after) {
  qt6cr_as_string_list(list).replaceInStrings(re, after);
}

bool qt6cr_string_list_contains(const QList<QString> &list, const QString &str, Qt::CaseSensitivity cs) {
  return qt6cr_as_string_list(list).contains(str, cs);
}

qsizetype qt6cr_string_list_indexOf(const QList<QString> &list, const QRegularExpression &re, qsizetype from) {
  return qt6cr_as_string_list(list).indexOf(re, from);
}

qsizetype qt6cr_string_list_lastIndexOf(const QList<QString> &list, const QRegularExpression &re, qsizetype from) {
  return qt6cr_as_string_list(list).lastIndexOf(re, from);
}
