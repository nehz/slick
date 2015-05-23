#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <jni.h>
#include <android/log.h>
#include <assert.h>

#include "lua/lua.h"
#include "lua/lualib.h"
#include "lua/lauxlib.h"

#define TAG "slick"
#define LOCAL_FRAME_CAP 100

#define JNI(f, ...) (*jni_env)->f(jni_env, __VA_ARGS__)
#define REF(o) JNI(NewGlobalRef, o)
#define JNI_REF(f, ...) ({ \
  jobject o = JNI(f, __VA_ARGS__); \
  jobject g = REF(o); \
  JNI(DeleteLocalRef, o); \
  g; \
})
#define LOCAL(s) { \
  int _f(lua_State *L) { s }; \
  JNI(PushLocalFrame, LOCAL_FRAME_CAP); \
  int r = _f(L); \
  JNI(PopLocalFrame, 0); \
  return r; \
};
#define DELOCAL(o) JNI(DeleteLocalRef, o)
#define EQUAL(x, y) JNI(IsSameObject, x, y)
#define LOG(...) __android_log_print(ANDROID_LOG_INFO, TAG, __VA_ARGS__)
#define ERROR(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

#ifndef LUA_VERSION_NUM
  #error Require Lua >= 5.1
#elif LUA_VERSION_NUM == 501
  #define lua_pushglobaltable(L) lua_pushvalue(L, LUA_GLOBALSINDEX)
#else
  #define luaL_register(L, n, l) (luaL_newlib(L, l), lua_setglobal(L, n))
#endif

typedef struct {
  jobject ref;
  void *data;
} Reference;

typedef struct {
  bool is_varargs;
  size_t args_len;
  jclass args_type[];
} MethodInfo;

static JNIEnv *jni_env;
static lua_State *L;

static struct {
  jstring storage_path;
  jobject package;
} global;

static struct {
  struct {
    jclass short_t;
    jclass int_t;
    jclass long_t;
    jclass float_t;
    jclass double_t;
    jclass bool_t;
  } Primitive;
  struct {
    jclass class;
    jmethodID toString;
  } Object;
  struct {
    jclass class;
    jmethodID getConstructors;
    jmethodID getMethods;
  } Class;
  struct { jclass class; } String;
  struct {
    jclass class;
    jmethodID doubleValue;
  } Number;
  struct {
    jclass class;
    jmethodID init;
  } Short;
  struct {
    jclass class;
    jmethodID init;
  } Integer;
  struct {
    jclass class;
    jmethodID init;
  } Long;
  struct {
    jclass class;
    jmethodID init;
  } Float;
  struct {
    jclass class;
    jmethodID init;
  } Double;
  struct {
    jclass class;
    jmethodID init;
    jmethodID booleanValue;
  } Boolean;
  struct {
    jclass class;
    jmethodID getName;
  } Member;
  struct {
    jclass class;
    jmethodID getParameterTypes;
    jmethodID isVarArgs;
    jmethodID newInstance;
  } Constructor;
  struct {
    jclass class;
    jmethodID getParameterTypes;
    jmethodID isVarArgs;
    jmethodID invoke;
  } Method;
  struct {
    jclass class;
    jmethodID read;
  } InputStream;
  struct {
    jclass class;
    jmethodID init;
    jmethodID getEntry;
    jmethodID getInputStream;
  } ZipFile;
  struct {
    jclass class;
    jmethodID getSize;
  } ZipEntry;
} cache;

/* Helpers */

