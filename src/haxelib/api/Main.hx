package haxelib.api;

class Main {
	static function main() {
        var api = new HaxeLibApi();
        api.addListener(HaxeLibEvent.OPERATION_STARTED, onEvent);
        api.addListener(HaxeLibEvent.OPERATION_PROGRESS, onEvent);
        api.addListener(HaxeLibEvent.OPERATION_ERRORED, onEvent);
        api.addListener(HaxeLibEvent.OPERATION_ENDED, onEvent);
        
        var localLibs = api.listLocal();
        trace("local haxelibs: " + localLibs.length);
        var actuate = localLibs[0];
        for (l in localLibs) {
            l.enrich();
            trace("name: " + l.name);
            trace("currentLocalVersion: " + l.currentLocalVersion);
            trace("availableLocalVersions: " + l.availableLocalVersions.join(", "));
            trace("localRootPath: " + l.localRootPath);
            trace("currentLocalPath: " + l.currentLocalPath);
            trace("isDev: " + l.isDev);
            trace("");
            //break;
        }
        
        
        api.install("actuate", "1.8.7");
        api.remoteInfo("actuate");
	}
    
    private static function onEvent(event:HaxeLibEvent) {
        if (event.type == HaxeLibEvent.OPERATION_PROGRESS) {
            trace(event.operationId + " ---> " + event.type + " > " + event.message + " (" + event.progressCurrent + " / " + event.progressMax + ")");
        } else {
            trace(event.operationId + " ---> " + event.type + " > " + event.message);
        }
    }
}