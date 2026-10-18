// QMatrix4x4 declares `operator*(QVector3D, QMatrix4x4)` and its mirror as
// friends unconditionally, but Qt deprecated their definitions in 6.1, so
// QT_DISABLE_DEPRECATED_BEFORE (see the Makefile) hides them: declared, never
// defined.  bindgen only ignores methods by name, which would drop every
// `operator*` of both classes, so the binding defines them as Qt did.
#include <QtGui/QMatrix4x4>
#include <QtGui/QTransform>
#include <QtGui/QVector3D>

inline QVector3D operator*(const QMatrix4x4 &matrix, const QVector3D &vector) {
  return matrix.map(vector);
}

inline QVector3D operator*(const QVector3D &vector, const QMatrix4x4 &matrix) {
  QVector4D v = QVector4D(vector, 1.0f) * matrix;
  return v.w() == 1.0f ? v.toVector3D() : v.toVector3DAffine();
}

// bindgen renders the `bool *invertible = nullptr` default of
// QTransform::inverted and QMatrix4x4::inverted as `Bool*? = true`, which
// Crystal rejects on a call using the default, so these are called instead.
// See `Qt::Transform#inverted` in src/qt6/transform.cr.
QTransform qt6cr_transform_inverted(const QTransform &transform, bool *invertible) {
  return transform.inverted(invertible);
}

QMatrix4x4 qt6cr_matrix4x4_inverted(const QMatrix4x4 &matrix, bool *invertible) {
  return matrix.inverted(invertible);
}
