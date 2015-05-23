package com.slick.core;

import android.view.View;
import android.view.View.OnClickListener;
import android.view.View.OnTouchListener;
import android.view.MotionEvent;
import android.text.TextWatcher;
import android.text.Editable;

public class EventListener
  implements OnClickListener, OnTouchListener, TextWatcher
{
  private long id;
  private long key;

  public EventListener(long id, long key) {
    this.id = id;
    this.key = key;
  }

  public void onClick(View v) {
    Lua.call("platform", "on_event", this.id, this.key);
  }

  public boolean onTouch(View v, MotionEvent e) {
    return true;
  }

  public void onTextChanged(CharSequence s, int start, int before, int count) {
    Lua.call("platform", "on_event", this.id, this.key, s.toString());
  }

  public void afterTextChanged(Editable s) {}
  public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
}
