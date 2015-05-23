<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="${ app['id'] }">
  <application android:label="${ app['name'] }">
    <meta-data android:name="entry" android:value="components.${ app['launch'] }" />
    <activity android:name="com.slick.core.SlickActivity">
      <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
      </intent-filter>
    </activity>
  </application>
</manifest>
