package com.slick.core;

import android.app.Activity;

public class Lua {
  public static void init(Activity activity) {
    final String storagePath = activity.getApplicationInfo().dataDir;
    final String apkPath = activity.getPackageResourcePath();
    Lua.init(apkPath, storagePath);
  }

  static {
    System.loadLibrary("slick");
  }

  private static native long init(String apkPath, String storagePath);
  public static native void call(String module, String func, Object... args);
  public static native void destroy();
}