static jobject to_java(lua_State *L, int index, jclass cls) {
  Reference *obj;
  switch(lua_type(L, index)) {
    case LUA_TNIL:
      break;
    case LUA_TNUMBER:
      if (cls == cache.Short.class || cache.Primitive.short_t) {
        jshort val = (jshort)lua_tonumber(L, index);
        return JNI(NewObject, cache.Short.class, cache.Short.init, val);
      }
      else if (cls == cache.Integer.class || cache.Primitive.int_t) {
        jint val = (jint)lua_tonumber(L, index);
        return JNI(NewObject, cache.Integer.class, cache.Integer.init, val);
      }
      else if (cls == cache.Long.class || cache.Primitive.long_t) {
        jlong val = (jlong)lua_tonumber(L, index);
        return JNI(NewObject, cache.Long.class, cache.Long.init, val);
      }
      else if (cls == cache.Float.class || cache.Primitive.float_t) {
        jfloat val = (jfloat)lua_tonumber(L, index);
        return JNI(NewObject, cache.Float.class, cache.Float.init, val);
      }
      else {
        jdouble val = (jdouble)lua_tonumber(L, index);
        return JNI(NewObject, cache.Double.class, cache.Double.init, val);
      }
    case LUA_TBOOLEAN:
      return JNI(NewObject,
        cache.Boolean.class, cache.Boolean.init, lua_toboolean(L, index));
    case LUA_TSTRING:
      return JNI(NewStringUTF, lua_tostring(L, index));
    case LUA_TTABLE:
      lua_pushstring(L, "_ref");
      lua_rawget(L, index);
      obj = lua_touserdata(L, -1);
      lua_pop(L, 1);
      if (obj) return obj->ref;
      luaL_error(L, "Table value conversion not yet supported");
      break;
    case LUA_TFUNCTION:
      luaL_error(L, "Function value conversion not yet supported");
      break;
    case LUA_TUSERDATA:
    case LUA_TLIGHTUSERDATA:
      obj = lua_touserdata(L, index);
      return obj->ref;
    case LUA_TTHREAD:
      luaL_error(L, "Thread value conversion not supported");
      break;
    default:
      luaL_error(L, "Unknown value conversion error");
      break;
  }
  return 0;
}

static jclass to_java_type(lua_State *L, int index) {
  Reference *obj;
  switch(lua_type(L, index)) {
    case LUA_TNIL:
      break;
    case LUA_TNUMBER:
      return cache.Double.class;
    case LUA_TBOOLEAN:
      return cache.Boolean.class;
    case LUA_TSTRING:
      return cache.String.class;
    case LUA_TTABLE:
      lua_pushstring(L, "_ref");
      lua_rawget(L, index);
      obj = lua_touserdata(L, -1);
      lua_pop(L, 1);
      if (obj) return JNI(GetObjectClass, obj->ref);
      luaL_error(L, "Table value conversion not yet supported");
      break;
    case LUA_TFUNCTION:
      luaL_error(L, "Function value conversion not yet supported");
      break;
    case LUA_TUSERDATA:
    case LUA_TLIGHTUSERDATA:
      obj = lua_touserdata(L, index);
      return JNI(GetObjectClass, obj->ref);
    case LUA_TTHREAD:
      luaL_error(L, "Thread value conversion not supported");
      break;
    default:
      luaL_error(L, "Unknown value conversion error");
      break;
  }
  return 0;
}

static Reference *push_reference(lua_State *L, jobject jobj, void *data) {
  Reference *ref = lua_newuserdata(L, sizeof(Reference));
  ref->ref = JNI(NewGlobalRef, jobj);
  ref->data = data;
  luaL_getmetatable(L, "reference");
  lua_setmetatable(L, -2);
  return ref;
}

static void push_java(lua_State *L, jobject obj) {
  if (!obj) {
    lua_pushnil(L);
    return;
  }

  jclass cls = JNI(GetObjectClass, obj);
  if (obj == NULL) {
    lua_pushnil(L);
  }
  else if (JNI(IsAssignableFrom, cls, cache.String.class)) {
    const char *r = JNI(GetStringUTFChars, obj, 0);
    lua_pushstring(L, r);
    JNI(ReleaseStringUTFChars, obj, r);
  }
  else if (JNI(IsAssignableFrom, cls, cache.Number.class)) {
    double r = JNI(CallDoubleMethod, obj, cache.Number.doubleValue);
    lua_pushnumber(L, r);
  }
  else if (JNI(IsAssignableFrom, cls, cache.Boolean.class)) {
    bool r = JNI(CallBooleanMethod, obj, cache.Boolean.booleanValue);
    lua_pushboolean(L, r);
  }
  else {
    push_reference(L, obj, 0);
  }
  DELOCAL(cls);
}

