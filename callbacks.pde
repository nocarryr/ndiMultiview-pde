
interface Notifier<T,V> {
  public void registerCallback(Callback callback);
  public boolean registerCallback(Object obj, String methodName);
  boolean unregisterCallback(Callback callback);
  boolean unregisterCallback(Object obj, String methodName);
  public void triggerCallback(V arg);
}

interface Callback<T,V> {
  void onCallback(T instance, V arg);
}


abstract class Callbacks<T,V> implements Notifier<T,V>{
  private Set<Callback> weakrefs;
  private HashMap<Integer,MethodCallback> methods;
  private Class v;
  public Callbacks(){
    weakrefs = Collections.newSetFromMap(new WeakHashMap<Callback, Boolean>());
    methods = new HashMap<Integer,MethodCallback>();
  }

  protected void setCallbackArgType(Class v){
    this.v = v;
  }

  private void _addCallback(Callback obj){
    weakrefs.add(obj);
  }

  private boolean _addCallback(Object obj, String methodName){
    Class[] paramTypes = {this.v};
    MethodCallback mcb = new MethodCallback(obj, methodName, paramTypes);
    if (mcb.valid()){
      int h = mcb.callbackHash();
      if (!methods.containsKey(h)){
        methods.put(h, mcb);
      }
    }
    return mcb.valid();
  }

  private boolean _removeCallback(Callback obj){
    return weakrefs.remove(obj);
  }

  private boolean _removeCallback(Object obj, String methodName){
    Class[] paramTypes = {this.v};
    MethodCallback mcb = new MethodCallback(obj, methodName, paramTypes);
    if (mcb.valid()){
      int h = mcb.callbackHash();
      if (methods.containsKey(h)){
        methods.remove(h);
        return true;
      }
    }
    return false;
  }

  public void registerCallback(Callback callback){
    _addCallback(callback);
  }

  public boolean registerCallback(Object obj, String methodName){
    return _addCallback(obj, methodName);
  }

  public boolean unregisterCallback(Callback callback){
    return _removeCallback(callback);
  }

  public boolean unregisterCallback(Object obj, String methodName){
    return _removeCallback(obj, methodName);
  }

  public void triggerCallback(V args){
    for (Callback cb : weakrefs){
      cb.onCallback(this, args);
    }
    IntList toRemove = new IntList();
    for (MethodCallback mcb : methods.values()){
      boolean r = mcb.invoke(args);
      if (!r){
        toRemove.append(mcb.callbackHash());
      }
    }
    for (int h : toRemove){
      methods.remove(h);
    }
  }
}


class MethodCallback{
  private WeakReference ref;
  private int _objHash;
  private int _methodHash;
  private Method method;
  private boolean _valid;

  MethodCallback(Object obj, String methodName, Class[] paramTypes){
    ref = new WeakReference(obj);
    _objHash = obj.hashCode();
    method = getMethodObj(obj.getClass(), methodName, paramTypes);
    _valid = method != null;
    if (_valid){
      _methodHash = method.hashCode();
    }
  }
  MethodCallback(Object obj, String methodName){
    ref = new WeakReference(obj);
    Class[] paramTypes = new Class[0];
    method = getMethodObj(obj.getClass(), methodName, paramTypes);
    _valid = method != null;
    if (_valid){
      _methodHash = method.hashCode();
    }
  }

  public int objHash(){ return _objHash; }
  public int methodHash(){ return _methodHash; }
  public int callbackHash(){
    return _objHash ^ _methodHash;
  }
  public boolean valid(){ return _valid; }
  public boolean alive(){ return ref.get() != null; }

  public boolean invoke(Object ... args){
    if (!_valid){
      return false;
    }
    Object obj = ref.get();
    if (obj == null){
      return false;
    }
    try {
      method.invoke(obj, args);
    } catch(IllegalAccessException e){
      e.printStackTrace();
      return false;
    } catch(InvocationTargetException e){
      e.printStackTrace();
      return false;
    }
    return true;
  }

  private Method getMethodObj(Class cls, String methodName, Class[] paramTypes){
    for (Method m : cls.getMethods()){
      if (m.getName() != methodName){
        continue;
      }
      Class[] params = m.getParameterTypes();
      if (params.length != paramTypes.length){
        continue;
      }
      boolean paramsMatch = true;
      for (int i=0; i<params.length; i++){
        if (params[i] != paramTypes[i]){
          paramsMatch = false;
          break;
        }
      }
      if (paramsMatch){
        return m;
      }
    }
    return null;
  }
}
