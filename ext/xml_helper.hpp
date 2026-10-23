// The QXmlStream classes return their names, values and text as QStringView,
// which the binding doesn't map (the Crystal String maps to QString; a
// QStringView argument of a temporary would dangle in QRegularExpression),
// so these return them as QString.  See src/qt6/xml_stream.cr.
#include <QtCore/QXmlStreamReader>
#include <QtCore/QXmlStreamWriter>

#define QT6CR_XML_STRING(klass, prefix, method) \
  QString qt6cr_xml_##prefix##_##method(const klass *object) { return object->method().toString(); }

QT6CR_XML_STRING(QXmlStreamReader, reader, documentVersion)
QT6CR_XML_STRING(QXmlStreamReader, reader, documentEncoding)
QT6CR_XML_STRING(QXmlStreamReader, reader, name)
QT6CR_XML_STRING(QXmlStreamReader, reader, namespaceUri)
QT6CR_XML_STRING(QXmlStreamReader, reader, qualifiedName)
QT6CR_XML_STRING(QXmlStreamReader, reader, prefix)
QT6CR_XML_STRING(QXmlStreamReader, reader, processingInstructionTarget)
QT6CR_XML_STRING(QXmlStreamReader, reader, processingInstructionData)
QT6CR_XML_STRING(QXmlStreamReader, reader, text)
QT6CR_XML_STRING(QXmlStreamReader, reader, dtdName)
QT6CR_XML_STRING(QXmlStreamReader, reader, dtdPublicId)
QT6CR_XML_STRING(QXmlStreamReader, reader, dtdSystemId)
QT6CR_XML_STRING(QXmlStreamAttribute, attribute, namespaceUri)
QT6CR_XML_STRING(QXmlStreamAttribute, attribute, name)
QT6CR_XML_STRING(QXmlStreamAttribute, attribute, qualifiedName)
QT6CR_XML_STRING(QXmlStreamAttribute, attribute, prefix)
QT6CR_XML_STRING(QXmlStreamAttribute, attribute, value)
QT6CR_XML_STRING(QXmlStreamNamespaceDeclaration, namespace_declaration, prefix)
QT6CR_XML_STRING(QXmlStreamNamespaceDeclaration, namespace_declaration, namespaceUri)
QT6CR_XML_STRING(QXmlStreamNotationDeclaration, notation_declaration, name)
QT6CR_XML_STRING(QXmlStreamNotationDeclaration, notation_declaration, systemId)
QT6CR_XML_STRING(QXmlStreamNotationDeclaration, notation_declaration, publicId)
QT6CR_XML_STRING(QXmlStreamEntityDeclaration, entity_declaration, name)
QT6CR_XML_STRING(QXmlStreamEntityDeclaration, entity_declaration, notationName)
QT6CR_XML_STRING(QXmlStreamEntityDeclaration, entity_declaration, systemId)
QT6CR_XML_STRING(QXmlStreamEntityDeclaration, entity_declaration, publicId)
QT6CR_XML_STRING(QXmlStreamEntityDeclaration, entity_declaration, value)

#undef QT6CR_XML_STRING

QString qt6cr_xml_attributes_value(const QXmlStreamAttributes *attributes, const QString &qualifiedName) {
  return attributes->value(qualifiedName).toString();
}

QString qt6cr_xml_attributes_value(const QXmlStreamAttributes *attributes, const QString &namespaceUri, const QString &name) {
  return attributes->value(namespaceUri, name).toString();
}