static void get_methods(lua_State *L, jclass cls, bool constructor) {
  jarray methods = constructor ?
    JNI(CallObjectMethod, cls, cache.Class.getConstructors) :
    JNI(CallObjectMethod, cls, cache.Class.getMethods);

  jsize len = JNI(GetArrayLength, methods);
  for (int i = 0; i < len; i++) {
    jobject method = JNI(GetObjectArrayElement, methods, i);
    jstring j_name = JNI(CallObjectMethod, method, cache.Member.getName);
    const char *name = JNI(GetStringUTFChars, j_name, 0);

    if (!constructor) {
      // Store all method overloads for method in a table
      lua_pushstring(L, name);
      lua_rawget(L, -2);
      if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        lua_newtable(L);
        lua_pushstring(L, name);
        lua_pushvalue(L, -2);
        lua_rawset(L, -4);
      }
    }

    // Cache method overload arg types
    jarray args_type = constructor ?
      JNI(CallObjectMethod, method, cache.Constructor.getParameterTypes) :
      JNI(CallObjectMethod, method, cache.Method.getParameterTypes);

    jsize len = JNI(GetArrayLength, args_type);
    MethodInfo *info = malloc(sizeof(MethodInfo) + (sizeof(jclass) * len));

    info->is_varargs = constructor ?
      JNI(CallBooleanMethod, method, cache.Constructor.isVarArgs) :
      JNI(CallBooleanMethod, method, cache.Method.isVarArgs);
    info->args_len = len;

    for (int i = 0; i < len; i++) {
      // Global references won't be deleted, but this should be ok as we
      // expect classes to not be GCed. We will also cache the
      // imported class at the lua side
      info->args_type[i] = JNI_REF(GetObjectArrayElement, args_type, i);
    }

    // Push method overload into method table
    int n = lua_objlen(L, -1);
    push_reference(L, method, info);
    lua_rawseti(L, -2, n + 1);

    if (!constructor) lua_pop(L, 1);
    JNI(ReleaseStringUTFChars, j_name, name);

    DELOCAL(method);
    DELOCAL(j_name);
    DELOCAL(args_type);
  }
}

