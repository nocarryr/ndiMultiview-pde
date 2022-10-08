
interface Notifier<T,V> {
  public void registerCallback(Callback callback);
  public boolean registerCallback(Object obj, String methodName);
  void triggerCallback(T instance, V arg);
}

interface Callback<T,V> {
  void onCallback(T instance, V arg);
}


class Callbacks<T,V> implements Notifier<T,V> {
  Set<Callback> weakrefs;
  HashMap<Integer,MethodCallback> methods;
  Class v;
  Callbacks(Class v){
    this.v = v;
    weakrefs = Collections.newSetFromMap(new WeakHashMap<Callback, Boolean>());
    methods = new HashMap<Integer,MethodCallback>();
  }
  void add(Callback obj){
    weakrefs.add(obj);
  }

  boolean add(Object obj, String methodName){
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

  void remove(Callback obj){
    weakrefs.remove(obj);
  }

  void remove(Object obj, String methodName){
    Class[] paramTypes = {this.v};
    MethodCallback mcb = new MethodCallback(obj, methodName, paramTypes);
    if (mcb.valid()){
      int h = mcb.callbackHash();
      if (methods.containsKey(h)){
        methods.remove(h);
      }
    }
  }

  void registerCallback(Callback callback){
    add(callback);
  }

  boolean registerCallback(Object obj, String methodName){
    return add(obj, methodName);
  }

  void triggerCallback(T instance, V args){
    for (Callback cb : weakrefs){
      cb.onCallback(instance, args);
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
