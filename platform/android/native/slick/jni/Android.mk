LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := libluajit
LOCAL_SRC_FILES := libs/$(TARGET_ARCH_ABI)/libluajit-2.0.4.a
include $(PREBUILT_STATIC_LIBRARY)

include $(CLEAR_VARS)
LOCAL_MODULE := slick
LOCAL_CFLAGS += -O3 -DNDEBUG -std=c99
LOCAL_LDLIBS += -llog
LOCAL_STATIC_LIBRARIES += libluajit
LOCAL_SRC_FILES := bridge.c
LOCAL_C_INCLUDES := include
include $(BUILD_SHARED_LIBRARY)