static Reference *select_method(lua_State *L, const char *name, int index) {
  int num_args = lua_gettop(L) - (index - 1);
  int num_methods = lua_objlen(L, 1);
  int num_candidates = num_methods;

  jclass args_type[num_args];
  Reference *methods[num_methods];

  for (int i = 0; i < num_args; i++) {
    args_type[i] = to_java_type(L, i + index);
  }

  // First pass: only methods which match number of arguments
  for (int i = 0; i < num_methods; i++) {
    lua_pushnumber(L, i + 1);
    lua_rawget(L, 1);
    methods[i] = lua_touserdata(L, -1);
    MethodInfo *info = methods[i]->data;

    if (info->args_len != num_args || (
        info->is_varargs && info->args_len <= num_args)) {
      methods[i] = 0;
      num_candidates--;
    }
    lua_pop(L, 1);
  }

  if (num_candidates == 1) goto done;
  if (!num_candidates) goto fail;

  // Second pass: check if types are compatible
  for (int i = 0; i < num_methods; i++) {
    if (!methods[i]) continue;

    MethodInfo *info = methods[i]->data;
    int n = info->is_varargs ? info->args_len - 1 : num_args;
    for (int j = 0; j < n; j++) {
      if (!args_type[j]) continue;
      if (JNI(IsAssignableFrom, args_type[j], info->args_type[j])) continue;

      if (EQUAL(args_type[j], cache.Double.class) && (
          JNI(IsAssignableFrom, info->args_type[j], cache.Number.class) ||
          EQUAL(info->args_type[j], cache.Primitive.short_t) ||
          EQUAL(info->args_type[j], cache.Primitive.int_t) ||
          EQUAL(info->args_type[j], cache.Primitive.long_t) ||
          EQUAL(info->args_type[j], cache.Primitive.float_t) ||
          EQUAL(info->args_type[j], cache.Primitive.double_t)))
        continue;

      if (EQUAL(args_type[j], cache.Boolean.class) &&
          EQUAL(info->args_type[j], cache.Primitive.bool_t))
        continue;

      methods[i] = 0;
      num_candidates--;
      break;
    }
  }

  if (num_candidates == 1) goto done;
  if (!num_candidates) goto fail;

  for (int i = 0; i < num_methods; i++) {
    if (methods[i]) {
      MethodInfo *info = methods[i]->data;
      for (int j = 0; j < info->args_len; j++) {
        jobject j_a = JNI(CallObjectMethod,
          info->args_type[j], cache.Object.toString);
        const char *a = JNI(GetStringUTFChars, j_a, 0);
        ERROR("%s", a);
        JNI(ReleaseStringUTFChars, j_a, a);
      }
    }
  }
  luaL_error(L, "Ambiguous method: (%d) %s", num_candidates, name);
  return 0;
fail:
  luaL_error(L, "No method found: %s", name);
  return 0;
done:
  for (int i = 0; i < num_methods; i++) {
    if (methods[i]) return methods[i];
  }
  luaL_error(L, "Select method fail: %s", name);
  return 0;
}

static jarray prepare_args(lua_State *L, Reference *method, int index) {
  if (!method) return 0;
  MethodInfo *info = method->data;

  jarray args = JNI(NewObjectArray, info->args_len, cache.Object.class, 0);
  int n = info->is_varargs ? info->args_len - 1 : info->args_len;
  for (int i = 0; i < n; i++) {
    jobject val = to_java(L, i + index, info->args_type[i]);
    JNI(SetObjectArrayElement, args, i, val);
  }

  if (info->is_varargs) {
    int num_args = lua_gettop(L) - (index - 1);
    int num_varargs = num_args - info->args_len;
    jarray varargs = JNI(NewObjectArray, num_varargs, cache.Object.class, 0);

    for (int i = 0; i < num_varargs; i++) {
      jobject val = to_java(L, i + n + index,  info->args_type[i]);
      JNI(SetObjectArrayElement, args, i, val);
    }

    JNI(SetObjectArrayElement, args, n, varargs);
    DELOCAL(varargs);
  }

  return args;
}

/* Lua functions */

static int log_info(lua_State *L) LOCAL ({
  int type = lua_type(L, 1);
  switch(type) {
    case LUA_TNIL:
      LOG("nil");
      break;
    case LUA_TNUMBER:
      LOG("%d", lua_tointeger(L, 1));
      break;
    case LUA_TBOOLEAN:
      LOG("%s", lua_toboolean(L, 1) ? "true" : "false");
      break;
    case LUA_TSTRING:
      LOG("%s", lua_tostring(L, 1));
      break;
    case LUA_TTABLE:
      LOG("table");
      break;
    case LUA_TFUNCTION:
      LOG("function");
      break;
    case LUA_TUSERDATA:
    case LUA_TLIGHTUSERDATA:
      LOG("userdata");
      break;
    case LUA_TTHREAD:
      LOG("thread");
      break;
    default:
      LOG("log(): invalid type %d", type);
      break;
  }
  return 0;
})

