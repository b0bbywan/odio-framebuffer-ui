cmake_minimum_required(VERSION 3.16)
project(odio-kiosk LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)

# mainwindow.cpp includes QMainWindow and QNetworkProxy directly.
find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Network WebEngineWidgets)
find_package(PkgConfig REQUIRED)
pkg_check_modules(NSS REQUIRED IMPORTED_TARGET nss)

add_executable(odio-kiosk
    src/distrust.cpp
    src/distrust.h
    src/main.cpp
    src/mainwindow.cpp
    src/mainwindow.h
)

file(GLOB DISTRUST_PEMS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS distrust/*.pem)
qt_add_resources(odio-kiosk distrust PREFIX "/" FILES ${DISTRUST_PEMS})

target_link_libraries(odio-kiosk PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Network
    Qt6::WebEngineWidgets
    PkgConfig::NSS
)

include(GNUInstallDirs)
install(TARGETS odio-kiosk RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
