require "spec"
require "../src/qt6"

# Widgets need an application.  The offscreen platform needs no display.
ENV["QT_QPA_PLATFORM"] ||= "offscreen"
spec_app = Qt::Application.new