static int inflate(lua_State *L) LOCAL ({
  jstring path = JNI(NewStringUTF, luaL_checkstring(L, 1));
  jobject zip_entry = JNI(CallObjectMethod,
    global.package, cache.ZipFile.getEntry, path);

  if (!zip_entry) {
    lua_pushnil(L);
    return 1;
  }

  size_t size = JNI(CallLongMethod, zip_entry, cache.ZipEntry.getSize);
  jarray buffer = JNI(NewByteArray, size);
  jobject stream = JNI(CallObjectMethod,
    global.package, cache.ZipFile.getInputStream, zip_entry);
  JNI(CallIntMethod, stream, cache.InputStream.read, buffer);

  char *data = JNI(GetByteArrayElements, buffer, 0);
  lua_pushlstring(L, data, size);
  JNI(ReleaseByteArrayElements, buffer, data, JNI_ABORT);
  return 1;
})

static int import(lua_State *L) LOCAL ({
  jclass cls;
  if (lua_type(L, 1) == LUA_TUSERDATA) {
    cls = lua_touserdata(L, 1);
  } else {
    const char *cls_str = luaL_checkstring(L, 1);
    cls = JNI(FindClass, cls_str);
    if (!cls) {
      luaL_error(L, "Class not found: %s", cls_str);
      return 0;
    }
  }

  lua_newtable(L);
  lua_pushstring(L, "_ref");
  push_reference(L, cls, 0);
  lua_rawset(L, -3);

  // Constructors
  lua_newtable(L);
  lua_pushstring(L, "_constructors");
  lua_pushvalue(L, -2);
  lua_rawset(L, -4);
  get_methods(L, cls, true);
  lua_pop(L, 1);

  // Methods
  lua_newtable(L);
  lua_pushstring(L, "_methods");
  lua_pushvalue(L, -2);
  lua_rawset(L, -4);
  get_methods(L, cls, false);
  lua_pop(L, 1);

  // Fields
  lua_newtable(L);
  lua_pushstring(L, "_fields");
  lua_pushvalue(L, -2);
  lua_rawset(L, -4);
  lua_pop(L, 1);

  return 1;
})

static int new(lua_State *L) LOCAL ({
  Reference *constructor = select_method(L, "<init>", 2);
  jarray args = prepare_args(L, constructor, 2);
  if (!args) return 0;

  jobject obj = JNI(CallObjectMethod,
    constructor->ref, cache.Constructor.newInstance, args);
  push_reference(L, obj, 0);
  return 1;
})

static int gc(lua_State *L) LOCAL ({
  Reference *obj = lua_touserdata(L, 1);
  JNI(DeleteGlobalRef, obj->ref);
  if (obj->data) free(obj->data);
  return 0;
})

static int invoke(lua_State *L) LOCAL ({
  const char *name = lua_tostring(L, 2);
  Reference *obj = lua_touserdata(L, 3);
  Reference *method = select_method(L, name, 4);
  jarray args = prepare_args(L, method, 4);
  if (!args) return 0;

  jobject res = JNI(CallObjectMethod,
    method->ref, cache.Method.invoke, obj->ref, args);

  push_java(L, res);
  return 1;
})

/* JNI exports */

