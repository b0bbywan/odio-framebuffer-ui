cmake_minimum_required(VERSION 3.16)
project(FBrowser LANGUAGES CXX)

file(GLOB source_files *.c *.cpp *.qrc)

set(CMAKE_INCLUDE_CURRENT_DIR ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)


set(FULLBROWSER OFF CACHE BOOL "Full Featured Browser Support")
set(USE_QT6 OFF CACHE BOOL "Build against Qt 6 instead of Qt 5")
configure_file(config.h.in config.h)

# The full browser carries the Qt 5 simplebrowser example, whose download,
# certificate error and default-settings APIs were all reworked in Qt 6. Only
# the default browser is ported, so refuse the combination outright rather than
# fail halfway through the build.
if (USE_QT6 AND FULLBROWSER)
  message(FATAL_ERROR "USE_QT6 and FULLBROWSER are exclusive for now: build the full browser with Qt 5.")
endif()

if (USE_QT6)
  find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Network WebEngineWidgets)
else()
  find_package(Qt5 REQUIRED COMPONENTS Core Gui Widgets Network WebEngineWidgets)
endif()
add_definitions (-DQT_DISABLE_DEPRECATED_BEFORE=0x060000)

if (FULLBROWSER)
set(PROJECT_SOURCES
    browser.cpp browser.h
    browserwindow.cpp browserwindow.h
    certificateerrordialog.ui
    downloadmanagerwidget.cpp downloadmanagerwidget.h downloadmanagerwidget.ui
    downloadwidget.cpp downloadwidget.h downloadwidget.ui
    main.cpp
    passworddialog.ui
    tabwidget.cpp tabwidget.h
    webpage.cpp webpage.h
    webpopupwindow.cpp webpopupwindow.h
    webview.cpp webview.h
    data/simplebrowser.qrc
)
else()
set(PROJECT_SOURCES
        main.cpp
        mainwindow.cpp
        mainwindow.h
)
endif()


add_executable(FBrowser
    ${PROJECT_SOURCES}
)

target_link_libraries(FBrowser PUBLIC
    Qt::Core
    Qt::Gui
    Qt::Widgets
    Qt::Network
    Qt::WebEngineWidgets
)
