#ifdef Q_OS_UNIX
#include <clocale>
#endif

void qt6cr_reset_numeric_locale() {
#ifdef Q_OS_UNIX
  std::setlocale(LC_NUMERIC, "C");
#endif
}