JNIEXPORT unsigned long long JNICALL
Java_com_slick_core_Lua_init(
  JNIEnv *env, jclass cls, jstring j_apk_path, jstring j_storage_path)
{
  jni_env = env;

  // Cache classes
  cache.Object.class = JNI_REF(FindClass, "java/lang/Object");
  cache.Class.class = JNI_REF(FindClass, "java/lang/Class");
  cache.String.class = JNI_REF(FindClass, "java/lang/String");
  cache.Number.class = JNI_REF(FindClass, "java/lang/Number");
  cache.Short.class = JNI_REF(FindClass, "java/lang/Short");
  cache.Integer.class = JNI_REF(FindClass, "java/lang/Integer");
  cache.Long.class = JNI_REF(FindClass, "java/lang/Long");
  cache.Float.class = JNI_REF(FindClass, "java/lang/Float");
  cache.Double.class = JNI_REF(FindClass, "java/lang/Double");
  cache.Boolean.class = JNI_REF(FindClass, "java/lang/Boolean");
  cache.Member.class = JNI_REF(FindClass, "java/lang/reflect/Member");
  cache.Constructor.class = JNI_REF(FindClass, "java/lang/reflect/Constructor");
  cache.Method.class = JNI_REF(FindClass, "java/lang/reflect/Method");
  cache.InputStream.class = JNI_REF(FindClass, "java/io/InputStream");
  cache.ZipFile.class = JNI_REF(FindClass, "java/util/zip/ZipFile");
  cache.ZipEntry.class = JNI_REF(FindClass, "java/util/zip/ZipEntry");

  // Cache primitive classes
  cache.Primitive.short_t = JNI_REF(GetStaticObjectField,
    cache.Short.class, JNI(GetStaticFieldID, cache.Short.class, "TYPE",
      "Ljava/lang/Class;"));
  cache.Primitive.int_t = JNI_REF(GetStaticObjectField,
    cache.Integer.class, JNI(GetStaticFieldID, cache.Integer.class, "TYPE",
      "Ljava/lang/Class;"));
  cache.Primitive.long_t = JNI_REF(GetStaticObjectField,
    cache.Long.class, JNI(GetStaticFieldID, cache.Long.class, "TYPE",
      "Ljava/lang/Class;"));
  cache.Primitive.float_t = JNI_REF(GetStaticObjectField,
    cache.Float.class, JNI(GetStaticFieldID, cache.Float.class, "TYPE",
      "Ljava/lang/Class;"));
  cache.Primitive.double_t = JNI_REF(GetStaticObjectField,
    cache.Double.class, JNI(GetStaticFieldID, cache.Double.class, "TYPE",
      "Ljava/lang/Class;"));
  cache.Primitive.bool_t = JNI_REF(GetStaticObjectField,
    cache.Boolean.class, JNI(GetStaticFieldID, cache.Boolean.class, "TYPE",
      "Ljava/lang/Class;"));

  // Cache methods
  cache.Number.doubleValue = JNI(GetMethodID, cache.Number.class,
    "doubleValue", "()D");
  cache.Short.init = JNI(GetMethodID, cache.Short.class,
    "<init>", "(S)V");
  cache.Integer.init = JNI(GetMethodID, cache.Integer.class,
    "<init>", "(I)V");
  cache.Long.init = JNI(GetMethodID, cache.Long.class,
    "<init>", "(J)V");
  cache.Float.init = JNI(GetMethodID, cache.Float.class,
    "<init>", "(F)V");
  cache.Double.init = JNI(GetMethodID, cache.Double.class,
    "<init>", "(D)V");
  cache.Boolean.init = JNI(GetMethodID, cache.Boolean.class,
    "<init>", "(Z)V");
  cache.Boolean.booleanValue = JNI(GetMethodID, cache.Boolean.class,
    "booleanValue", "()Z");
  cache.Object.toString = JNI(GetMethodID, cache.Object.class,
    "toString", "()Ljava/lang/String;");
  cache.Class.getConstructors = JNI(GetMethodID, cache.Class.class,
    "getConstructors", "()[Ljava/lang/reflect/Constructor;");
  cache.Class.getMethods = JNI(GetMethodID, cache.Class.class,
    "getMethods", "()[Ljava/lang/reflect/Method;");
  cache.Member.getName = JNI(GetMethodID, cache.Member.class,
    "getName", "()Ljava/lang/String;");
  cache.Constructor.getParameterTypes = JNI(GetMethodID, cache.Constructor.class,
    "getParameterTypes", "()[Ljava/lang/Class;");
  cache.Constructor.isVarArgs = JNI(GetMethodID, cache.Constructor.class,
    "isVarArgs", "()Z");
  cache.Constructor.newInstance = JNI(GetMethodID, cache.Constructor.class,
    "newInstance", "([Ljava/lang/Object;)Ljava/lang/Object;");
  cache.Method.getParameterTypes = JNI(GetMethodID, cache.Method.class,
    "getParameterTypes", "()[Ljava/lang/Class;");
  cache.Method.isVarArgs = JNI(GetMethodID, cache.Method.class,
    "isVarArgs", "()Z");
  cache.Method.invoke = JNI(GetMethodID, cache.Method.class,
    "invoke", "(Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;");
  cache.InputStream.read = JNI(GetMethodID, cache.InputStream.class,
    "read", "([B)I");
  cache.ZipFile.init = JNI(GetMethodID, cache.ZipFile.class,
    "<init>", "(Ljava/lang/String;)V");
  cache.ZipFile.getEntry = JNI(GetMethodID, cache.ZipFile.class,
    "getEntry", "(Ljava/lang/String;)Ljava/util/zip/ZipEntry;");
  cache.ZipFile.getInputStream = JNI(GetMethodID, cache.ZipFile.class,
    "getInputStream", "(Ljava/util/zip/ZipEntry;)Ljava/io/InputStream;");
  cache.ZipEntry.getSize = JNI(GetMethodID, cache.ZipEntry.class,
    "getSize", "()J");

  // Global references
  global.storage_path = JNI(NewGlobalRef, j_storage_path);
  global.package = JNI(NewGlobalRef,
    JNI(NewObject, cache.ZipFile.class, cache.ZipFile.init, j_apk_path));

  L = luaL_newstate();
  luaL_openlibs(L);

  // Register functions
  const luaL_Reg funcs[] = {
    {"log_info", log_info},
    {"inflate", inflate},
    {"import", import},
    {"new", new},
    {"gc", gc},
    {"invoke", invoke},
    {NULL, NULL}
  };
  luaL_register(L, "_internal", funcs);

  // Zip module loader
  luaL_dostring(L,
    "table.insert(package.loaders, function(module_name) "
    "  local module_path = string.gsub(module_name, '%.', '/') "
    "  local module = _internal.inflate('assets/' .. module_path .. '.lua') "
    "  if module then "
    "    return assert(loadstring(module, module_name)) "
    "  end "
    "  module = _internal.inflate('assets/' .. module_path .. '/init.lua') "
    "  if module then "
    "    return assert(loadstring(module, module_name)) "
    "  end "
    "end) "
  );

  // Register metatables
  luaL_newmetatable(L, "reference");
  lua_pushstring(L, "__gc");
  lua_pushcfunction(L, gc);
  lua_rawset(L, -3);

  lua_settop(L, 0);
}

