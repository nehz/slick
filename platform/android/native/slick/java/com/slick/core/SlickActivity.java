package com.slick.core;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.content.pm.PackageManager;
import android.content.pm.PackageManager.NameNotFoundException;
import android.content.pm.ApplicationInfo;

public class SlickActivity extends Activity {
  public static final String TAG = "slick";
  public long luaState;

  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    String entry;
    try {
      ApplicationInfo info = getPackageManager().getApplicationInfo(
        getPackageName(), PackageManager.GET_META_DATA);
      entry = info.metaData.getString("entry");
    } catch(NameNotFoundException e) {
      Log.e(TAG, "Cannot find entry in metadata");
      return;
    }

    Log.i(TAG, "Loading...");
    try {
      Lua.init(this);
      Log.i(TAG, "Init successful");
      Lua.call("platform", "set", "android");
      Lua.call("platform", "init", entry, this);
    } catch(Throwable e) {
      Log.e(TAG, "Failed to init entry");
      Log.e(TAG, "Java exception", e);
    }
  }
}
