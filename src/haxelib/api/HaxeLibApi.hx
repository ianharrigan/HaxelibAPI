package haxelib.api;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

using StringTools;

@:access(haxelib.client.Main)
@:access(haxelib.api.MainEx)
class HaxeLibApi {
    public static inline var OPERATION_LIST_LOCAL:String = "operation.listLocal";
    public static inline var OPERATION_INSTALL:String = "operation.install";
    public static inline var OPERATION_SUBMIT:String = "operation.submit";
    public static inline var OPERATION_REMOTE_INFO:String = "operation.remoteInfo";
   
    private var _listeners:Map<String, Array<HaxeLibEvent->Void>> = new Map<String, Array<HaxeLibEvent->Void>>();
    private var _client = new MainEx();

    public function new() {
    }

    public function addListener(type:String, listener:HaxeLibEvent->Void) {
        var array = _listeners.get(type);
        if (array == null) {
            array = [];
            _listeners.set(type, array);
        }
        array.push(listener);
    }
    
    public function removeListener(type:String, listener:HaxeLibEvent->Void) {
        var array = _listeners.get(type);
        if (array == null) {
            return;
        }
        array.remove(listener);
        if (array.length == 0) {
            _listeners.remove(type);
        }
    }

    public function clearListeners() {
        _listeners = new Map<String, Array<HaxeLibEvent->Void>>();
    }
    
    public function dispatchEvent(event:HaxeLibEvent) {
        event.api = this;
        var type = event.type;
        var array = _listeners.get(type);
        if (array == null) {
            return;
        }
        
        for (a in array) {
            a(event);
        }
    }
    
    public var repositoryPath(get, null):String;
    private function get_repositoryPath():String {
		return _client.getGlobalRepository();
    }
    
    public function listLocal(filter:String = null):Array<HaxeLibInfo> {
        dispatchEvent(new HaxeLibEvent(HaxeLibEvent.OPERATION_STARTED, OPERATION_LIST_LOCAL, "Listing local haxelibs"));
        var list = _client.listEx(filter);
        dispatchEvent(new HaxeLibEvent(HaxeLibEvent.OPERATION_ENDED, OPERATION_LIST_LOCAL, "Listing local haxelibs"));
        return list;
    }
    
    public function remoteInfo(name:String):HaxeLibInfo {
        dispatchEvent(new HaxeLibEvent(HaxeLibEvent.OPERATION_STARTED, OPERATION_REMOTE_INFO, "Getting remote info for " + name));
        
        var haxelibInfo = null;
        try {
            var info = _client.infoEx(name);
            //trace(info);
            
            haxelibInfo = new HaxeLibInfo();
            if (info.name != null) {
                haxelibInfo.name = info.name;
            }
            if (info.owner != null) {
                haxelibInfo.owner = info.owner;
            }
            if (info.website != null) {
                haxelibInfo.website = info.website;
            }
            haxelibInfo.downloads = info.downloads;
            if (info.desc != null) {
                haxelibInfo.description = info.desc;
            }
            if (info.license != null) {
                haxelibInfo.license = info.license;
            }
            if (info.tags != null) {
                for (t in info.tags) {
                    haxelibInfo.tags.push(t);
                }
            }
            if (info.versions != null) {
                for (v in info.versions) {
                    var release = new HaxeLibReleaseInfo();
                    release.date = v.date;
                    release.version = v.name;
                    release.downloads = v.downloads;
                    release.comments = v.comments;
                    haxelibInfo.releases.push(release);
                }
                haxelibInfo.releases.reverse();
            }
            if (info.contributors != null) {
                for (c in info.contributors) {
                    var user = new HaxeLibUserInfo();
                    user.username = c.name;
                    user.name = c.fullname;
                    haxelibInfo.contributors.push(user);
                }
            }
            
            dispatchEvent(new HaxeLibEvent(HaxeLibEvent.OPERATION_ENDED, OPERATION_REMOTE_INFO, "Getting remote info for " + name));
        } catch (e:Dynamic) {
            dispatchEvent(new HaxeLibEvent(HaxeLibEvent.OPERATION_ERRORED, OPERATION_REMOTE_INFO, e));
            dispatchEvent(new HaxeLibEvent(HaxeLibEvent.OPERATION_ENDED, OPERATION_REMOTE_INFO, "Getting remote info for " + name));
        }
        
        return haxelibInfo;
    }
    
    public function install(name:String, version:String) {
        dispatchEvent(new HaxeLibEvent(HaxeLibEvent.OPERATION_STARTED, OPERATION_INSTALL, "Installing " + name + " version " + version));
        _client.doInstallEx(repositoryPath, name, version, true, function(data:Dynamic) {
            var message = data.message;
            if (data.type == "complete") {
                dispatchEvent(new HaxeLibEvent(HaxeLibEvent.OPERATION_ENDED, OPERATION_INSTALL, message));
            } else {
                var event = new HaxeLibEvent(HaxeLibEvent.OPERATION_PROGRESS, OPERATION_INSTALL, message);
                event.progressCurrent = data.cur;
                event.progressMax = data.max;
                dispatchEvent(event);
            }
        });
    }
    
    public function submit(zipFile:String, username:String, password:String) {
        dispatchEvent(new HaxeLibEvent(HaxeLibEvent.OPERATION_STARTED, OPERATION_SUBMIT, "Submitting " + zipFile));
        try {
            _client.submitEx(zipFile, username, password, function(data:Dynamic) {
                var message = data.message;
                if (data.type == "complete") {
                    dispatchEvent(new HaxeLibEvent(HaxeLibEvent.OPERATION_ENDED, OPERATION_SUBMIT, message));
                } else {
                    var event = new HaxeLibEvent(HaxeLibEvent.OPERATION_PROGRESS, OPERATION_SUBMIT, message);
                    event.progressCurrent = data.cur;
                    event.progressMax = data.max;
                    dispatchEvent(event);
                }
            });
        } catch (e:Dynamic) {
            dispatchEvent(new HaxeLibEvent(HaxeLibEvent.OPERATION_ERRORED, OPERATION_SUBMIT, e));
        }
    }
    
    public function dev(name:String, path:String = null) {
        dispatchEvent(new HaxeLibEvent(HaxeLibEvent.OPERATION_STARTED, OPERATION_INSTALL, "Setting development directory for " + name));
        _client.devEx(name, path);
        dispatchEvent(new HaxeLibEvent(HaxeLibEvent.OPERATION_ENDED, OPERATION_INSTALL, "Setting development directory for " + name));
    }
    
    public static function safeName(s:String) {
        return Data.safe(s);
    }
}