JNIEXPORT void JNICALL
Java_com_slick_core_Lua_call(
  JNIEnv *env, jclass cls, jstring j_module, jstring j_func, jarray args)
{
  assert(L);
  const char *module = JNI(GetStringUTFChars, j_module, 0);
  const char *func = JNI(GetStringUTFChars, j_func, 0);

  lua_getfield(L, LUA_GLOBALSINDEX, "require");
  lua_pushstring(L, module);
  if (lua_pcall(L, 1, 1, 0)) {
    ERROR("Error loading: %s", module);
    ERROR("%s", lua_tostring(L, -1));
    goto done;
  }

  lua_pushstring(L, func);
  lua_gettable(L, -2);
  if (lua_isnil(L, -1)) {
    ERROR("Cannot find func: %s.%s", module, func);
    goto done;
  }

  int num_args = JNI(GetArrayLength, args);
  for (int i = 0; i < num_args; i++) {
    jobject arg = JNI(GetObjectArrayElement, args, i);
    push_java(L, arg);
  }

  if (lua_pcall(L, num_args, 0, 0)) {
    ERROR("Error calling: %s.%s", module, func);
    ERROR("%s", lua_tostring(L, -1));
    goto done;
  }

done:
  lua_settop(L, 0);
  JNI(ReleaseStringUTFChars, j_module, module);
  JNI(ReleaseStringUTFChars, j_func, func);
}

JNIEXPORT void JNICALL
Java_com_slick_core_Lua_destroy(JNIEnv *env, jclass cls)
{
  lua_close(L);
}
