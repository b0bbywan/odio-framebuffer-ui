cmake_minimum_required(VERSION 3.16)
project(FBrowser LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)

# mainwindow.cpp includes QMainWindow and QNetworkProxy directly.
find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Network WebEngineWidgets)

add_executable(FBrowser
    src/main.cpp
    src/mainwindow.cpp
    src/mainwindow.h
)

target_link_libraries(FBrowser PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::Network
    Qt6::WebEngineWidgets
)
