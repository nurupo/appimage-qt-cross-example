cmake_minimum_required(VERSION 3.1.0)
project(my_app)

# Make sure to use host Qt programs, because when cross-compiling Qt for some reason uses target
if (UNIX)
    foreach(PROGRAM moc rcc uic)
        find_program(QT_NATIVE_EXECUTABLE_${PROGRAM} ${PROGRAM} NO_CMAKE_FIND_ROOT_PATH)
        if (QT_NATIVE_EXECUTABLE_${PROGRAM})
            message(STATUS "Found ${PROGRAM} ${QT_NATIVE_EXECUTABLE_${PROGRAM}}")
            add_executable(Qt5::${PROGRAM} IMPORTED)
            set_property(TARGET Qt5::${PROGRAM} PROPERTY IMPORTED_LOCATION ${QT_NATIVE_EXECUTABLE_${PROGRAM}})
        endif()
    endforeach()
endif()

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt5 REQUIRED COMPONENTS Core Gui Network Widgets)

add_executable(my_app
    src/main.cpp
    src/mainwindow.h
    src/mainwindow.cpp
)

target_link_libraries(my_app Qt5::Core Qt5::Gui Qt5::Network Qt5::Widgets)

install(TARGETS my_app RUNTIME DESTINATION bin)
install(FILES "my_app.desktop" DESTINATION "share/applications")
install(FILES "icons/256x256.png" DESTINATION "share/icons/hicolor/256x256/apps" RENAME "my_app.png")
