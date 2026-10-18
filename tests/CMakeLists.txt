find_package(Qt6 REQUIRED COMPONENTS Core Test)

# Pure heuristics of the AI page: model tags
add_executable(tst_aiheuristics tst_aiheuristics.cpp ${CMAKE_SOURCE_DIR}/src/aiheuristics.cpp)
target_include_directories(tst_aiheuristics PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(tst_aiheuristics PRIVATE Qt6::Core Qt6::Test)
add_test(NAME tst_aiheuristics COMMAND tst_aiheuristics)

# The whisper model for this computer: probe, recommendation, whisper-cli options.
# whisperhw.{h,cpp} and this test are the same files as in lingmo-studio.
add_executable(tst_whisperhw tst_whisperhw.cpp ${CMAKE_SOURCE_DIR}/src/whisperhw.cpp)
target_include_directories(tst_whisperhw PRIVATE ${CMAKE_SOURCE_DIR}/src)
target_link_libraries(tst_whisperhw PRIVATE Qt6::Core Qt6::Test)
add_test(NAME tst_whisperhw COMMAND tst_whisperhw)
set_tests_properties(tst_whisperhw PROPERTIES ENVIRONMENT "LC_ALL=C")
