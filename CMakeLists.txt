cmake_minimum_required(VERSION 3.16)
project(FBrowser LANGUAGES CXX)

file(GLOB source_files *.c *.cpp *.qrc)

set(CMAKE_INCLUDE_CURRENT_DIR ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)


set(USE_QT6 OFF CACHE BOOL "Build against Qt 6 instead of Qt 5")

if (USE_QT6)
  find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Network WebEngineWidgets)
else()
  find_package(Qt5 REQUIRED COMPONENTS Core Gui Widgets Network WebEngineWidgets)
endif()
add_definitions (-DQT_DISABLE_DEPRECATED_BEFORE=0x060000)

set(PROJECT_SOURCES
    main.cpp
    mainwindow.cpp
    mainwindow.h
)


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
